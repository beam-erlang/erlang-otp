%% SPDX-License-Identifier: Apache-2.0
-module(otp_counter).
-behaviour(gen_server).
-export([start_link/0, init/1, handle_call/3, handle_cast/2]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, Initial} = application:get_env(otp_counter, initial_count),
    {ok, Observer} = application:get_env(otp_counter, observer),
    Observer ! {counter_ready, self(), Initial},
    {ok, Initial}.

handle_call(value, _From, Count) -> {reply, Count, Count};
handle_call(increment, _From, Count) -> {reply, Count + 1, Count + 1}.

handle_cast(crash, _Count) -> exit(deliberate_counter_crash).
