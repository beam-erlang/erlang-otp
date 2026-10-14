%% SPDX-License-Identifier: Apache-2.0
-module(otp_hello).
-export([main/0]).

main() ->
    try
        ok = otp_fixture:check(),
        io:format("OTP_HELLO_OK~n"),
        init:stop(0)
    catch Class:Reason:Stack ->
        io:format(standard_error, "OTP hello failed: ~p:~p~n~p~n", [Class, Reason, Stack]),
        erlang:halt(1)
    end.
