%% SPDX-License-Identifier: Apache-2.0
-module(otp_terminal_regex).
-export([run/0, reference/0]).

run() -> check(true).

%% The pinned original supplies the rendering comparison, without imposing the
%% ordinary-provider initialization policy on its built-in implementation.
reference() -> check(false).

check(Trace) ->
    {module, re} = code:ensure_loaded(re),
    ok = prim_tty:load(),
    case Trace of
        true -> erlang:trace_pattern({re, compile, 2}, true, [local]);
        false -> ok
    end,
    try
        scenario(native_cooked, Trace),
        scenario(native_raw, Trace),
        scenario(ssh, Trace),
        io:put_chars("OTP_TERMINAL_REGEX_OK\n")
    after
        case Trace of
            true -> erlang:trace_pattern({re, compile, 2}, false, [local]);
            false -> ok
        end
    end.

scenario(Kind, Trace) ->
    Parent = self(),
    {Pid, Mon} = spawn_monitor(fun() -> worker(Parent) end),
    receive {ready, Pid} -> ok after 5000 -> error(worker_start_timeout) end,
    case Trace of
        true -> 1 = erlang:trace(Pid, true, [call, {tracer, self()}]);
        false -> ok
    end,
    try
        Initialize = fun(_) ->
            case Kind of
                ssh -> prim_tty:init_ssh(#{input => raw, output => cooked},
                                         {80, 24}, unicode);
                native_cooked -> prim_tty:unicode(prim_tty:init(options(cooked)), true);
                native_raw -> prim_tty:unicode(prim_tty:init(options(raw)), true)
            end
        end,
        step(Pid, Mon, init, Initialize, 0, Trace),
        case Kind of
            native_raw ->
                request(Pid, Mon, {putc, <<"raw">>}, <<"raw">>, 0, Trace),
                request(Pid, Mon, beep, <<7>>, 0, Trace),
                reinit(Pid, Mon, cooked, Trace);
            native_cooked ->
                step(Pid, Mon, direct_write, fun(S) ->
                    #{write := WriterRef} = prim_tty:handles(S),
                    {ok, Ref} = prim_tty:write(S, <<"OTP_TERMINAL_DIRECT\n">>, self()),
                    receive {WriterRef, ok} -> ok
                    after 5000 -> error(writer_timeout) end,
                    true = demonitor(Ref, [flush]),
                    S
                end, 0, Trace);
            ssh -> ok
        end,
        %% putc discards insert_buf's returned state; its cache must survive.
        request(Pid, Mon, {putc, <<"A">>}, <<"A">>, 1, Trace),
        ANSI = <<"\e[31m", 195, 169, "\e[0m\e[2K\e[2C">>,
        request(Pid, Mon, {insert, ANSI}, ANSI, 0, Trace),
        request(Pid, Mon, {insert, <<"B">>}, <<"B">>, 0, Trace),
        case Kind of
            ssh -> ok;
            _ ->
                reinit(Pid, Mon, raw, Trace),
                request(Pid, Mon, {putc, <<"raw-again">>}, <<"raw-again">>, 0, Trace),
                reinit(Pid, Mon, cooked, Trace),
                request(Pid, Mon, {insert, <<"C">>}, <<"C">>, 0, Trace)
        end
    after
        case is_process_alive(Pid) of
            true ->
                Pid ! stop,
                receive {'DOWN', Mon, process, Pid, normal} -> ok
                after 5000 -> exit(Pid, kill), error(worker_stop_timeout) end;
            false -> demonitor(Mon, [flush])
        end
    end.

options(Output) -> #{input => disabled, output => Output, ofd => stderr}.

reinit(Pid, Mon, Output, Trace) ->
    step(Pid, Mon, {reinit, Output},
         fun(S) -> prim_tty:reinit(S, options(Output)) end, 0, Trace).

request(Pid, Mon, Request, Expected, Count, Trace) ->
    step(Pid, Mon, Request, fun(S) ->
        {Bytes, Next} = prim_tty:handle_request(S, Request),
        Expected = iolist_to_binary(Bytes),
        Next
    end, Count, Trace).

step(Pid, Mon, Label, Function, Expected, Trace) ->
    Ref = make_ref(),
    Pid ! {step, Ref, Function},
    receive
        {done, Pid, Ref} -> ok;
        {'DOWN', Mon, process, Pid, Reason} -> error({worker_failed, Label, Reason})
    after 5000 -> error({step_timeout, Label})
    end,
    case Trace of
        true ->
            Barrier = erlang:trace_delivered(Pid),
            case calls(Pid, Barrier, 0) of
                Expected -> ok;
                Actual -> error({compile_count, Label, Expected, Actual})
            end;
        false -> ok
    end.

calls(Pid, Ref, Count) ->
    receive
        {trace, Pid, call, {re, compile, [_Pattern, [unicode]]}} ->
            calls(Pid, Ref, Count + 1);
        {trace_delivered, Pid, Ref} -> Count
    after 5000 -> error(trace_delivery_timeout)
    end.

worker(Parent) ->
    process_flag(trap_exit, true),
    true = register(otp_terminal_regex_worker, self()),
    Parent ! {ready, self()},
    try worker_loop(Parent, undefined)
    after
        case whereis(otp_terminal_regex_worker_writer) of
            undefined -> ok;
            Writer ->
                Ref = monitor(process, Writer),
                exit(Writer, shutdown),
                receive {'DOWN', Ref, process, Writer, _} -> ok
                after 5000 -> error(writer_stop_timeout) end
        end
    end.

worker_loop(Parent, State) ->
    receive
        {step, Ref, Function} ->
            Next = Function(State),
            Parent ! {done, self(), Ref},
            worker_loop(Parent, Next);
        stop -> ok
    end.
