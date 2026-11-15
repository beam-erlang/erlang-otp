#!/usr/bin/env escript
%%! +S 2:2 +SDcpu 1 +SDio 1 -noinput -boot start_sasl -sasl errlog_type error -enable-feature maybe_expr -start_epmd false -setcookie otp_ct_controller
-mode(compile).

%% Installed-runtime entry point. CT and original Make/ts own test semantics.
main(["--help"]) -> usage();
main([Action0 | Args]) ->
    put(report_path, undefined),
    try
        Product = product(),
        C = options(Args,#{}),
        Source0 = maps:get(source_root,C,Product),
        absolute = filename:pathtype(Source0),
        Source = filename:absname(Source0),
        compile_controller(Source),
        validate_outputs(C,Source),
        put(report_path,maps:get(report,C,undefined)),
        Action = action(Action0),
        Result = dispatch(Action,C,Source),
        case get(report_path) of undefined->ok;P->otp_ct_support:write_json(P,Result) end,
        io:format("otp-ct ~s: ~tp~n",[Action0,maps:get(status,Result,maps:get(complete,Result,unknown))]),
        case good(Result) of true->ok;false->halt(1) end
    catch Class:Reason:Stack ->
        Error = failure(Class,Reason,Stack),
        case get(report_path) of undefined->ok;P0->fallback_json(P0,Error) end,
        io:format(standard_error,"otp-ct failed: ~tp:~tp~n~tp~n",[Class,Reason,Stack]),
        halt(1)
    end;
main(_) -> usage(),halt(2).

usage()->io:format("otp_ct.escript run|prepare --domain APP|emulator|system|epmd|yielding-c-fun~n"
    "  --profile full|suite [--suite SUITE [--group GROUP] [--case CASE]]~n"
    "  --source-root REPO --candidate-prefix INSTALL --candidate-build BUILD --sdk-root SDK~n"
    "  --reference-git REPO --configured-source TREE --work-root WORKSPACE/tmp/OWNED~n"
    "  --make TOOL --cc TOOL --cxx TOOL --git TOOL --tar TOOL --javac TOOL~n"
    "  [--perl TOOL --wx-config TOOL --clang TOOL --bash TOOL --inputs JSON] --report JSON~n"
    "Other actions: inventory; begin --session-file JSON; reconcile with the same candidate/tool/input~n"
    "arguments plus --session-file JSON --input-report JSON ... --report JSON;~n"
    "selftest --work-root WORKSPACE/tmp/OWNED --report JSON.~n").
action("run")->run;action("prepare")->prepare;action("inventory")->inventory;
action("begin")->'begin';action("reconcile")->reconcile;action("selftest")->selftest;
action(A)->error({invalid_action,A}).
product()->
    P=filename:absname(escript:script_name()),
    filename:dirname(filename:dirname(filename:dirname(filename:dirname(P)))).
options([],C)->C;
options(["--"++K,V|T],C)->
    Allowed=["source-root","candidate-prefix","candidate-build","sdk-root","reference-git",
        "configured-source","work-root","inputs","report","session-file","input-report",
        "domain","profile","suite","group","case","make","cc","cxx","git","tar",
        "javac","perl","wx-config","clang","bash","flavor","build-type"],
    true=lists:member(K,Allowed),
    Key=key(K),
    case Key of
        input_report->options(T,C#{Key=>maps:get(Key,C,[])++[V]});
        _->false=maps:is_key(Key,C),options(T,C#{Key=>V})
    end;
options(_,_) -> error(invalid_arguments).
key("case")->testcase;
key(K)->list_to_atom([case X of $-->$_;_->X end||X<-K]).
path(K,C,Default)->
    case maps:get(K,C,Default) of undefined->undefined;""->undefined;P->otp_ct_support:absolute(P) end.
compile_controller(Source)->
    Dir=filename:join(Source,"tests/otp/support"),
    lists:foreach(fun(M)->compile_module(filename:join(Dir,atom_to_list(M)++".erl"),M) end,
        [otp_ct_support,otp_ct_prepare,otp_ct_evidence,otp_ct_yielding,otp_ct_event]).
compile_module(File,Module)->
    Result=compile:file(File,[binary,debug_info,report_errors,report_warnings]),
    Binary=case Result of {ok,Module,B}->B;{ok,Module,B,_}->B;_->error({controller_compile_failed,File,Result}) end,
    {module,Module}=code:load_binary(Module,File,Binary),ok.
validate_outputs(C,Source)->
    lists:foreach(fun(K)->case maps:get(K,C,undefined) of
        undefined->ok;
        V->otp_ct_support:owned_path(Source,V),ok
    end end,[report,session_file]),
    ok.

dispatch(inventory,_C,Source)->
    M=otp_ct_support:read_json(filename:join(Source,"tests/otp/manifest.json")),
    B=maps:merge(maps:get(<<"batches">>,M),maps:get(<<"supplemental_batches">>,M,#{})),
    Ds=maps:map(fun(_,Batch)->
        Base=maps:get(<<"suites">>,Batch),
        Vs=[maps:get(<<"module">>,V)||V<-maps:get(<<"variants">>,Batch,[])],
        #{suites=>lists:usort(Base++Vs++maps:get(<<"generated_suites">>,Batch,[])),
          specification=>maps:get(<<"main_spec">>,Batch)}
    end,B),
    Excluded=case otp_ct_support:platform() of
        linux->#{emulator=>[mtx_SUITE],system=>[ethread_SUITE,erl_print_SUITE]};_->#{} end,
    #{status=>passed,format=>1,source_commit=>maps:get(<<"source_commit">>,M),
      domains=>Ds,excluded=>Excluded};
dispatch('begin',C,_Source)->
    File=maps:get(session_file,C),
    S=#{format=>1,id=>binary:encode_hex(crypto:strong_rand_bytes(16),lowercase),
        started=>timestamp(),expected_domains=>otp_ct_support:domains()},
    otp_ct_support:write_json(File,S),S#{status=>passed};
dispatch(reconcile,C,Source)->
    Paths=maps:get(input_report,C,[]),true=Paths=/=[],
    ExpectedDomains=otp_ct_support:domains(),
    %% Only main publishes. A partial matrix must never escape before its
    %% current candidate, SDK, inputs and session have been checked.
    Matrix=otp_ct_evidence:reconcile(Paths,ExpectedDomains,undefined),
    try
        Ctx=common_context(C,Source,reconcile),
        Identity=otp_ct_support:json(otp_ct_support:identity(Ctx)),
        Session=otp_ct_support:session(Ctx),
        otp_ct_evidence:bind_current(Matrix,Identity,Session)
    catch Class:Reason -> Matrix#{complete=>false,status=>failed,
        errors=>maps:get(errors,Matrix,[])++[#{kind=><<"current_identity_validation_failed">>,
                                             class=>Class,reason=>fmt(Reason)}]}
    end;
