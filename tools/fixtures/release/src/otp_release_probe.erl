%% SPDX-License-Identifier: Apache-2.0
-module(otp_release_probe).
-behaviour(application).
-behaviour(supervisor).
-export([start/2, stop/1, init/1, check/0]).

start(_, _) -> supervisor:start_link(?MODULE, []).
stop(_) -> ok.
init([]) -> {ok, {{one_for_one, 1, 5}, []}}.

check() ->
    Preloads = erlang:pre_loaded(),
    22 = length(Preloads),
    lists:foreach(fun(M) -> preloaded = code:which(M), true = code:is_sticky(M) end, Preloads),
    [] = erlang:system_info(taints),
    {ok, Drivers} = erl_ddll:loaded_drivers(),
    lists:foreach(fun(D) ->
        true = lists:member(D, Drivers),
        true = erl_ddll:info(D, linked_in_driver),
        {error, linked_in_driver} = erl_ddll:unload_driver(D)
    end, ["tcp_inet", "udp_inet", "ram_file_drv"]),
    Data = <<"release lifecycle">>,
    Data = zlib:uncompress(zlib:compress(Data)),
    Data = iolist_to_binary(zstd:decompress(zstd:compress(Data))),
    {ok, File} = ram_file:open(Data, [read, binary]),
    {ok, Data} = file:read(File, byte_size(Data)),
    ok = file:close(File),
    ok = file:write_file("release-probe.txt", Data),
    {ok, Data} = file:read_file("release-probe.txt"),
    ok = file:delete("release-probe.txt"),
    lists:foreach(fun(Backend) ->
        {ok, Listener} = gen_tcp:listen(0, [{inet_backend, Backend}, binary,
                                          {active, false}, {ip, {127,0,0,1}}]),
        {ok, Port} = inet:port(Listener),
        {ok, Client} = gen_tcp:connect({127,0,0,1}, Port,
                         [{inet_backend, Backend}, binary, {active, false}], 5000),
        {ok, Server} = gen_tcp:accept(Listener, 5000),
        ok = gen_tcp:send(Client, Data),
        {ok, Data} = gen_tcp:recv(Server, byte_size(Data), 5000),
        ok = gen_tcp:close(Client), ok = gen_tcp:close(Server),
        ok = gen_tcp:close(Listener)
    end, [inet, socket]),
    "helper-ok" = os:cmd("printf helper-ok"),
    ok.
