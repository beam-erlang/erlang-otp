#!/usr/bin/env escript
%% SPDX-License-Identifier: Apache-2.0
%%! +S1 +A0
-mode(compile).
main(["space arg", [955], "+literal"]) ->
    1 = erlang:system_info(schedulers),
    0 = erlang:system_info(thread_pool_size),
    io:format("escript_passed~n").