dispatch(selftest,C,Source)->
    Work=otp_ct_support:owned_work(Source,maps:get(work_root,C)),
    Probe=filename:join(Source,"tests/otp/otp_ct_evidence_probe.erl"),
    compile_module(Probe,otp_ct_evidence_probe),
    InputsFile=path(inputs,C,undefined),
    Inputs=case InputsFile of undefined->#{};_->otp_ct_support:read_json(InputsFile) end,
    Ctx=#{source_root=>Source,candidate_prefix=>code:root_dir(),work_root=>Work,
          action=>selftest,domain=>controller,tools=>#{},inputs=>Inputs,inputs_file=>InputsFile},
    otp_ct_support:environment(Ctx),
    Network=network(Ctx),
    try otp_ct_evidence_probe:run(filename:join(Work,"probe"))
    after stop_network(Ctx,Network) end;
dispatch(Action,C,Source) when Action=:=run;Action=:=prepare ->
    Profile=case maps:get(profile,C,"full") of "full"->full;"suite"->suite;_->error(invalid_profile) end,
    Domain=list_to_atom(maps:get(domain,C)),
    true=lists:member(Domain,otp_ct_support:domains()),
    Select=maps:from_list([{K,selectors(maps:get(K,C))}||K<-[suite,group,testcase],maps:is_key(K,C)]),
    case Profile of
        full->true=map_size(Select)=:=0;
        suite->true=maps:is_key(suite,Select),false=Domain=:='yielding-c-fun'
    end,
    reject_excluded(Domain,maps:get(suite,Select,[])),
    Common=common_context(C,Source,Action),
    Ctx0=maps:merge(Common#{domain=>Domain,profile=>Profile,
        ct_options=>selected_configs(maps:get(inputs,Common),Domain)},Select),
    put(context,Ctx0),
    Started=(base_report(Ctx0))#{phase=><<"started">>,status=><<"running">>,started=>timestamp()},
    otp_ct_support:write_json(maps:get(report,C),Started),
    otp_ct_support:environment(Ctx0),
    RuntimeSetup=runtime_setup(),
    Identity=otp_ct_support:json(otp_ct_support:identity(Ctx0)),
    Ctx1=Ctx0#{identity=>Identity,epoch=>otp_ct_support:hash(Identity),
              runtime_setup=>RuntimeSetup,runtime_facts=>runtime_facts(Ctx0)},
    Session=otp_ct_support:session(Ctx1),
    Ctx=case Session of null->Ctx1;_->Ctx1#{session=>Session} end,
    put(context,Ctx),
    Result=case Domain of
        'yielding-c-fun'->otp_ct_yielding:run(Ctx);
        _->run_ct(Action,Ctx)
    end,
    IdentityAfter=otp_ct_support:json(otp_ct_support:identity(Ctx)),
    Drift=IdentityAfter=/=Identity,
    Final=Result#{identity=>Identity,epoch=>otp_ct_support:hash(Identity),identity_at_finish=>IdentityAfter,
                  inputs_changed_during_run=>Drift,
                  finished=>timestamp(),phase=><<"finished">>},
    case Drift of true->Final#{status=><<"failed">>,errors=>maps:get(errors,Final,[])++[<<"input_identity_changed_during_run">>]};
                  false->Final end.

