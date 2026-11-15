%% SPDX-License-Identifier: Apache-2.0
%% Shared I/O and identities for the installed Common Test controller.
-module(otp_ct_support).
-include_lib("kernel/include/file.hrl").
-export([command/5, copy/2, copy_tree/2, sha/1, content_sha/1, hash/1,
         write_json/2, read_json/1, json/1, bin/1, text/1, absolute/1,
         owned_path/2, owned_work/2, environment/1, identity/1, session/1, domains/0,
         selection/1, platform/0, system_name/0, architecture/0, installed_command/2,
         linux_envelope/1, input_tree/1, prepare_runtime/1, finish_runtime/1,
         verify_runtime_receipts/2]).

bin(Value) when is_binary(Value) -> Value;
bin(Value) -> unicode:characters_to_binary(Value).
text(Value) -> iolist_to_binary(io_lib:format("~0tp", [Value])).
hash(Value) -> binary:encode_hex(crypto:hash(sha256, term_to_binary(json(Value), [deterministic])), lowercase).
sha(Path) ->
    content_sha(Path).
content_sha(Path) ->
    {ok, Bytes} = file:read_file(Path),
    binary:encode_hex(crypto:hash(sha256, Bytes), lowercase).

json(Value) when is_map(Value) ->
    %% Decoded JSON already distinguishes strings from integer arrays. Keep
    %% that distinction when embedding raw CT rows in a published report.
    case json_value(Value) of
        true -> Value;
        false -> maps:from_list([{key(K), json(V)} || {K,V} <- maps:to_list(Value)])
    end;
json(Value) when is_tuple(Value) -> json(tuple_to_list(Value));
json(Value) when is_list(Value), Value =/= [] ->
    case io_lib:printable_unicode_list(Value) of
        true -> bin(Value);
        false -> [json(V) || V <- Value]
    end;
json(Value) when Value =:= true; Value =:= false; Value =:= null -> Value;
json(Value) when is_atom(Value) -> atom_to_binary(Value);
json(Value) when is_pid(Value); is_reference(Value); is_function(Value); is_port(Value) -> text(Value);
json(Value) -> Value.
json_value(Value) when is_map(Value) ->
    lists:all(fun({K,V}) -> is_binary(K) andalso json_value(V) end, maps:to_list(Value));
json_value(Value) when is_list(Value) -> lists:all(fun json_value/1, Value);
json_value(Value) -> is_binary(Value) orelse is_number(Value) orelse
    Value =:= true orelse Value =:= false orelse Value =:= null.
key(K) when is_binary(K) -> K;
key(K) when is_atom(K) -> atom_to_binary(K);
key(K) when is_list(K) -> bin(K);
key(K) -> text(K).
read_json(Path) -> {ok, Bytes} = file:read_file(Path), json:decode(Bytes).
write_json(Path, Value) ->
    ok = filelib:ensure_dir(Path),
    Temp = Path ++ "." ++ integer_to_list(erlang:unique_integer([positive])) ++ ".tmp",
    ok = file:write_file(Temp, [json:encode(json(Value)), $\n]),
    ok = file:rename(Temp, Path).

absolute(Path0) ->
    Path = unicode:characters_to_list(Path0),
    absolute = filename:pathtype(Path),
    false = lists:member("..", filename:split(Path)),
    filename:join([P || P <- filename:split(Path), P =/= "."]).
owned_path(Product, Path0) ->
    Path = absolute(Path0),
    Scratch = filename:join(filename:dirname(absolute(Product)), "tmp"),
    true = lists:prefix(Scratch ++ "/", Path),
    no_symlink_ancestors(Path),
    Path.
owned_work(Product, Base0) ->
    Base = owned_path(Product, Base0),
    ok = filelib:ensure_path(Base),
    Id = binary_to_list(binary:encode_hex(crypto:strong_rand_bytes(8), lowercase)),
    Run = filename:join([Base, "runs", Id]),
    ok = filelib:ensure_path(Run),
    Run.
no_symlink_ancestors("/") -> ok;
no_symlink_ancestors(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type=symlink}} -> error({symlink_work_path, Path});
        _ -> case filename:dirname(Path) of Path -> ok; Parent -> no_symlink_ancestors(Parent) end
    end.

