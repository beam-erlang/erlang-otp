%% SPDX-License-Identifier: Apache-2.0
-module(otp_supervision).
-export([main/0]).

main() ->
    try
        ok = otp_fixture:check(),
        ok = application:load(otp_counter),
        {ok, 41} = application:get_env(otp_counter, initial_count),
        lists:foreach(fun cycle/1, [1, 2]),
        io:format("OTP_SUPERVISION_OK~n"),
        init:stop(0)
    catch Class:Reason:Stack ->
        io:format(standard_error, "OTP supervision failed: ~p:~p~n~p~n",
                  [Class, Reason, Stack]),
        erlang:halt(1)
    end.

cycle(Number) ->
    %% Keep configuration in the OTP application environment, not the worker.
    Initial = 40 + Number,
    ok = application:set_env(otp_counter, initial_count, Initial),
    ok = application:set_env(otp_counter, observer, self()),
    try
        {ok, [otp_counter]} = application:ensure_all_started(otp_counter),
        Supervisor = whereis(otp_counter_sup),
        true = is_pid(Supervisor),
        First = ready(Initial),
        First = whereis(otp_counter),
        Initial = gen_server:call(First, value, 5000),
        Incremented = Initial + 1,
        Incremented = gen_server:call(First, increment, 5000),
        FirstMonitor = erlang:monitor(process, First),
        ok = gen_server:cast(First, crash),
        receive
            {'DOWN', FirstMonitor, process, First, deliberate_counter_crash} -> ok
        after 5000 -> erlang:error(counter_crash_timeout)
        end,
        Second = ready(Initial),
        true = Second =/= First,
        Second = whereis(otp_counter),
        Initial = gen_server:call(Second, value, 5000),
        SupMonitor = erlang:monitor(process, Supervisor),
        WorkerMonitor = erlang:monitor(process, Second),
        ok = application:stop(otp_counter),
        down(SupMonitor, Supervisor),
        down(WorkerMonitor, Second),
        undefined = whereis(otp_counter),
        undefined = whereis(otp_counter_sup),
        false = lists:keymember(otp_counter, 1, application:which_applications())
    after
        %% Also stop a partially exercised application when an assertion fails.
        _ = application:stop(otp_counter)
    end.

ready(Initial) ->
    receive
        {counter_ready, Pid, Initial} -> Pid
    after 5000 -> erlang:error(counter_ready_timeout)
    end.

down(Monitor, Pid) ->
    receive
        {'DOWN', Monitor, process, Pid, _Reason} -> ok
    after 5000 -> erlang:error(application_stop_timeout)
    end.