common_context(C,Source,Action)->
    Candidate=path(candidate_prefix,C,code:root_dir()),
    Candidate=otp_ct_support:absolute(code:root_dir()),
    Build=path(candidate_build,C,undefined),
    SDK=otp_ct_support:selection(Build),
    ExpectedFlavor=binary_to_list(maps:get(<<"flavor">>,SDK)),
    ExpectedFlavor=maps:get(flavor,C,ExpectedFlavor),
    ExpectedType=binary_to_list(maps:get(<<"build_type">>,SDK)),
    ExpectedType=maps:get(build_type,C,ExpectedType),
    Work=case Action of
        reconcile->case path(work_root,C,undefined) of
            undefined->undefined;P->otp_ct_support:owned_path(Source,P) end;
        _->otp_ct_support:owned_work(Source,maps:get(work_root,C))
    end,
    Tools=maps:from_list([{K,tool_value(maps:get(K,C,undefined))}||K<-
        [make,cc,cxx,git,tar,javac,perl,wx_config,clang,bash]]),
    InputsFile=path(inputs,C,undefined),
    Inputs=case InputsFile of undefined->#{};F->otp_ct_support:read_json(F) end,
    #{source_root=>Source,candidate_prefix=>Candidate,
        candidate_build=>Build,sdk_root=>path(sdk_root,C,undefined),
        platform=>otp_ct_support:platform(),architecture=>otp_ct_support:architecture(),
        target=>binary_to_list(maps:get(<<"host_triple">>,SDK)),
        session_file=>path(session_file,C,undefined),
        reference_git=>path(reference_git,C,undefined),configured_source=>path(configured_source,C,undefined),
        work_root=>Work,action=>Action,tools=>Tools,inputs=>Inputs,inputs_file=>InputsFile,
        report=>maps:get(report,C),
        erts_version=>erlang:system_info(version),
        flavor=>erlang:system_info(emu_flavor),build_type=>runtime_type()}.

