%% SPDX-License-Identifier: Apache-2.0
-module(otp_compiler_probe).
-export([run/0]).

run() ->
    Values = [N * 2 || N <- lists:seq(1, 6)],
    #{total := Result} = #{total => lists:sum(Values)},
    Result.
