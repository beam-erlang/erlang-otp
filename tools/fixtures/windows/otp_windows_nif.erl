%% SPDX-License-Identifier: Apache-2.0
-module(otp_windows_nif).
-export([load/1,double/1]).
load(Path) -> erlang:load_nif(Path, 0).
double(_) -> erlang:nif_error(not_loaded).
