%% SPDX-License-Identifier: Apache-2.0
-module(otp_re_test).
-export([load/1,stats/0,clocks/0,limit/1,coverage/0,compile_hold/1,fail_upgrade/1,
         set_internal_state/2,get_internal_state/1]).
-nifs([stats/0,clocks/0,limit/1,coverage/0,compile_hold/1,fail_upgrade/1]).
load(Path)->
    %% Controls need the ordinary provider's state before setting loop budgets.
    {module,re}=code:ensure_loaded(re),
    erlang:load_nif(Path,otp_re_test).
set_internal_state(re_loop_limit,Value)->limit(Value).
get_internal_state(re_yield_coverage)->coverage().
stats()->erlang:nif_error(nif_not_loaded).
clocks()->erlang:nif_error(nif_not_loaded).
limit(_)->erlang:nif_error(nif_not_loaded).
coverage()->erlang:nif_error(nif_not_loaded).
compile_hold(_)->erlang:nif_error(nif_not_loaded).
fail_upgrade(_)->erlang:nif_error(nif_not_loaded).