run_ct(Action,Ctx)->
    Prepared=otp_ct_prepare:prepare(Ctx),
    otp_ct_support:write_json(filename:join(maps:get(work_root,Ctx),"preparation.json"),Prepared),
    case maps:get(status,Prepared) of
        blocked->(base_report(Ctx))#{status=><<"blocked">>,preparation=>Prepared,
            classification=><<"prerequisite_gap">>,errors=>[maps:get(reason,Prepared,missing_prerequisite)]};
        prepared when Action=:=prepare->(base_report(Ctx))#{status=><<"prepared">>,preparation=>Prepared};
        prepared->
            %% The original controller supplies ts_net_dir as a VM argument.
            %% An empty value and CT's local fallback resolve the same paths.
            %% Network-mounted test paths need their own execution envelope.
            case proplists:get_value(ts_net_dir,maps:get(variables,Prepared),"") of
                ""->ok;
                NetDir->error({missing_prerequisite,{network_mounted_test_paths,NetDir}})
            end,
            {RuntimeCtx,RuntimeCopy}=otp_ct_support:prepare_runtime(Ctx),
            Network=network(RuntimeCtx),
            RunCtx=execution_configs(RuntimeCtx,Prepared),
            put(context,RunCtx),
            Result=try
                Plan=otp_ct_evidence:plan(RunCtx,Prepared),
                otp_ct_support:write_json(filename:join(maps:get(work_root,Ctx),"selection.json"),Plan),
                otp_ct_evidence:execute(RunCtx,Prepared,Plan)
            after
                try stop_network(RunCtx,Network)
                after otp_ct_support:finish_runtime(RunCtx) end
            end,
            ChangesPath=filename:join(maps:get(work_root,Ctx),"runtime-changes.json"),
            RuntimeChanges0=otp_ct_support:read_json(ChangesPath),
            RuntimeChanges=RuntimeChanges0#{<<"receipt">>=>#{<<"path">>=>otp_ct_support:bin(ChangesPath),
                <<"sha256">>=>otp_ct_support:sha(ChangesPath)}},
            _=otp_ct_support:verify_runtime_receipts(maps:get(receipt,RuntimeCopy),
                maps:get(<<"receipt">>,RuntimeChanges)),
            Integrity=otp_ct_prepare:verify(Prepared),
            R=Result#{preparation=>#{path=>filename:join(maps:get(work_root,Ctx),"preparation.json"),
                    sha256=>otp_ct_support:sha(filename:join(maps:get(work_root,Ctx),"preparation.json"))},
                       runtime_installation=>#{copy=>RuntimeCopy,changes=>RuntimeChanges},
                       source_integrity=>Integrity,
                       orchestration_setup=>maps:get(runtime_setup,Ctx),
                       execution_network=>Network},
            Errors=case maps:get(status,Integrity) of
                passed->[];_->[<<"original_source_changed">>]
            end ++ case maps:get(<<"requires_review">>,RuntimeChanges,false) of
                false->[];true->[<<"runtime_input_changes_require_review">>]
            end,
            case Errors of []->R;_->R#{status=><<"failed">>,
                errors=>maps:get(errors,R,[])++Errors} end
    end.

