%% SPDX-License-Identifier: Apache-2.0
-module(otp_distribution_SUITE).
-include_lib("common_test/include/ct.hrl").
-export([all/0, suite/0, file_and_compression/1, tcp/1, native/1, supervision/1]).

suite() -> [{timetrap,{seconds,30}}].
all() -> [file_and_compression,tcp,native,supervision].

file_and_compression(Config) ->
    Path = filename:join(?config(priv_dir,Config), "roundtrip.bin"),
    Bytes = unicode:characters_to_binary([16#03bb,16#1f642]),
    ok = file:write_file(Path,Bytes),
    {ok,Bytes} = file:read_file(Path),
    Bytes = zlib:uncompress(zlib:compress(Bytes)),
    <<_:256>> = crypto:hash(sha256,Bytes),
    ok = file:delete(Path).

tcp(_Config) ->
    {ok,Listen} = gen_tcp:listen(0,[binary,{active,false},{ip,{127,0,0,1}}]),
    {ok,{_,Port}} = inet:sockname(Listen),
    Parent = self(),
    {Pid,Monitor} = spawn_monitor(fun() ->
        {ok,Server} = gen_tcp:accept(Listen,5000),
        {ok,<<"ping">>} = gen_tcp:recv(Server,4,5000),
        ok = gen_tcp:send(Server,<<"pong">>),
        ok = gen_tcp:close(Server),
        Parent ! server_complete
    end),
    try
        {ok,Client} = gen_tcp:connect({127,0,0,1},Port,[binary,{active,false}],5000),
        try
            ok = gen_tcp:send(Client,<<"ping">>),
            {ok,<<"pong">>} = gen_tcp:recv(Client,4,5000)
        after gen_tcp:close(Client) end,
        receive server_complete -> ok after 5000 -> ct:fail(server_timeout) end,
        receive {'DOWN',Monitor,process,Pid,normal} -> ok
        after 5000 -> ct:fail(server_not_stopped) end
    after
        gen_tcp:close(Listen),
        exit(Pid,kill)
    end,
    {ok,{hostent,_,_,inet,4,Addresses}} = inet_gethost_native:gethostbyname("localhost"),
    true = lists:member({127,0,0,1},Addresses),
    Child = open_port({spawn_executable,"/bin/sh"},[{args,["-c","exit 23"]},exit_status]),
    try
        receive {Child,{exit_status,23}} -> ok
        after 5000 -> ct:fail(child_status_timeout) end
    after catch port_close(Child) end.

native(Config) ->
    Native = os:getenv("OTP_TEST_NATIVE"),
    ok = otp_probe_nif:load(filename:join(Native,"otp_probe_nif")),
    Term = {copied,[42,<<"native">>]},
    Term = otp_probe_nif:echo(Term),
    ok = erl_ddll:load_driver(Native,"otp_probe_drv"),
    Port = open_port({spawn_driver,"otp_probe_drv"},[binary]),
    try
        true = port_command(Port,<<"driver-echo">>),
        receive {Port,{data,<<"driver-echo">>}} -> ok
        after 5000 -> ct:fail(driver_timeout) end
    after port_close(Port) end,
    ok = erl_ddll:unload_driver("otp_probe_drv"),
    TracePath = filename:join(?config(priv_dir,Config),"runtime_tools.trace"),
    OpenTrace = dbg:trace_port(file,TracePath),
    TracePort = OpenTrace(),
    TraceBytes = term_to_binary({otp_trace,42}),
    try
        true = port_command(TracePort,TraceBytes),
        [0] = port_control(TracePort,$f,[])
    after port_close(TracePort) end,
    Size = byte_size(TraceBytes),
    {ok,<<0,Size:32,TraceBytes:Size/binary>>} = file:read_file(TracePath),
    ok = erl_ddll:unload_driver("trace_file_drv").

supervision(_Config) ->
    {ok,Supervisor} = otp_probe_supervisor:start_link(),
    unlink(Supervisor),
    try
        [{worker,First,worker,_}] = supervisor:which_children(Supervisor),
        Monitor = monitor(process,First),
        exit(First,kill),
        receive {'DOWN',Monitor,process,First,killed} -> ok
        after 5000 -> ct:fail(worker_not_stopped) end,
        replacement(Supervisor,First,erlang:monotonic_time(millisecond)+5000)
    after
        Stop = monitor(process,Supervisor),
        exit(Supervisor,shutdown),
        receive {'DOWN',Stop,process,Supervisor,shutdown} -> ok
        after 5000 -> ct:fail(supervisor_not_stopped) end
    end.

replacement(Supervisor,First,Deadline) ->
    case supervisor:which_children(Supervisor) of
        [{worker,Second,worker,_}] when is_pid(Second), Second =/= First ->
            Second ! {ping,self()},
            receive {pong,Second} -> ok after 5000 -> ct:fail(worker_not_ready) end;
        _ ->
            case erlang:monotonic_time(millisecond) < Deadline of
                true -> receive after 10 -> replacement(Supervisor,First,Deadline) end;
                false -> ct:fail(worker_not_replaced)
            end
    end.
