%% SPDX-License-Identifier: Apache-2.0
%% Execute the unchanged ordinary yielding-C regression driver.
-module(otp_ct_yielding).
-include_lib("kernel/include/file.hrl").
-export([run/1]).

run(Ctx) ->
    Identity = otp_ct_support:json(maps:get(identity, Ctx)),
    Base0 = #{format => 3, type => <<"supplemental-tool">>,
              component_kind => supplemental_tool, domain => <<"yielding-c-fun">>,
              profile => <<"full">>,  errors => [], identity => Identity,
              epoch => otp_ct_support:hash(maps:get(identity, Ctx)), started => timestamp()},
    Base = case maps:find(session, Ctx) of
        {ok, Session} -> Base0#{session => otp_ct_support:json(Session)};
        error -> Base0
    end,
    Result = try
        full = maps:get(profile, Ctx, full),
        State = prepare(Ctx),
        verify(State),
        Evidence = maps:get(evidence, State),
        case maps:get(action, Ctx, run) of
            prepare -> Evidence#{status => <<"prepared">>};
            run ->
                Command = try execute(Ctx, State)
                          catch error:{command_failed, Failed} -> Failed
                          end,
                verify(State),
                Exit = maps:get(exit_status, Command),
                Status = case Exit of 0 -> <<"passed">>; _ -> <<"failed">> end,
                Evidence#{status => Status, exit_status => Exit, command => Command,
                          inputs_unchanged => true, tools_unchanged => true}
        end
    catch
        throw:{blocked, Reason} -> #{status => <<"blocked">>, reason => otp_ct_support:json(Reason)};
        error:{command_failed, Record} ->
            #{status => <<"failed">>, exit_status => maps:get(exit_status, Record), command => Record};
        Class:Reason:Stack ->
            #{status => <<"failed">>, error => otp_ct_support:text({Class, Reason}),
              stack => otp_ct_support:json(Stack)}
    end,
    Merged = maps:merge(Base, Result),
    Merged#{phase => <<"finished">>, finished => timestamp()}.