network(Ctx)->
    Linux=otp_ct_support:platform()=:=linux,
    case Linux of true->otp_ct_support:linux_envelope(Ctx);false->ok end,
    SelectedPort=maps:get(<<"epmd_port">>,maps:get(inputs,Ctx),undefined),
    Port=case {Linux,SelectedPort} of
        {true,undefined}->"4369";
        {true,4369}->"4369";
        {true,<<"4369">>}->"4369";
        {true,_}->error({missing_prerequisite,private_linux_epmd_default_required});
        {false,undefined}->os:getenv("ERL_EPMD_PORT");
        {false,N} when is_integer(N)->integer_to_list(N);
        {false,V}->binary_to_list(V)
    end,
    case Port of false->error({missing_prerequisite,task_owned_epmd});_->ok end,
    case Linux of
        true->false=os:getenv("ERL_EPMD_PORT"),error=init:get_argument(epmd_port);
        false->true=list_to_integer(Port)>1024,true=Port=/="4369",os:putenv("ERL_EPMD_PORT",Port)
    end,
    {ok,Host}=inet:gethostname(),{ok,{127,_,_,_}}=inet:getaddr(Host,inet),
    os:putenv("ERL_FLAGS","+S 2:2 +SDcpu 1 +SDio 1 -start_epmd false"),
    Start=case Linux of
        true->
            {error,_}=erl_epmd:names(Host),
            Command=otp_ct_support:command(Ctx,otp_ct_support:installed_command(maps:get(candidate_prefix,Ctx),epmd),
                ["-daemon","-port",Port],
                maps:get(work_root,Ctx),"start-owned-epmd"),
            wait_epmd(Host,50),
            #{ownership=>linux_namespace,port=>list_to_integer(Port),command=>Command};
        false->{ok,_}=erl_epmd:names(Host),#{ownership=>external,port=>list_to_integer(Port)}
    end,
    Name=list_to_atom("otp_ct_"++filename:basename(maps:get(work_root,Ctx))),
    {ok,_}=net_kernel:start([Name,shortnames]),
    %% Original peer helpers supply their own -setcookie. An inherited duplicate
    %% makes auth ignore both flags. Unadorned peers use the owned home instead.
    CookieFile=otp_ct_support:owned_path(maps:get(source_root,Ctx),filename:join(os:getenv("HOME"),".erlang.cookie")),
    ok=file:write_file(CookieFile,atom_to_binary(erlang:get_cookie())),
    ok=file:change_mode(CookieFile,8#600),
    Owned=Start#{cookie_file=>#{path=>CookieFile,sha256=>otp_ct_support:sha(CookieFile),mode=>8#600}},
    case {Linux,maps:get(domain,Ctx)} of
        {true,epmd}->
            try Owned#{proxy_preflight=>proxy_preflight(Ctx)}
            catch C:R:S->stop_network(Ctx,Owned),erlang:raise(C,R,S) end;
        _->Owned
    end.

wait_epmd(_Host,0)->error({missing_prerequisite,owned_epmd_startup});
wait_epmd(Host,Left)->case erl_epmd:names(Host) of
    {ok,[]}->ok;{error,_}->receive after 100->wait_epmd(Host,Left-1) end;
    Other->error({owned_epmd_not_empty,Other})
end.

stop_network(Ctx,#{ownership:=linux_namespace,port:=Port})->
    ok=net_kernel:stop(),
    {ok,Host}=inet:gethostname(),
    {ok,[]}=erl_epmd:names(Host),
    otp_ct_support:command(Ctx,otp_ct_support:installed_command(maps:get(candidate_prefix,Ctx),epmd),
        ["-port",integer_to_list(Port),"-kill"],maps:get(work_root,Ctx),"stop-owned-epmd"),
    ok;
stop_network(_,_) -> ok.

%% The original negative cases also pass when SSH denies a channel. Prove a
%% real connection from the peer before letting those assertions run.
proxy_preflight(Ctx) ->
    try
        otp_ct_support:linux_envelope(Ctx),
        %% Use the same controlled PATH lookup as the original suite, including
        %% any explicitly selected native executable artifact.
        Program=os:find_executable("ssh"),true=is_list(Program),
        SSH=#{path=>otp_ct_support:bin(Program),sha256=>otp_ct_support:sha(Program)},
        [_,Host]=string:split(atom_to_list(node()),"@",all),
        true=Host=/="localhost" andalso Host=/="nohost",
        Args=["-L","2244:"++Host++":2243","otp-epmd-peer","read"],
        Log=filename:join(maps:get(work_root,Ctx),"epmd-proxy-preflight.log"),
        {ok,Listen}=gen_tcp:listen(2243,[binary,{active,false},{ip,{10,203,0,1}},{reuseaddr,true}]),
        try
            {ok,Io}=file:open(Log,[write,binary]),
            try
                Port=open_port({spawn_executable,Program},[binary,exit_status,stderr_to_stdout,use_stdio,{args,Args}]),
                try
                    Connect=fun Poll(0)->error(proxy_listener_timeout);
                        Poll(N)->case gen_tcp:connect({127,0,0,1},2244,[binary,{active,false}],100) of
                            {ok,C}->C;{error,_}->receive after 100->Poll(N-1) end
                        end end,
                    Exchange=try
                        Client=Connect(30),
                        try
                            {ok,Peer}=gen_tcp:accept(Listen,2000),
                            try
                                {ok,{{10,203,0,2},_}=PeerIP}=inet:peername(Peer),
                                {ok,{{10,203,0,1},2243}=LocalIP}=inet:sockname(Peer),
                                Challenge=crypto:strong_rand_bytes(32),
                                ok=gen_tcp:send(Client,Challenge),
                                {ok,Challenge}=gen_tcp:recv(Peer,32,2000),
                                ok=gen_tcp:send(Peer,Challenge),
                                {ok,Challenge}=gen_tcp:recv(Client,32,2000),
                                ok=gen_tcp:close(Client),{error,closed}=gen_tcp:recv(Peer,0,2000),
                                #{peer=>PeerIP,sockname=>LocalIP,
                                  challenge_sha256=>binary:encode_hex(crypto:hash(sha256,Challenge),lowercase)}
                            after gen_tcp:close(Peer) end
                        after gen_tcp:close(Client) end
                    catch Class:Reason->#{error=>{Class,Reason}} end,
                    try port_command(Port,<<"\n">>) catch _:_ ->ok end,
                    Deadline=erlang:monotonic_time(millisecond)+3000,
                    Wait=fun Collect()->
                        Left=Deadline-erlang:monotonic_time(millisecond),
                        case Left=<0 of
                            true->ssh_exit_timeout;
                            false->receive {Port,{data,B}}->ok=file:write(Io,B),Collect();
                                           {Port,{exit_status,N}}->N
                                   after Left->ssh_exit_timeout end
                        end end,
                    Exit=Wait(),ok=file:sync(Io),ok=gen_tcp:close(Listen),
                    Evidence=Exchange#{program=>SSH,arguments=>Args,log=>Log,
                        log_sha256=>otp_ct_support:sha(Log),exit_status=>Exit},
                    case {maps:is_key(error,Exchange),Exit} of
                        {false,0}->
                            lists:foreach(fun(P)->{ok,S}=gen_tcp:listen(P,[{ip,{0,0,0,0}},{reuseaddr,true}]),
                                                 gen_tcp:close(S) end,[2243,2244]),
                            Evidence#{status=>passed,ports_released=>#{service=>2243,proxy=>2244}};
                        _->error({proxy_transport_failed,Evidence})
                    end
                after
                    try port_command(Port,<<"\n">>) catch _:_ ->ok end,
                    try port_close(Port) catch _:_ ->ok end
                end
            after file:close(Io) end
        after gen_tcp:close(Listen) end
    catch C:R->error({missing_prerequisite,{verified_epmd_proxy,C,R}}) end.

