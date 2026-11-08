%% SPDX-License-Identifier: Apache-2.0
%% An incompatible wrapper must fail before publishing a native module owner.
-module(re).
-on_load(init/0).
-export([run/2]).
%% Keep every native entry in bytecode so rejection reaches the load-info check.
-export([compile_nif/2, run_nif/4, inspect_nif/2, import_nif/1, version_nif/0]).
-nifs([compile_nif/2, run_nif/4, inspect_nif/2, import_nif/1, version_nif/0]).
init() ->
    Result = erlang:load_nif("re", incompatible_load_info),
    otp_re_upgrade_observer ! {invalid_re_load, Result},
    Result.
run(A,B) -> run_nif(A,B,[],false).
compile_nif(_,_) -> erlang:nif_error(nif_not_loaded).
run_nif(_,_,_,_) -> erlang:nif_error(nif_not_loaded).
inspect_nif(_,_) -> erlang:nif_error(nif_not_loaded).
import_nif(_) -> erlang:nif_error(nif_not_loaded).
version_nif() -> erlang:nif_error(nif_not_loaded).
