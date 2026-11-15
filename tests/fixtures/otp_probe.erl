%% SPDX-License-Identifier: Apache-2.0
-module(otp_probe).
-export([identity/0, restart/0, peer/0, release/0]).
-include_lib("kernel/include/eep48.hrl").

identity() ->
    Root = filename:absname(os:getenv("OTP_TEST_ROOT")),
    Root = filename:absname(code:root_dir()),
    Apps = string:lexemes(os:getenv("OTP_TEST_APPS"),","),
    lists:foreach(fun(Name) ->
        App = list_to_atom(Name),
        case application:load(App) of
            ok -> ok;
            {error,{already_loaded,App}} -> ok
        end,
        AppRoot = filename:absname(code:lib_dir(App)),
        true = lists:prefix(Root ++ "/", AppRoot),
        {ok, Modules} = application:get_key(App, modules),
        lists:foreach(fun(Module) ->
            Beam = filename:join([AppRoot,"ebin",atom_to_list(Module) ++ ".beam"]),
            %% Inspect declarations without executing every module's on_load.
            {ok,{Module,[{exports,_}]}} = beam_lib:chunks(Beam,[exports])
        end, Modules)
    end,Apps),
    lists:foreach(fun(Path) ->
        Absolute = filename:absname(Path),
        true = lists:prefix(Root ++ "/",Absolute) orelse
               lists:prefix(filename:absname(os:getenv("OTP_TEST_WORK")) ++ "/",Absolute)
    end,code:get_path()),
    Expected = list_to_atom(os:getenv("OTP_TEST_FLAVOR")),
    Actual = erlang:system_info(emu_flavor),
    true = (Expected =:= jit andalso Actual =:= jit) orelse
           (Expected =:= emu andalso Actual =:= emu),
    _ = diagnostics(),
    ok = preloads(Root),
    io:format("otp-identity-ok ~s ~p~n",[erlang:system_info(version),Actual]).

preloads(Root) ->
    Version = erlang:system_info(version),
    Erts = filename:join([Root,"lib","erts-" ++ Version]),
    Ebin = filename:join(Erts,"ebin"),
    Files = filelib:wildcard(filename:join(Ebin,"*.beam")),
    22 = length(Files),
    Modules = lists:map(fun(File) ->
        %% This is xref_base:abst/1's request; stripped execution seeds do not
        %% provide the inspection metadata consumed by OTP's analysis tools.
        {ok,{Module,[{abstract_code,{raw_abstract_v1,Forms}},
                     {attributes,Attributes},{documentation,Documentation}]}} =
            beam_lib:chunks(File,[abstract_code,attributes,documentation]),
        true = is_list(Forms) andalso Forms =/= [],
        true = is_list(Attributes),
        #docs_v1{metadata = Metadata} = Documentation,
        LogicalSource = filename:join(["erts","preloaded","src",atom_to_list(Module) ++ ".erl"]),
        LogicalSource = maps:get(source_path,Metadata),
        relative = filename:pathtype(LogicalSource),
        true = filelib:is_regular(filename:join([Erts,"src",filename:basename(LogicalSource)])),
        preloaded = code:which(Module),
        Module
    end,Files),
    Modules = lists:sort(erlang:pre_loaded()),
    {ok,{erts_internal,[{"Line",Line},{"Meta",Meta}]}} =
        beam_lib:chunks(filename:join(Ebin,"erts_internal.beam"),["Line","Meta"]),
    true = byte_size(Line) > 0,
    true = byte_size(Meta) > 0,
    {ok,[{application,erts,Properties}]} = file:consult(filename:join(Ebin,"erts.app")),
    Version = proplists:get_value(vsn,Properties),
    ok.

restart() ->
    _ = diagnostics(),
    Path = filename:join(os:getenv("OTP_TEST_WORK"),"restart.marker"),
    case file:read_file(Path) of
        {error,enoent} ->
            ok = file:write_file(Path,<<"restart-requested">>),
            init:restart();
        {ok,<<"restart-requested">>} ->
            io:put_chars("otp-restart-ok\n"),
            halt(0)
    end.

peer() ->
    Erl = filename:join([code:root_dir(),"bin","erl"]),
    {ok,Peer,Node} = peer:start_link(#{name => otp_probe_peer,
        connection => standard_io, exec => Erl,
        args => ["+S","2:2","+SDcpu","1","+SDio","1",
                 "-setcookie",atom_to_list(erlang:get_cookie())]}),
    try
        pong = net_adm:ping(Node),
        Node = rpc:call(Node,erlang,node,[]),
        Root = code:root_dir(),
        Root = rpc:call(Node,code,root_dir,[]),
        Diagnostics = diagnostics(),
        Diagnostics = {peer:call(Peer,erlang,system_info,[build_type]),
                       peer:call(Peer,erlang,system_info,[debug_compiled]),
                       peer:call(Peer,erlang,system_info,[lock_checking])},
        2 = peer:call(Peer,erlang,length,[[one,two]])
    after peer:stop(Peer) end,
    io:put_chars("otp-peer-ok\n").

diagnostics() ->
    Expected = case os:getenv("OTP_TEST_BUILD_TYPE") of
                   "Release" -> {opt,false,false};
                   "Debug" -> {debug,true,true}
               end,
    Expected = {erlang:system_info(build_type),
                erlang:system_info(debug_compiled),
                erlang:system_info(lock_checking)}.

release() ->
    Work = os:getenv("OTP_TEST_WORK"),
    Apps = [kernel,stdlib,sasl],
    Versions = [begin
        _ = application:load(App),
        {ok,Vsn} = application:get_key(App,vsn),
        {App,Vsn}
    end || App <- Apps],
    Rel = {release,{"otp_probe","1"},{erts,erlang:system_info(version)},Versions},
    Name = filename:join(Work,"otp_probe"),
    ok = file:write_file(Name ++ ".rel",io_lib:format("~tp.~n",[Rel])),
    case systools:make_script(Name,[silent,{path,code:get_path()},{outdir,Work}]) of
        {ok,_,[]} -> ok;
        ok -> ok;
        Other -> error({release_failed,Other})
    end,
    {ok,_} = file:read_file(Name ++ ".boot"),
    io:put_chars("otp-release-created\n").