execution_configs(#{domain:=epmd,platform:=linux}=Ctx,Prepared)->
    otp_ct_support:linux_envelope(Ctx),
    Config=otp_ct_support:owned_path(maps:get(source_root,Ctx),os:getenv("OTP_CT_LINUX_EPMD_CONFIG")),
    {ok,[{ssh_proxy_host,"otp-epmd-peer"}]}=file:consult(Config),
    Options=maps:get(ct_options,Ctx),
    Paths=case proplists:get_value(config,Options) of
        undefined->[filename:join(maps:get(server_dir,Prepared),F)||F<-["ts.config","ts.unix.config"]];
        Selected->Selected
    end,
    Ctx#{ct_options=>[{config,Paths++[Config]}|proplists:delete(config,Options)]};
execution_configs(Ctx,_)->Ctx.
runtime_type()->case erlang:system_info(emu_type) of debug->"Debug";opt->"Release";V->atom_to_list(V) end.
runtime_setup()->
    %% escript does not start SASL even when its boot arguments name start_sasl.
    %% Match the original erl -boot start_sasl controller using the public API.
    {ok,_}=application:ensure_all_started(sasl),
    true=lists:keymember(sasl,1,application:which_applications()),
    {ok,error}=application:get_env(sasl,errlog_type),
    #{launcher=>escript,boot_arguments=>init:get_argument(boot),
      sasl=>ensure_all_started,sasl_errlog_type=>error}.
