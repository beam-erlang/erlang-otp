%% SPDX-License-Identifier: Apache-2.0
-module(otp_probe_nif).
-export([load/1, echo/1]).
load(Path) -> erlang:load_nif(Path, 0).
echo(_) -> erlang:nif_error(not_loaded).
