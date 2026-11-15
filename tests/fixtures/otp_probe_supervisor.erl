%% SPDX-License-Identifier: Apache-2.0
-module(otp_probe_supervisor).
-behaviour(supervisor).
-export([start_link/0, init/1, start_worker/0]).

start_link() -> supervisor:start_link(?MODULE,[]).
init([]) ->
    {ok,{{one_for_one,3,5},
         [{worker,{?MODULE,start_worker,[]},permanent,1000,worker,[?MODULE]}]}}.
start_worker() -> {ok,spawn_link(fun loop/0)}.
loop() ->
    receive {ping,From} -> From ! {pong,self()}, loop() end.
