%% SPDX-License-Identifier: Apache-2.0
-module(otp_re_coexist).
-export([load/1, stock/0]).
-nifs([stock/0]).
load(Path) -> erlang:load_nif(Path, []).
stock() -> erlang:nif_error(nif_not_loaded).