copy(From, To) ->
    ok = filelib:ensure_dir(To),
    case file:read_link_info(From) of
        {ok, #file_info{type=symlink}} ->
            {ok, Target} = file:read_link(From),
            ok = file:make_symlink(Target, To);
        {ok, #file_info{mode=Mode}} ->
            {ok, _} = file:copy(From, To),
            ok = file:change_mode(To, Mode)
    end.
copy_tree(From, To) ->
    {ok, #file_info{type=Type}} = file:read_link_info(From),
    case Type of
        directory ->
            ok = filelib:ensure_path(To),
            {ok, Names} = file:list_dir(From),
            lists:foreach(fun(N) -> copy_tree(filename:join(From,N), filename:join(To,N)) end, Names);
        _ -> copy(From, To)
    end.

%% The test process receives a fresh installation, never a writable producer.
%% These receipts describe filesystem states, not transient write history.
prepare_runtime(Ctx) ->
    Product=maps:get(source_root,Ctx),
    Producer=absolute(maps:get(candidate_prefix,Ctx)),
    Producer=canonical_path(Producer),
    Work=owned_path(Product,maps:get(work_root,Ctx)),
    Runtime=owned_path(Product,filename:join(Work,"runtime")),
    false=inside(Producer,Runtime) orelse inside(Runtime,Producer),
    Before=installation_tree(Producer),
    validate_installation(Producer,Before),
    case file:make_dir(Runtime) of
        ok->ok;
        Error->error({runtime_destination_not_fresh,Runtime,Error})
    end,
    Path=filename:join(Work,"runtime-copy.json"),
    Base=#{format=>1,type=><<"runtime-copy">>,producer_prefix=>bin(Producer),
           runtime_prefix=>bin(Runtime),producer_tree=>Before,
           producer_tree_sha256=>hash(Before),copy_method=><<"file-copy-no-hardlinks">>},
    ok=write_json(Path,Base#{phase=><<"copying">>}),
    ok=copy_tree(Producer,Runtime),
    Directories=[{P,M} || {P,#{kind:=directory,mode:=M}}<-maps:to_list(Before)],
    lists:foreach(fun({P,M})->
        ok=file:change_mode(filename:join(Runtime,unicode:characters_to_list(P)),M)
    end,lists:sort(fun({A,_},{B,_})->
        length(filename:split(A))>length(filename:split(B))
    end,Directories)),
    Copied=installation_tree(Runtime),
    validate_installation(Runtime,Copied),
    After=installation_tree(Producer),
    CopyChanges=tree_changes(Before,Copied),
    ProducerChanges=tree_changes(Before,After),
    NoHardlinks=no_producer_hardlinks(Producer,Runtime,Before),
    Verified=Before=:=Copied andalso Before=:=After andalso NoHardlinks,
    Receipt=runtime_receipt(Path,Base#{phase=><<"finished">>,verified=>Verified,
        runtime_tree_sha256=>hash(Copied),producer_unchanged=>Before=:=After,
        producer_changes=>ProducerChanges,copy_changes=>CopyChanges,no_hardlinks=>NoHardlinks}),
    case Verified of
        true->{Ctx#{runtime_prefix=>Runtime,
                    runtime_view=>#{producer=>Producer,runtime=>Runtime,baseline=>Before,
                                    copy_receipt=>maps:get(receipt,Receipt)}},Receipt};
        false->error({runtime_copy_verification_failed,Receipt})
    end.

finish_runtime(Ctx) ->
    #{producer:=Producer,runtime:=Runtime,baseline:=Before,copy_receipt:=Copy}=maps:get(runtime_view,Ctx),
    Producer=absolute(maps:get(candidate_prefix,Ctx)),
    Runtime=absolute(maps:get(runtime_prefix,Ctx)),
    CopyPath=unicode:characters_to_list(maps:get(path,Copy)),
    true=sha(CopyPath)=:=maps:get(sha256,Copy),
    ProducerAfter=installation_tree(Producer),
    RuntimeAfter=installation_tree(Runtime),
    ProducerChanges=tree_changes(Before,ProducerAfter),
    RuntimeChanges=tree_changes(Before,RuntimeAfter),
    Unchanged=Before=:=ProducerAfter,
    NeedsReview=map_size(maps:get(changed,RuntimeChanges))>0 orelse
                map_size(maps:get(deleted,RuntimeChanges))>0,
    Receipt=runtime_receipt(filename:join(maps:get(work_root,Ctx),"runtime-changes.json"),
        #{format=>1,type=><<"runtime-changes">>,producer_prefix=>bin(Producer),
          runtime_prefix=>bin(Runtime),copy_receipt=>Copy,producer_unchanged=>Unchanged,
          producer_tree_sha256=>hash(ProducerAfter),runtime_tree_sha256=>hash(RuntimeAfter),
          producer_changes=>ProducerChanges,runtime_changes=>RuntimeChanges,
          requires_review=>NeedsReview}),
    case Unchanged of true->Receipt;false->error({producer_installation_changed,Receipt}) end.

runtime_receipt(Path,Value) ->
    ok=write_json(Path,Value),Value#{receipt=>#{path=>bin(Path),sha256=>sha(Path)}}.

%% Validate the immutable receipts without recopying or classifying test output.
verify_runtime_receipts(CopyRef0,FinalRef0) ->
    try
        {Copy,CopyRef}=read_runtime_receipt(CopyRef0),
        {Final,FinalRef}=read_runtime_receipt(FinalRef0),
        CopyPath=unicode:characters_to_list(maps:get(path,CopyRef)),
        FinalPath=unicode:characters_to_list(maps:get(path,FinalRef)),
        "runtime-copy.json"=filename:basename(CopyPath),
        "runtime-changes.json"=filename:basename(FinalPath),
        Work=filename:dirname(CopyPath),Work=filename:dirname(FinalPath),
        1=maps:get(<<"format">>,Copy),1=maps:get(<<"format">>,Final),
        <<"runtime-copy">>=maps:get(<<"type">>,Copy),
        <<"runtime-changes">>=maps:get(<<"type">>,Final),
        <<"finished">>=maps:get(<<"phase">>,Copy),
        <<"file-copy-no-hardlinks">>=maps:get(<<"copy_method">>,Copy),
        true=maps:get(<<"verified">>,Copy),true=maps:get(<<"no_hardlinks">>,Copy),
        true=maps:get(<<"producer_unchanged">>,Copy),true=maps:get(<<"producer_unchanged">>,Final),
        Producer=maps:get(<<"producer_prefix">>,Copy),Producer=maps:get(<<"producer_prefix">>,Final),
        Producer=bin(absolute(Producer)),
        Runtime=bin(filename:join(Work,"runtime")),
        Runtime=maps:get(<<"runtime_prefix">>,Copy),Runtime=maps:get(<<"runtime_prefix">>,Final),
        false=inside(unicode:characters_to_list(Producer),unicode:characters_to_list(Runtime)) orelse
              inside(unicode:characters_to_list(Runtime),unicode:characters_to_list(Producer)),
        true=json(CopyRef)=:=maps:get(<<"copy_receipt">>,Final),
        Before=maps:get(<<"producer_tree">>,Copy),
        ok=validate_runtime_tree(Before),
        #{<<"kind">>:=<<"directory">>}=maps:get(<<".">>,Before),
        true=lists:all(fun(#{<<"kind">>:=K})->
            lists:member(K,[<<"directory">>,<<"regular">>,<<"symlink">>])
        end,maps:values(Before)),
        BeforeHash=hash(Before),
        BeforeHash=maps:get(<<"producer_tree_sha256">>,Copy),
        BeforeHash=maps:get(<<"runtime_tree_sha256">>,Copy),
        BeforeHash=maps:get(<<"producer_tree_sha256">>,Final),
        Empty=json(tree_changes(#{},#{})),
        Empty=maps:get(<<"copy_changes">>,Copy),
        Empty=maps:get(<<"producer_changes">>,Copy),
        Empty=maps:get(<<"producer_changes">>,Final),
        Changes=maps:get(<<"runtime_changes">>,Final),
        [<<"added">>,<<"changed">>,<<"deleted">>]=lists:sort(maps:keys(Changes)),
        Added=maps:get(<<"added">>,Changes),Changed=maps:get(<<"changed">>,Changes),
        Deleted=maps:get(<<"deleted">>,Changes),
        true=is_map(Added) andalso is_map(Changed) andalso is_map(Deleted),
        []=[P || P<-maps:keys(Added),maps:is_key(P,Before)],
        []=[P || P<-maps:keys(Changed),maps:is_key(P,Deleted)],
        maps:foreach(fun(P,V)->true=maps:get(P,Before)=:=V end,Deleted),
        Replaced=maps:map(fun(P,V)->
            [<<"after">>,<<"before">>]=lists:sort(maps:keys(V)),
            Old=maps:get(<<"before">>,V),Old=maps:get(P,Before),
            New=maps:get(<<"after">>,V),false=Old=:=New,New
        end,Changed),
        After=maps:merge(maps:merge(maps:without(maps:keys(Deleted),Before),Replaced),Added),
        ok=validate_runtime_tree(After),
        AfterHash=hash(After),AfterHash=maps:get(<<"runtime_tree_sha256">>,Final),
        NeedsReview=map_size(Changed)>0 orelse map_size(Deleted)>0,
        NeedsReview=maps:get(<<"requires_review">>,Final),
        #{producer_prefix=>Producer,runtime_prefix=>Runtime,producer_unchanged=>true,
          producer_tree_sha256=>BeforeHash,runtime_tree_sha256=>AfterHash,
          runtime_changes=>Changes,requires_review=>NeedsReview,
          copy_receipt=>CopyRef,changes_receipt=>FinalRef}
    catch Class:Reason -> error({invalid_runtime_receipts,Class,Reason}) end.

read_runtime_receipt(Ref0) ->
    Ref=json(Ref0),[<<"path">>,<<"sha256">>]=lists:sort(maps:keys(Ref)),
    Path=maps:get(<<"path">>,Ref),Path=bin(absolute(Path)),
    {ok,#file_info{type=regular}}=file:read_link_info(Path),
    {ok,Bytes}=file:read_file(Path),
    Expected=maps:get(<<"sha256">>,Ref),
    Expected=binary:encode_hex(crypto:hash(sha256,Bytes),lowercase),
    {json:decode(Bytes),#{path=>Path,sha256=>Expected}}.

validate_runtime_tree(Tree) ->
    true=is_map(Tree),
    maps:foreach(fun(P,V)->
        true=is_binary(P),Name=unicode:characters_to_list(P),
        case P of <<".">>->ok;_->
            relative=filename:pathtype(Name),true=Name=/=[],
            false=lists:any(fun(X)->X=:="." orelse X=:=".." end,filename:split(Name)),
            Name=filename:join(filename:split(Name)),
            Parent=case filename:dirname(Name) of "."-><<".">>;D->bin(D) end,
            #{<<"kind">>:=<<"directory">>}=maps:get(Parent,Tree)
        end,
        Mode=maps:get(<<"mode">>,V),true=is_integer(Mode) andalso Mode>=0 andalso Mode=<8#7777,
        case maps:get(<<"kind">>,V) of
            <<"regular">>->
                [<<"kind">>,<<"mode">>,<<"sha256">>]=lists:sort(maps:keys(V)),
                H=maps:get(<<"sha256">>,V),true=is_binary(H) andalso byte_size(H)=:=64,
                match=re:run(H,<<"^[0-9a-f]{64}$">>,[{capture,none}]);
            <<"symlink">>->
                [<<"kind">>,<<"mode">>,<<"sha256">>,<<"target">>]=lists:sort(maps:keys(V)),
                Target=maps:get(<<"target">>,V),true=is_binary(Target),
                H=maps:get(<<"sha256">>,V),H=binary:encode_hex(crypto:hash(sha256,Target),lowercase);
            K when K=:=<<"directory">>;K=:=<<"device">>;K=:=<<"other">> ->
                [<<"kind">>,<<"mode">>]=lists:sort(maps:keys(V))
        end
    end,Tree).

installation_tree(Root) ->
    case file:read_link_info(Root) of
        {error,enoent}->#{};
        {ok,_}->installation_tree(Root,Root,#{})
    end.
installation_tree(Root,Path,Acc) ->
    {ok,#file_info{type=Kind,mode=Mode}}=file:read_link_info(Path),
    Relative=case Path of Root-><<".">>;_->bin(string:prefix(Path,Root++"/")) end,
    Base=#{kind=>Kind,mode=>Mode band 8#7777},
    Value=case Kind of
        regular->Base#{sha256=>sha(Path)};
        symlink->{ok,Target}=file:read_link(Path),
                 Base#{target=>bin(Target),sha256=>binary:encode_hex(crypto:hash(sha256,bin(Target)),lowercase)};
        _->Base
    end,
    With=Acc#{Relative=>Value},
    case Kind of
        directory->{ok,Names}=file:list_dir(Path),
                   lists:foldl(fun(N,A)->installation_tree(Root,filename:join(Path,N),A) end,With,Names);
        _->With
    end.

validate_installation(Root,Tree) ->
    #{kind:=directory}=maps:get(<<".">>,Tree),
    maps:foreach(fun(Relative,#{kind:=Kind})->
        case Kind of
            regular->ok;
            directory->ok;
            symlink->true=inside(Root,canonical_path(filename:join(Root,unicode:characters_to_list(Relative))));
            _->error({unsupported_installation_file_type,Relative,Kind})
        end
    end,Tree).

no_producer_hardlinks(Producer,Runtime,Tree) ->
    lists:all(fun(Relative)->
        P=unicode:characters_to_list(Relative),
        {ok,Original}=file:read_file_info(filename:join(Producer,P)),
        {ok,Copied}=file:read_file_info(filename:join(Runtime,P)),
        case {Original#file_info.inode,Copied#file_info.inode} of
            {A,B} when is_integer(A),A>0,is_integer(B),B>0 ->
                {Original#file_info.major_device,A}=/={Copied#file_info.major_device,B};
            _->true %% file:copy is also used where inode metadata is unavailable.
        end
    end,[P || {P,#{kind:=regular}}<-maps:to_list(Tree)]).

tree_changes(Before,After) ->
    #{added=>maps:without(maps:keys(Before),After),
      deleted=>maps:without(maps:keys(After),Before),
      changed=>maps:from_list([{P,#{before=>Old,'after'=>New}} ||
          {P,Old}<-maps:to_list(Before),{ok,New}<-[maps:find(P,After)],Old=/=New])}.

command(Ctx, Program0, Args0, Cwd0, Label0) ->
    Program = absolute(Program0), Cwd = absolute(Cwd0),
    Args = [unicode:characters_to_list(A) || A <- Args0],
    Label = unicode:characters_to_list(Label0),
    false = lists:member($/, Label),
    Log = filename:join([maps:get(work_root, Ctx), "commands", Label ++ ".log"]),
    ok = filelib:ensure_dir(Log),
    {ok, Io} = file:open(Log, [write,binary]),
    Record = #{program=>bin(Program), arguments=>[bin(A)||A<-Args], cwd=>bin(Cwd), log=>bin(Log)},
    write_json(Log ++ ".command.json", Record),
    try
        Port = open_port({spawn_executable,Program}, [binary,exit_status,stderr_to_stdout,
                                                     use_stdio,{args,Args},{cd,Cwd}]),
        Status = collect(Port, Io),
        ok = file:close(Io),
        Finished = Record#{exit_status=>Status,log_sha256=>sha(Log)},
        write_json(Log ++ ".command.json", Finished),
        case Status of 0 -> Finished; _ -> error({command_failed,Finished}) end
    catch C:R:S -> file:close(Io), erlang:raise(C,R,S)
    end.
collect(Port, Io) ->
    receive
        {Port,{data,Bytes}} -> ok=file:write(Io,Bytes),collect(Port,Io);
        {Port,{exit_status,Status}} -> Status
    end.

environment(Ctx) ->
    Candidate = maps:get(candidate_prefix,Ctx),
    Candidate = absolute(code:root_dir()),
    Product = maps:get(source_root,Ctx),
    Work = maps:get(work_root,Ctx),
    case {maps:get(action,Ctx),maps:get(domain,Ctx)} of
        {run,D} when D =/= 'yielding-c-fun' ->
            {ok,[[Home]]}=init:get_argument(home),
            case try owned_path(Product,Home) catch _:_ -> invalid end of
                Home -> ok;
                _ -> error({missing_prerequisite,owned_controller_home})
            end,
            Home=os:getenv("HOME"),ok=filelib:ensure_path(Home);
        _ ->
            H=filename:join(Work,"home"),ok=filelib:ensure_path(H),os:putenv("HOME",H)
    end,
    Temp=case os:getenv("TMPDIR") of
        false->filename:join(Work,"tmp");P0->
            case try owned_path(Product,P0) catch _:_ -> invalid end of
                P0->P0;_->filename:join(Work,"tmp") end
    end,
    ok=filelib:ensure_path(Temp),os:putenv("TMPDIR",Temp),os:putenv("TMP",Temp),os:putenv("TEMP",Temp),
    lists:foreach(fun os:unsetenv/1, ["ERL_FLAGS","ERL_AFLAGS","ERL_ZFLAGS","ERL_LIBS",
        "ERL_COMPILER_OPTIONS","ERL_TOP","CFLAGS","CXXFLAGS","CPPFLAGS","LDFLAGS",
        "CONFIG_FLAGS","MAKEFLAGS","ERL_EXTREME_TESTING"]),
    os:putenv("ERL_FLAGS", "+S 2:2 +SDcpu 1 +SDio 1 -start_epmd false"),
    Tools = maps:get(tools,Ctx),
    lists:foreach(fun({Env,Name}) ->
        case maps:get(Name,Tools,undefined) of undefined->ok; P->os:putenv(Env,P) end
    end,[{"CC",cc},{"CXX",cxx},{"JAVAC",javac}]),
    Inputs = maps:get(inputs,Ctx,#{}),
    InputIdentity = validate_inputs(Inputs,Candidate),
    activate_proper(maps:get(proper,InputIdentity)),
    Paths = native_paths(Ctx),
    Separator = case platform() of win32 -> ";"; _ -> ":" end,
    os:putenv("PATH",string:join([filename:join(Candidate,"bin") | Paths],Separator)),
    Releases = filename:join(Work,"historical-releases"),
    ok = filelib:ensure_path(Releases),
    os:putenv("TEST_SERVER_RELEASE_ROOT",Releases),
    os:putenv("ERL_CRASH_DUMP",filename:join(Work,"erl_crash.dump")),
    ok.

native_paths(Ctx) ->
    Tools = [filename:dirname(P) || P <- maps:values(maps:get(tools,Ctx)), P =/= undefined],
    case platform() of
        win32 ->
            [] = selected_executables(maps:get(inputs,Ctx,#{})),
            System = case os:getenv("SystemRoot") of
                false -> error({missing_prerequisite,windows_system_root});
                Root -> filename:join(Root,"System32")
            end,
            Dirs = lists:usort([System | Tools]),
            %% Selected native tool directories must not expose another VM.
            lists:foreach(fun(Dir) ->
                case [N || N <- ["erl.exe","erlc.exe","escript.exe","epmd.exe"],
                           filelib:is_regular(filename:join(Dir,N))] of
                    [] -> ok;
                    Names -> error({missing_prerequisite,{native_tool_directory_contains_runtime,Dir,Names}})
                end
            end,Dirs),
            Dirs;
        _ ->
            View = filename:join(maps:get(work_root,Ctx),"tools"),
            ok = filelib:ensure_path(View),
            Dirs = lists:usort(Tools ++ ["/usr/bin","/bin","/usr/sbin","/sbin"]),
            install_executables(selected_executables(maps:get(inputs,Ctx,#{})),View),
            lists:foreach(fun(Dir) -> native_view(Dir,View) end,Dirs),
            [View]
    end.

native_view(Dir, View) ->
    Exclude = ["erl","erlc","escript","beam","beam.smp","erlexec","epmd","ct_run",
        "cerl","erl_call","erl_child_setup","run_erl","to_erl","dialyzer","typer","snmpc",
        "start","start_erl","inet_gethost"],
    {ok, Names} = file:list_dir(Dir),
    lists:foreach(fun(N) ->
        P=filename:join(Dir,N),
        case not lists:member(N,Exclude) andalso filelib:is_regular(P) andalso
             file:read_link_info(filename:join(View,N)) =:= {error,enoent} of
            true->ok=file:make_symlink(P,filename:join(View,N));false->ok
        end
    end,Names).

identity(Ctx) ->
    Root=maps:get(source_root,Ctx), Candidate=maps:get(candidate_prefix,Ctx),
    Pin=string:trim(binary_to_list(element(2,file:read_file(filename:join(Root,"UPSTREAM_COMMIT"))))),
    "550d7b7898706c7822362c42e7b93120c1d1f29a"=Pin,
    Selection=filename:join(maps:get(candidate_build,Ctx),"sdk-selection.txt"),
    S=selection(maps:get(candidate_build,Ctx)),
    true=bin(system_name())=:=maps:get(<<"platform">>,S),
    SDKArch=case architecture() of "x86_64"-><<"x86">>;_-><<"arm">> end,
    SDKArch=maps:get(<<"architecture">>,S),
    true=maps:get(target,Ctx)=:=binary_to_list(maps:get(<<"host_triple">>,S)),
    Manifest=unicode:characters_to_list(maps:get(<<"manifest">>,S)),
    true=content_sha(Manifest)=:=maps:get(<<"manifest_sha256">>,S),
    SDK=read_json(Manifest),
    [Variant]=[V || V<-maps:get(<<"variants">>,SDK),
         maps:get(<<"flavor">>,V)=:=maps:get(<<"flavor">>,S),
         maps:get(<<"build_type">>,V)=:=maps:get(<<"build_type">>,S)],
    true=maps:get(<<"build_id">>,Variant)=:=maps:get(<<"build_id">>,S),
    Prefix=unicode:characters_to_list(maps:get(<<"prefix">>,S)),
    case maps:get(sdk_root,Ctx,undefined) of undefined->ok;Prefix->ok;_->error(selected_sdk_root_mismatch) end,
    Files=maps:get(<<"common_files">>,SDK)++maps:get(<<"package_files">>,SDK)++maps:get(<<"files">>,Variant),
    lists:foreach(fun(F)-> true=content_sha(filename:join(Prefix,maps:get(<<"path">>,F)))=:=maps:get(<<"sha256">>,F) end,Files),
    Support=filename:join(Root,"tests/otp/support"),
    Helpers=lists:sort(filelib:wildcard(filename:join(Support,"otp_ct*.erl"))++
                      filelib:wildcard(filename:join(Support,"otp_ct*.sh"))++
                      [filename:join(Support,"otp_ct.escript"),filename:join(Support,"otp_ct_event.erl")]),
    Tools=maps:map(fun(_,P)->tool_identity(P) end,maps:get(tools,Ctx)),
    Config=maps:get(configured_source,Ctx,undefined),
    ConfigNames=["make/make_emakefile","make/output.mk","make/"++maps:get(target,Ctx)++"/otp.mk","lib/wx/config.mk"],
    ConfigIdentity=case Config of undefined->null;_->maps:from_list([{bin(N),maybe_sha(filename:join(Config,N))}||N<-ConfigNames]) end,
    Source= #{source_commit=>bin(Pin),manifest=>sha(filename:join(Root,"tests/otp/manifest.json")),
              adapter=>maps:from_list([{bin(filename:basename(P)),sha(P)}||P<-Helpers])},
    Inputs=maps:get(inputs,Ctx,#{}),
    InputIdentity=validate_inputs(Inputs,Candidate),
    ActualType=erlang:system_info(emu_type),
    ExpectedType=case maps:get(<<"build_type">>,S) of <<"Debug">>->debug;<<"Release">>->opt end,
    ExpectedType=ActualType,
    true=atom_to_binary(erlang:system_info(emu_flavor))=:=maps:get(<<"flavor">>,S),
    true=maps:get(<<"upstream">>,S)=:=bin(Pin),
    #{configuration=>[bin(system_name()),bin(architecture()),maps:get(<<"flavor">>,S),maps:get(<<"build_type">>,S)],
      runtime_configuration=>#{schedulers=>erlang:system_info(schedulers),
                               dirty_cpu_schedulers=>erlang:system_info(dirty_cpu_schedulers),
                               dirty_io_schedulers=>erlang:system_info(dirty_io_schedulers)},
      source=>Source#{yielding_input_registry=>sha(filename:join(Root,"cmake/OTPYieldingCInputs.cmake"))},
      sdk=>#{selection_sha256=>sha(Selection),manifest_sha256=>sha(Manifest),
                           source_id=>maps:get(<<"source_id">>,S),build_id=>maps:get(<<"build_id">>,S),
                           host_triple=>maps:get(<<"host_triple">>,S),
                           toolchain_id=>maps:get(<<"toolchain_id">>,S)},
       candidate=>#{root=>bin(Candidate),files=>tree_identity(Candidate),
                    tree_sha256=>hash(installation_tree(Candidate)),
                   erts=>bin(erlang:system_info(version)),flavor=>erlang:system_info(emu_flavor),
                   build_type=>maps:get(<<"build_type">>,S)},
      tools=>Tools,execution=>execution_identity(Ctx),
      inputs=>#{profile=>Inputs,profile_file=>tool_identity(maps:get(inputs_file,Ctx,undefined)),
                ct_config_files=>config_identities(Inputs),activated=>InputIdentity},
      configured_make=>ConfigIdentity}.

%% Linux process-name cleanup is safe only inside the selected launcher's
%% private PID/proc and network envelope. An input-profile flag cannot admit it.
linux_envelope(Ctx) ->
    try
        linux = platform(),
        Path0 = os:getenv("OTP_CT_LINUX_ENVELOPE"),
        true = is_list(Path0),
        Path = owned_path(maps:get(source_root,Ctx),Path0),
        disjoint_linux_inputs(Ctx,filename:dirname(Path)),
        Host = key_file(filename:join(Path,"host-namespaces")),
        Current = maps:from_list([begin
            {ok,Link}=file:read_link("/proc/self/ns/"++binary_to_list(K)),
            true=bin(Link)=/=maps:get(K,Host),
            {K,bin(Link)}
        end || K <- [<<"pid">>,<<"net">>,<<"mnt">>,<<"user">>,<<"ipc">>,<<"uts">>]]),
        {ok,Mounts}=file:read_file("/proc/self/mountinfo"),
        Rows=[F || L<-binary:split(Mounts,<<"\n">>,[global]),
                   F<-[binary:split(L,<<" ">>,[global])],length(F)>6],
        [Root]=[F || F<-Rows,lists:nth(5,F)=:=<<"/">>],
        true=lists:member(<<"ro">>,string:split(lists:nth(6,Root),<<",">>,all)),
        NativeRoots=native_root_record(maps:get(inputs,Ctx,#{}),Path),
        ReadOnly=maps:from_list([{bin(P),read_only_mount(P,Rows)} ||
            P<-["/usr","/etc","/etc/hosts","/etc/passwd","/etc/group","/etc/ssh/ssh_config"]]),
        ProducerMount=read_only_mount(absolute(maps:get(candidate_prefix,Ctx)),Rows),
        Selected=key_file(filename:join(Path,"selected-tools")),
        true=lists:all(fun(K)->maps:is_key(K,Selected) end,[<<"bwrap">>,<<"unshare">>,<<"ip">>]),
        Tools=maps:map(fun(_,P)->tool_identity(P) end,Selected),
        Effective=key_file(filename:join(Path,"effective-tool-sha256")),
        Effective=maps:map(fun(_,I)->maps:get(sha256,I) end,Tools),
        NSS=maps:from_list([begin H=sha(filename:join(Path,N)),H=sha("/etc/"++N),{bin(N),H} end ||
                           N<-["passwd","group"],filelib:is_regular(filename:join(Path,N))]),
        #{policy=><<"linux-private-process-network-v1">>,path=>bin(Path),
          host_namespaces=>Host,namespaces=>Current,root_read_only=>true,
          read_only_mounts=>ReadOnly,tools=>Tools,private_nss=>NSS,
          native_roots=>NativeRoots,producer_read_only=>ProducerMount}
    catch
        error:{missing_prerequisite,_}=Reason -> error(Reason);
        _:_ -> error({missing_prerequisite,verified_linux_execution_envelope})
    end.

read_only_mount(Path,Rows) ->
    Cover=[F || F<-Rows,lists:nth(5,F)=:=<<"/">> orelse
                           inside(unicode:characters_to_list(lists:nth(5,F)),Path)],
    Length=lists:max([byte_size(lists:nth(5,F)) || F<-Cover]),
    [Mount]=[F || F<-Cover,byte_size(lists:nth(5,F))=:=Length],
    Options=binary:split(lists:nth(6,Mount),<<",">>,[global]),
    {_,[<<"-">>,_,_,Super]}=lists:splitwith(fun(F)->F=/=<<"-">> end,Mount),
    SuperOptions=binary:split(Super,<<",">>,[global]),
    true=lists:member(<<"ro">>,Options) orelse lists:member(<<"ro">>,SuperOptions),
    #{mountpoint=>lists:nth(5,Mount),options=>Options,super_options=>SuperOptions}.

disjoint_linux_inputs(Ctx,Writable) ->
    Inputs=maps:get(inputs,Ctx,#{}),
    Roots=[maps:get(K,Ctx,undefined)||K<-[source_root,candidate_prefix,candidate_build,sdk_root,
                                       reference_git,configured_source,inputs_file]],
    Artifacts=[maps:get(<<"path">>,A)||A<-maps:values(maps:get(<<"artifacts">>,Inputs,#{}))],
    Configs=lists:append(maps:values(maps:get(<<"ct_config">>,Inputs,#{}))),
    Proper=case maps:get(<<"proper">>,Inputs,undefined) of undefined->[];P->[maps:get(<<"path">>,P)] end,
    Native=[maps:get(<<"path">>,R)||R<-maps:get(<<"native_roots">>,Inputs,[])],
    Declared=[absolute(P)||P<-Roots++Artifacts++Configs++Proper++Native++maps:values(maps:get(tools,Ctx,#{})),
                           P=/=undefined],
    Paths=lists:usort(Declared++[canonical_path(P)||P<-Declared]),
    Overlap=[P||P<-Paths,inside(Writable,P) orelse inside(P,Writable)],
    case Overlap of []->ok;_->error({missing_prerequisite,{linux_work_input_overlap,Writable,Overlap}}) end.

execution_identity(Ctx) ->
    case {platform(),os:getenv("OTP_CT_LINUX_ENVELOPE")} of
        {linux,false}->#{policy=>external};
        {linux,_}->maps:with([policy,tools,native_roots],linux_envelope(Ctx));
        _->#{policy=>native}
    end.

key_file(Path) ->
    {ok,Bytes}=file:read_file(Path),
    Pairs=[begin [K,V]=binary:split(Line,<<"=">>),true=K=/=<<>>,true=V=/=<<>>,{K,V} end ||
        Line<-binary:split(Bytes,<<"\n">>,[global]),Line=/=<<>>],
    true=length(Pairs)=:=map_size(maps:from_list(Pairs)),
    maps:from_list(Pairs).

selection(Build) ->
    {ok, Lines} = file:read_file(filename:join(Build,"sdk-selection.txt")),
    Pairs = [begin [K,V]=binary:split(L,<<"=">>),{K,V} end ||
        L <- binary:split(binary:replace(Lines,<<"\r">>,<<>>,[global]),<<"\n">>,[global]),L=/=<<>>],
    true = length(Pairs) =:= map_size(maps:from_list(Pairs)),
    maps:from_list(Pairs).
platform() -> case os:type() of
    {unix,linux}->linux; {unix,darwin}->darwin; {win32,_}->win32;
    Other->error({unsupported_native_platform,Other})
end.
system_name() -> case platform() of linux->"Linux";darwin->"Darwin";win32->"Windows" end.
architecture() ->
    [Arch|_] = string:split(erlang:system_info(system_architecture),"-",all),
    case {platform(),Arch} of
        {_,"x86_64"}->"x86_64"; {darwin,"aarch64"}->"arm64";
        {darwin,"arm64"}->"arm64"; {linux,"aarch64"}->"aarch64";
        Other->error({unsupported_native_architecture,Other})
    end.
installed_command(Prefix,Name) when is_atom(Name) -> installed_command(Prefix,atom_to_list(Name));
installed_command(Prefix,Name) ->
    Suffix = case platform() of win32->".exe";_->"" end,
    filename:join([Prefix,"bin",Name++Suffix]).

config_identities(Inputs)->maps:map(fun(_,Paths)->
    maps:from_list([{bin(P),content_sha(absolute(P))}||P<-Paths])
end,maps:get(<<"ct_config">>,Inputs,#{})).

validate_inputs(Inputs,Candidate) ->
    Unsupported = maps:keys(maps:without([<<"artifacts">>,<<"ct_config">>,<<"epmd_port">>,
                                          <<"proper">>,<<"executables">>,<<"native_roots">>],Inputs)),
    case Unsupported of [] -> ok; _ -> error({unsupported_input_fields,Unsupported}) end,
    maps:foreach(fun(_, Artifact)->
        Path=maps:get(<<"path">>,Artifact),
        true=content_sha(absolute(Path))=:=maps:get(<<"sha256">>,Artifact)
    end,maps:get(<<"artifacts">>,Inputs,#{})),
    maps:foreach(fun(_,Paths)->lists:foreach(fun(P)->true=filelib:is_regular(absolute(P)) end,Paths) end,
                 maps:get(<<"ct_config">>,Inputs,#{})),
    Proper = proper_input(maps:get(<<"proper">>,Inputs,undefined),Candidate),
    case Proper of null -> ok; _ -> reject_historical_program_config(Inputs) end,
    #{proper=>Proper,executables=>selected_executables(Inputs),native_roots=>native_roots(Inputs)}.

%% Ordered package roots supply native /usr and /etc resources only. They
%% must never introduce another OTP installation beside the selected candidate.
native_roots(Inputs) ->
    Records=maps:get(<<"native_roots">>,Inputs,[]),
    true=is_list(Records),
    case {platform(),Records} of
        {_,[]}->ok;
        {linux,_}->ok;
        _->error({missing_prerequisite,native_roots_require_linux})
    end,
    Roots=[begin
        []=maps:keys(maps:without([<<"path">>,<<"tree_sha256">>],Record)),
        Root=absolute(maps:get(<<"path">>,Record)),Root=canonical_path(Root),
        false=lists:member($\n,Root),false=lists:member($\r,Root),
        Tree=closed_tree(Root),Expected=maps:get(<<"tree_sha256">>,Record),Actual=hash(Tree),
        case Actual=:=Expected of
            true->ok;
            false->error({native_root_hash_mismatch,Root,Expected,Actual})
        end,
        maps:foreach(fun(Relative,_)->native_root_path(unicode:characters_to_list(Relative)) end,Tree),
        #{path=>bin(Root),expected_tree_sha256=>Expected,tree_sha256=>Actual,tree=>Tree}
    end || Record<-Records],
    Paths=[maps:get(path,R)||R<-Roots],true=length(Paths)=:=length(lists:usort(Paths)),
    Roots.

native_root_path(Relative) ->
    Parts=filename:split(Relative),
    false=filename:extension(Relative)=:=".beam",
    case Parts of
        ["usr",Lib,Dir|_] when Lib=:="lib";Lib=:="lib64" -> false=erlang_directory(Dir);
        ["usr","local",Lib,Dir|_] when Lib=:="lib";Lib=:="lib64" -> false=erlang_directory(Dir);
        _->ok
    end,
    case Parts of
        ["usr",Bin,Name] when Bin=:="bin";Bin=:="sbin" -> false=runtime_command(Name);
        ["usr","local",Bin,Name] when Bin=:="bin";Bin=:="sbin" -> false=runtime_command(Name);
        [Bin,Name] when Bin=:="bin";Bin=:="sbin" -> false=runtime_command(Name);
        _->ok
    end.
erlang_directory(Name) -> Name=:="erlang" orelse lists:prefix("erlang-",Name).

native_root_record(Inputs,Path) ->
    Roots=native_roots(Inputs),
    Record=iolist_to_binary([[maps:get(path,R),$\n] || R<-Roots]),
    {ok,Record}=file:read_file(filename:join(Path,"native-roots")),
    Roots.

%% Closed immutable application data; the digest uses the existing tree method.
input_tree(Path) -> hash(closed_tree(Path)).
closed_tree(Path) ->
    Root=canonical_path(absolute(Path)),
    {ok,#file_info{type=directory}}=file:read_link_info(Root),
    %% Reject special files before reading bytes (a FIFO must not block an
    %% identity check), and bind directory modes as well as file/link data.
    Directories=closed_directories(Root,Root),
    Tree=maps:merge(Directories,tree_identity(Root)),
    maps:foreach(fun(Relative,#{kind:=Kind})->
        P=filename:join(Root,unicode:characters_to_list(Relative)),
        case Kind of
            regular -> ok;
            directory -> ok;
            symlink -> true=inside(Root,canonical_path(P));
            _ -> error({unsupported_input_file_type,P,Kind})
        end
    end,Tree),
    Tree.

closed_directories(Root,Dir) ->
    {ok,#file_info{type=directory,mode=Mode}}=file:read_link_info(Dir),
    Relative=case Dir of Root-><<".">>;_->bin(string:prefix(Dir,Root++"/")) end,
    {ok,Names}=file:list_dir(Dir),
    lists:foldl(fun(Name,Acc)->
        P=filename:join(Dir,Name),{ok,#file_info{type=Kind}}=file:read_link_info(P),
        case Kind of
            directory->maps:merge(Acc,closed_directories(Root,P));
            regular->Acc;
            symlink->true=inside(Root,canonical_path(P)),Acc;
            _->error({unsupported_input_file_type,P,Kind})
        end
    end,#{Relative=>#{kind=>directory,mode=>Mode band 8#777}},Names).

proper_input(undefined,_) -> null;
proper_input(Record,Candidate) ->
    []=maps:keys(maps:without([<<"path">>,<<"tree_sha256">>],Record)),
    Root=canonical_path(absolute(maps:get(<<"path">>,Record))),
    Name=filename:basename(Root),
    true=(Name=:="proper" orelse lists:prefix("proper-",Name)),
    Tree=closed_tree(Root),Expected=maps:get(<<"tree_sha256">>,Record),Actual=hash(Tree),
    case Actual=:=Expected of true->ok;false->error({proper_tree_hash_mismatch,Expected,Actual}) end,
    Ebin=filename:join(Root,"ebin"),Include=filename:join(Root,"include"),
    true=filelib:is_regular(filename:join(Include,"proper.hrl")),
    true=filelib:is_regular(filename:join(Include,"proper_common.hrl")),
    [AppFile]=filelib:wildcard(filename:join(Ebin,"*.app")),
    {ok,[{application,proper,Properties}]}=file:consult(AppFile),
    Modules=lists:sort(proplists:get_value(modules,Properties)),
    true=Modules=/=[],true=lists:member(proper,Modules),
    true=length(Modules)=:=length(lists:usort(Modules)),
    Beams=lists:sort(filelib:wildcard(filename:join(Ebin,"*.beam"))),
    Names=lists:sort([begin
        {ok,{Module,[{exports,_}]}}=beam_lib:chunks(Beam,[exports]),
        true=atom_to_list(Module)=:=filename:basename(Beam,".beam"),Module
    end || Beam<-Beams]),
    true=Modules=:=Names,
    Core=candidate_modules(Candidate),[]=[M || M<-Modules,lists:member(M,Core)],
    maps:foreach(fun(Relative,_)->
        Rel=unicode:characters_to_list(Relative),Base=filename:basename(Rel),
        case filename:extension(Rel) of
            ".app" -> true=Rel=:="ebin/proper.app";
            ".beam" -> true=filename:dirname(Rel)=:="ebin";
            _ -> ok
        end,
        false=runtime_command(Base),
        false=lists:any(fun(C)->C=:="erts" orelse lists:prefix("erts-",C) end,filename:split(Rel))
    end,Tree),
    Version=proplists:get_value(vsn,Properties),
    true=(is_list(Version) orelse is_binary(Version)),true=bin(Version)=/=<<>>,
    #{path=>bin(Root),ebin=>bin(Ebin),include=>bin(Include),
      version=>bin(Version),modules=>Modules,
      expected_tree_sha256=>Expected,tree_sha256=>Actual,tree=>Tree}.

candidate_modules(Candidate) ->
    lists:usort(erlang:pre_loaded()++[begin
        {ok,{Module,[{exports,_}]}}=beam_lib:chunks(Beam,[exports]),Module
    end || Beam<-filelib:wildcard(filename:join([Candidate,"lib","*","ebin","*.beam"]))]).

activate_proper(null) -> ok;
activate_proper(#{ebin:=Ebin0,include:=Include0}) ->
    Libraries=candidate_libraries(absolute(code:root_dir())),
    Ebin=unicode:characters_to_list(Ebin0),true=code:add_pathz(Ebin),
    Include=unicode:characters_to_list(Include0),Include=filename:join(absolute(code:lib_dir(proper)),"include"),
    Libraries=candidate_libraries(absolute(code:root_dir())),
    %% Candidate peers inherit this trailing path. Named-release launchers
    %% clear ERL_AFLAGS; the explicit historical {prog,Path} route does not.
    os:putenv("ERL_AFLAGS","-pz "++vm_word(Ebin)),ok.

candidate_libraries(Candidate) ->
    lists:sort([begin
        {ok,[{application,App,_}]}=file:consult(File),
        Expected=filename:dirname(filename:dirname(File)),
        Expected=absolute(code:lib_dir(App)),{App,Expected}
    end || File<-filelib:wildcard(filename:join([Candidate,"lib","*","ebin","*.app"]))]).

reject_historical_program_config(Inputs) ->
    maps:foreach(fun(_,Paths)->lists:foreach(fun(Path)->
        case file:consult(absolute(Path)) of
            {ok,Terms}->
                case historical_program_config(Terms) of
                    false->ok;
                    true->error({unsupported_input_combination,proper_and_historical_program_config,Path})
                end;
            Error->error({unverifiable_proper_historical_config,Path,Error})
        end
    end,Paths) end,maps:get(<<"ct_config">>,Inputs,#{})).
historical_program_config({otp_releases,_}) -> true;
historical_program_config(T) when is_tuple(T) -> historical_program_config(tuple_to_list(T));
historical_program_config([H|T]) -> historical_program_config(H) orelse historical_program_config(T);
historical_program_config(_) -> false.

%% Each key is an explicit native command referencing an existing hashed
%% artifact. Its containing directory is never exposed through PATH.
selected_executables(Inputs) ->
    Names=maps:get(<<"executables">>,Inputs,[]),
    true=is_list(Names),true=length(Names)=:=length(lists:usort(Names)),
    Artifacts=maps:get(<<"artifacts">>,Inputs,#{}),
    [begin
        Name=unicode:characters_to_list(Key),true=lists:member(Name,executable_names()),
        false=runtime_command(Name),Artifact=maps:get(Key,Artifacts),
        Declared=absolute(maps:get(<<"path">>,Artifact)),
        false=runtime_command(filename:basename(Declared)),Path=canonical_path(Declared),
        false=runtime_command(filename:basename(Path)),
        {ok,#file_info{type=regular,mode=Mode}}=file:read_link_info(Path),
        case platform() of win32->ok;_->true=(Mode band 8#111)=/=0 end,
        Expected=maps:get(<<"sha256">>,Artifact),Expected=content_sha(Path),
        #{name=>bin(Name),path=>bin(Path),declared_path=>bin(Declared),sha256=>Expected}
    end || Key<-Names].
executable_names() -> ["vsftpd","netstat","slapd","ldapadd","ldapmodify","openssl",
    "ssh","sshd","ssh-keygen","tmux","nano","vim","unbuffer","emacs","named",
    "dig","drill","snmpd","snmpget","snmpwalk","snmptrap","snmpset","snmptranslate",
    "mib2c","apache2","apache2ctl","httpd","tinyproxy","ncat","nginx","wget","docker"].
runtime_command(Name0) ->
    Name=string:lowercase(Name0),
    Base=case filename:extension(Name) of ".exe"->filename:rootname(Name);_->Name end,
    lists:prefix("beam.",Base) orelse lists:member(Base,["erl","erlc","escript","beam","beam.smp","beam.debug.smp",
        "erlexec","epmd","ct_run","cerl","erl_call","erl_child_setup","run_erl",
        "to_erl","dialyzer","typer","snmpc","start","start_erl","inet_gethost"]).
install_executables(Records,View) ->
    lists:foreach(fun(#{name:=Name,path:=Path})->
        Destination=filename:join(View,unicode:characters_to_list(Name)),
        case file:read_link_info(Destination) of
            {error,enoent}->ok;
            {ok,#file_info{type=symlink}}->ok=file:delete(Destination);
            Other->error({native_input_destination_not_symlink,Destination,Other})
        end,
        ok=file:make_symlink(unicode:characters_to_list(Path),Destination)
    end,Records).

inside(Root,Path) -> Root=:=Path orelse lists:prefix(Root++"/",Path).
canonical_path(Path) -> canonical_path(absolute(Path),0).
canonical_path(_,Links) when Links>40 -> error(input_symlink_cycle);
canonical_path(Path,Links) ->
    [Root|Parts]=filename:split(Path),resolve_parts(Parts,Root,Links).
resolve_parts([],Path,_) -> Path;
resolve_parts(["."|Rest],Path,Links) -> resolve_parts(Rest,Path,Links);
resolve_parts([".."|Rest],Path,Links) -> resolve_parts(Rest,filename:dirname(Path),Links);
resolve_parts([Part|Rest],Path,Links) ->
    Next=filename:join(Path,Part),
    case file:read_link_info(Next) of
        {ok,#file_info{type=symlink}}->
            {ok,Target}=file:read_link(Next),
            Full=case filename:pathtype(Target) of absolute->Target;relative->filename:join(Path,Target) end,
            canonical_path(filename:join([Full|Rest]),Links+1);
        {ok,_}->resolve_parts(Rest,Next,Links);
        Error->error({invalid_input_path,Next,Error})
    end.
vm_word(Word) -> [$"|lists:append([case C of $\\->"\\\\"; $"->"\\\""; _->[C] end || C<-Word])]++[$"].

tool_identity(undefined)->null;
tool_identity(<<>>)->null;
tool_identity("")->null;
tool_identity(Path)->
    P=absolute(Path),
    #{path=>bin(P),sha256=>content_sha(P)}.
maybe_sha(P)->case filelib:is_regular(P) of true->sha(P);false->missing end.
tree_identity(Root)->tree_identity(Root,Root,#{}).
tree_identity(Root,Dir,Acc)->
    {ok,Names}=file:list_dir(Dir),
    lists:foldl(fun(N,A)->
        P=filename:join(Dir,N),{ok,#file_info{type=T,mode=M}}=file:read_link_info(P),
        case T of directory->tree_identity(Root,P,A);_->
            Relative=bin(string:prefix(P,Root++"/")),
            H=case T of symlink->{ok,Link}=file:read_link(P),
                                  binary:encode_hex(crypto:hash(sha256,bin(Link)),lowercase);
                         _->sha(P) end,
            A#{Relative=>#{kind=>T,mode=>M band 8#777,sha256=>H}} end
    end,Acc,Names).

session(Ctx)->case maps:get(session_file,Ctx,undefined) of
    undefined->null;
    Path->S=read_json(Path),true=maps:get(<<"format">>,S)=:=1,S
end.
domains()->[kernel,stdlib,compiler,sasl,parsetools,syntax_tools,tools,runtime_tools,common_test,
    eunit,erl_interface,asn1,crypto,public_key,xmerl,mnesia,ssh,snmp,os_mon,inets,ssl,wx,et,
    debugger,observer,ftp,dialyzer,diameter,edoc,eldap,jinterface,megaco,odbc,reltool,tftp,
    emulator,system,epmd,'yielding-c-fun'].
