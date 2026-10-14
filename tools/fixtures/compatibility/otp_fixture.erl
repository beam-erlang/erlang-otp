%% SPDX-License-Identifier: Apache-2.0
-module(otp_fixture).
-export([check/0]).

check() ->
    Prefix = os:getenv("BEAM_EXPECT_PREFIX"),
    true = is_list(Prefix),
    Prefix = code:root_dir(),
    LibraryPrefix = filename:join(Prefix, "lib") ++ "/",
    lists:foreach(fun(Module) ->
        {module, Module} = code:ensure_loaded(Module),
        Path = code:which(Module),
        true = is_list(Path),
        true = lists:prefix(LibraryPrefix, filename:absname(Path))
    end, [application, supervisor, gen_server, file, gen_tcp]),
    preloaded = code:which(prim_eval),
    true = lists:member(prim_eval, erlang:pre_loaded()),
    22 = length(erlang:pre_loaded()),
    lists:foreach(fun(Module) ->
        preloaded = code:which(Module),
        true = code:is_sticky(Module)
    end, [atomics, counters, persistent_term]),
    lists:foreach(fun(Module) ->
        true = lists:member(Module, erlang:pre_loaded()),
        true = code:is_sticky(Module),
        preloaded = code:which(Module),
        {file, preloaded} = code:is_loaded(Module)
    end, [init, erl_init]),
    %% Verify the executing image independently of application expectations.
    Host = filename:join([Prefix, "erts-" ++ erlang:system_info(version), "bin", "beam.smp"]),
    case os:type() of
        {unix, darwin} ->
            Observer = os:getenv("OTP_TEST_HOST_OBSERVER"),
            true = is_list(Observer),
            Probe = open_port({spawn_executable, Observer},
                              [binary, exit_status, {args, ["--images", os:getpid()]}]),
            Read = fun F(Acc) -> receive
                {Probe, {data, Bytes}} -> F(<<Acc/binary,Bytes/binary>>);
                {Probe, {exit_status, 0}} -> Acc
                after 5000 -> error(host_observation_timeout)
                end
            end,
            #{<<"executable">> := Exe, <<"files">> := Files} = json:decode(Read(<<>>)),
            Exe = unicode:characters_to_binary(Host),
            true = lists:member(Exe, Files),
            false = lists:any(fun(Name) ->
                lists:member(filename:basename(Name), [<<"libbeam.so">>, <<"libbeam.dylib">>])
            end, Files);
        _ ->
        {ok, Host} = file:read_link("/proc/self/exe"),
        {ok, Mappings} = file:read_file("/proc/self/maps"),
        true = binary:match(Mappings, unicode:characters_to_binary(Host)) =/= nomatch,
        nomatch = binary:match(Mappings, <<"libbeam.so">>)
    end,
    ok.