runtime_facts(Ctx)->#{system_name=>otp_ct_support:bin(otp_ct_support:system_name()),os_type=>otp_ct_support:json(os:type()),
    emu_flavor=>erlang:system_info(emu_flavor),dynamic_trace=>erlang:system_info(dynamic_trace),
    lock_counting=>erlang:system_info(lock_counting),crypto_fips=>crypto:info_fips(),
    execution_envelope=>case otp_ct_support:platform() of linux->otp_ct_support:linux_envelope(Ctx);_->null end,
    mnesia_debug_compiled=>mnesia_lib:is_debug_compiled()}.
selected_configs(Inputs,Domain)->
    Paths=maps:get(atom_to_binary(Domain),maps:get(<<"ct_config">>,Inputs,#{}),[]),
    case Paths of []->[];_->[{config,[otp_ct_support:absolute(P)||P<-Paths]}] end.
selectors(Value)->
    Names=string:split(Value,",",all),
    true=Names=/=[],true=lists:all(fun valid_name/1,Names),
    true=length(Names)=:=length(lists:usort(Names)),
    [list_to_atom(N)||N<-Names].
valid_name([H|T])->H>=32 andalso H=/=127 andalso length(T)<200 andalso
    lists:all(fun(C)->C>=32 andalso C=/=127 end,T);
valid_name(_)->false.
reject_excluded(Domain,Suites)->
    Ex=case {otp_ct_support:platform(),Domain} of
        {linux,emulator}->[mtx_SUITE];{linux,system}->[ethread_SUITE,erl_print_SUITE];_->[] end,
    case [S||S<-Suites,lists:member(S,Ex)] of []->ok;Bad->error({excluded_selection,Bad}) end.
tool_value(undefined)->undefined;
tool_value("")->undefined;
tool_value(Value)->case lists:suffix("-NOTFOUND",Value) of true->undefined;false->otp_ct_support:absolute(Value) end.
base_report(Ctx)->maps:merge(#{format=>3,type=><<"ct">>,domain=>atom_to_binary(maps:get(domain,Ctx)),
    profile=>atom_to_binary(maps:get(profile,Ctx)),phase=><<"finished">>,work_root=>maps:get(work_root,Ctx)},maps:with([identity,epoch,session],Ctx)).
good(#{complete:=B})->B;
good(#{status:=S})->lists:member(S,[passed,prepared,<<"passed">>,<<"prepared">>]);
good(_)->false.
failure(Class,Reason,Stack)->
    Base=case get(context) of undefined->#{format=>3};Ctx->base_report(Ctx) end,
    Status=case Reason of {missing_prerequisite,_}-><<"blocked">>;_-><<"failed">> end,
    Base#{phase=><<"finished">>,status=>Status,finished=>timestamp(),
          error_class=>Class,errors=>[fmt(Reason)],stack=>fmt(Stack)}.
fmt(T)->iolist_to_binary(io_lib:format("~0tp",[T])).
timestamp()->list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second),[{offset,"Z"}])).
fallback_json(P,Map)->
    try otp_ct_support:write_json(P,Map)
    catch _:_ ->ok=filelib:ensure_dir(P),file:write_file(P,[json:encode(#{status=><<"failed">>,error=>fmt(Map)}),$\n]) end.
