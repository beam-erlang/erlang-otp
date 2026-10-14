%% SPDX-License-Identifier: Apache-2.0
-module(otp_service_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_Type, _Args) -> otp_service_sup:start_link().
stop(_State) -> ok.
