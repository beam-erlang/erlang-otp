%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2024-2025. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%
-module(erts_trace_cleaner).
-moduledoc false.
-export([start/0, check/0, send_trace_clean_signal/1]).

%% Canonical OTP startup identity; the worker implementation belongs to the VM.
start() ->
    beam_internal:trace_cleaner_start().

-spec check() -> boolean().
check() ->
    erlang:nif_error(undef).

-spec send_trace_clean_signal(pid() | port()) -> boolean().
send_trace_clean_signal(_To) ->
    erlang:nif_error(undef).
