#!/usr/bin/env escript
%% SPDX-License-Identifier: Apache-2.0
%% Product-only upstream compiler flags. The deterministic seed recipe is
%% independent of these installed-application build choices.
-mode(compile).

main([Directory, Profile, Version]) ->
    Files = case Profile of
        "epmd" -> [filename:join(Directory, "erl_epmd.beam")];
        _ -> filelib:wildcard(filename:join(Directory, "*.beam"))
    end,
    Extra = case Profile of
        "compiler" -> [inline];
        "crypto" -> [{d, 'CRYPTO_VSN', Version}];
        "epmd" -> [{d, epmd_port_no, 4369}, {d, epmd_node_type, 110},
                   {d, epmd_dist_low, 5}, {d, epmd_dist_high, 6},
                   {d, erlang_daemon_port, 4369}];
        "mnesia" -> [{parse_transform, sys_pre_attributes},
                     {attribute, insert, vsn, "mnesia_" ++ Version}];
        "odbc" -> [{d, 'SERVER_SOFTWARE', "odbc/" ++ Version},
                   {parse_transform, sys_pre_attributes},
                   {attribute, insert, app_vsn, "odbc-" ++ Version}]
    end,
    lists:foreach(fun(File) ->
        {ok, {Module, [{compile_info, Info}]}} = beam_lib:chunks(File, [compile_info]),
        Source = proplists:get_value(source, Info),
        Options = proplists:get_value(options, Info),
        %% Upstream explicitly excludes its generated Core Erlang parser
        %% from compiler-wide inlining.
        ModuleExtra = case {Profile, Module} of
            {"compiler", core_parse} -> lists:delete(inline, Extra);
            _ -> Extra
        end,
        {ok, Module} = compile:noenv_file(Source,
            [{outdir, Directory}, report_errors, report_warnings | ModuleExtra ++ Options])
    end, Files).
