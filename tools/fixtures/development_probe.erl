%% SPDX-License-Identifier: Apache-2.0
-module(development_probe).
-export([load/1, check/0]).
-nifs([check/0]).
load(Path) -> erlang:load_nif(Path, 0).
check() -> erlang:nif_error(not_loaded).
