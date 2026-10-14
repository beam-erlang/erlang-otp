%% SPDX-License-Identifier: Apache-2.0
-module(otp_counter_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Child = #{id => otp_counter, start => {otp_counter, start_link, []},
              restart => permanent, shutdown => 5000, type => worker},
    {ok, {#{strategy => one_for_one, intensity => 3, period => 5}, [Child]}}.