prepare(Ctx) ->
    Product = maps:get(source_root, Ctx),
    Source = case maps:get(original_source, Ctx, undefined) of
        undefined -> Product;
        OriginalSource -> OriginalSource
    end,
    Registry = filename:join(Product, "cmake/OTPYieldingCInputs.cmake"),
    require_file(Registry),
    {ok, Data} = file:read_file(Registry),
    {match, [Pin]} = re:run(Data, <<"OTP_YCF_SOURCE_COMMIT[ \\t]+\"([0-9a-f]{40})\"">>,
                          [{capture, [1], binary}]),
    PinPath = filename:join(Product, "UPSTREAM_COMMIT"),
    {ok, SourcePin} = file:read_file(PinPath),
    Pin = string:trim(SourcePin),
    {match, Inputs} = re:run(Data, <<"\"([^\"\\n]+)\\|([0-9a-f]{64})\"">>,
                            [global, {capture, [1, 2], binary}]),
    Names = [Name || [Name, _] <- Inputs],
    true = length(Names) =:= length(lists:usort(Names)),
    true = lists:member(<<"bin/yielding_c_fun">>, Names),
    true = lists:member(<<"test/test.sh">>, Names),
    Work = maps:get(work_root, Ctx),
    false = lists:any(fun(C) -> lists:member(C, " \t\r\n;") end, Work),
    Run = filename:join(Work, "yielding-c"),
    {error, enoent} = file:read_link_info(Run),
    ok = file:make_dir(Run),
    Stage = filename:join(Run, "source"),
    Tools = filename:join(Run, "tools"),
    ok = filelib:ensure_path(Tools),
    ok = filelib:ensure_path(filename:join(Run, "home")),
    ok = filelib:ensure_path(filename:join(Run, "tmp")),
    Copied = [begin
        Relative = unicode:characters_to_list(Name),
        relative = filename:pathtype(Relative),
        false = lists:member("..", filename:split(Relative)),
        Origin = filename:join([Source, "erts/lib_src/yielding_c_fun", Relative]),
        regular = file_type(Origin),
        require_hash(Origin, Hash),
        Destination = filename:join(Stage, Relative),
        ok = otp_ct_support:copy(Origin, Destination),
        {Origin, Destination, Hash}
    end || [Name, Hash] <- Inputs],
    Clang = tool(Ctx, clang), Bash = tool(Ctx, bash),
    EnvName = case otp_ct_support:platform() of win32 -> "env.exe"; _ -> "env" end,
    Env = case os:find_executable(EnvName) of
        false -> throw({blocked, #{reason => missing_native_environment_tool, tool => EnvName}});
        FoundEnv -> otp_ct_support:absolute(FoundEnv)
    end,
    require_file(Env),
    VersionCommand = try otp_ct_support:command(Ctx, Clang, ["--version"], Run, "yielding-clang-version")
                     catch error:{command_failed, R} -> throw({blocked, #{reason => unusable_clang, command => R}})
                     end,
    {ok, Version} = file:read_file(maps:get(log, VersionCommand)),
    case binary:match(Version, <<"clang version">>) of
        nomatch -> throw({blocked, #{reason => clang_required, command => VersionCommand}});
        _ -> ok
    end,
    ToolNames = case otp_ct_support:platform() of win32 -> ["clang.exe","cc.exe"]; _ -> ["clang","cc"] end,
    lists:foreach(fun(Name) -> ok = file:make_symlink(Clang, filename:join(Tools, Name)) end,ToolNames),
    Candidate = maps:get(candidate_prefix, Ctx),
    Erts = unicode:characters_to_list(maps:get(erts_version, Ctx, erlang:system_info(version))),
    Suffix = case otp_ct_support:platform() of win32 -> ".exe"; _ -> "" end,
    Installed = filename:join([Candidate, "erts-" ++ Erts, "bin/yielding_c_fun" ++ Suffix]),
    regular = file_type(Installed),
    {ok, Binary} = file:read_file(Installed),
    StagedTool = filename:join(Stage, "bin/yielding_c_fun.bin"),
    ok = file:write_file(StagedTool, Binary),
    ok = file:change_mode(StagedTool, 8#755),
    ToolHash = otp_ct_support:sha(Installed),
    ToolHash = otp_ct_support:sha(StagedTool),
    Selected = [{P, otp_ct_support:sha(P)} || P <- [PinPath, Registry, Installed, StagedTool, Clang, Bash, Env]],
    Closure = [#{path => Name, sha256 => Hash} || [Name, Hash] <- Inputs],
    Evidence = #{source_commit => Pin, input_registry_sha256 => otp_ct_support:sha(Registry),
                 inputs => Closure, ordinary_driver_arguments => [], optional_nif_example => false,
                 tool => #{path => Installed, sha256 => otp_ct_support:sha(Installed)},
                 compiler => #{path => Clang, sha256 => otp_ct_support:sha(Clang),
                               version => Version, command => VersionCommand},
                 bash => #{path => Bash, sha256 => otp_ct_support:sha(Bash)},
                 input_identity => otp_ct_support:hash({Closure, Selected})},
    #{run => Run, stage => Stage, tools => Tools, clang => Clang, aliases => ToolNames, bash => Bash, env => Env,
      copied => Copied, selected => Selected, evidence => Evidence}.

execute(Ctx, State) ->
    Stage = maps:get(stage, State), Run = maps:get(run, State),
    Separator = case otp_ct_support:platform() of win32 -> ";"; _ -> ":" end,
    Path = string:join([maps:get(tools,State),filename:join(Stage,"bin"),os:getenv("PATH")],Separator),
    Args = ["-i", "PATH=" ++ Path,
            "HOME=" ++ filename:join(Run, "home"), "TMPDIR=" ++ filename:join(Run, "tmp") ++ "/",
            "LANG=C", "LC_ALL=C", maps:get(bash, State), filename:join(Stage, "test/test.sh")],
    otp_ct_support:command(Ctx, maps:get(env, State), Args, filename:join(Stage, "test"), "yielding-c-fun").

verify(State) ->
    lists:foreach(fun({Origin, Destination, Hash}) ->
        lists:foreach(fun(P) ->
            case file:read_link_info(P) of
                {ok, #file_info{type = regular}} -> Hash = otp_ct_support:sha(P);
                _ -> error({input_changed_during_run, P})
            end
        end,
                      [Origin, Destination])
    end, maps:get(copied, State)),
    lists:foreach(fun({P, Hash}) -> Hash = otp_ct_support:sha(P) end, maps:get(selected, State)),
    lists:foreach(fun(Name) ->
        {ok, Clang} = file:read_link(filename:join(maps:get(tools, State), Name)),
        Clang = maps:get(clang, State)
    end, maps:get(aliases,State)).

tool(Ctx, Name) ->
    case maps:get(Name, maps:get(tools, Ctx), undefined) of
        undefined -> throw({blocked, #{reason => missing_tool, tool => Name}});
        Path -> require_file(Path), otp_ct_support:absolute(Path)
    end.
require_file(Path) ->
    case filelib:is_regular(Path) of true -> ok; false -> throw({blocked, #{reason => missing_file, path => Path}}) end.
require_hash(Path, Hash) ->
    case otp_ct_support:sha(Path) of Hash -> ok; _ -> throw({blocked, #{reason => changed_pinned_input, path => Path}}) end.
file_type(Path) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = Type}} -> Type;
        {error, enoent} -> throw({blocked, #{reason => missing_file, path => Path}})
    end.
timestamp() -> otp_ct_support:bin(calendar:system_time_to_rfc3339(
    erlang:system_time(second), [{unit, second}, {offset, "Z"}])).
