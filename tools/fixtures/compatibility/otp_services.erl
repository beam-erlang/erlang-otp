%% SPDX-License-Identifier: Apache-2.0
-module(otp_services).
-export([main/0]).

main() ->
    try
        ok = otp_fixture:check(),
        Backend = case init:get_plain_arguments() of
                      ["inet"] -> inet;
                      ["socket"] -> socket
                  end,
        ok = application:load(otp_service),
        ok = application:set_env(otp_service, backend, Backend),
        lists:foreach(fun(N) -> cycle(Backend, N) end, [1, 2]),
        io:format("OTP_SERVICES_OK ~p~n", [Backend]),
        init:stop(0)
    catch Class:Reason:Stack ->
        io:format(standard_error, "OTP services failed: ~p:~p~n~p~n",
                  [Class, Reason, Stack]),
        erlang:halt(1)
    end.

cycle(Backend, Number) ->
    Directory = "otp-service-" ++ atom_to_list(Backend) ++ "-" ++
                integer_to_list(erlang:unique_integer([positive])),
    ok = file:make_dir(Directory),
    Path = filename:join(Directory, "payload.bin"),
    try
        {ok, [otp_service]} = application:ensure_all_started(otp_service),
        Supervisor = whereis(otp_service_sup),
        Server = whereis(otp_service),
        true = is_pid(Supervisor),
        true = is_pid(Server),
        %% The synchronous call acknowledges that the listener is ready.
        Port = gen_server:call(Server, port, 5000),
        true = Port > 0,
        Payload = term_to_binary({compatibility, Backend, Number,
                                  binary:copy(<<"BEAM OTP services\n">>, 1024)}),
        Owner = self(),
        {Client, Monitor} = spawn_monitor(fun() ->
            client(Owner, Backend, Port, Payload)
        end),
        try
            {ok, Size} = gen_server:call(Server, {exchange, Path}, 5000),
            Size = byte_size(Payload),
            receive
                {client_done, Client, Payload} -> ok;
                {'DOWN', Monitor, process, Client, Reason} ->
                    erlang:error({client_failed, Reason})
            after 5000 -> erlang:error(client_reply_timeout)
            end,
            receive
                {'DOWN', Monitor, process, Client, normal} -> ok
            after 5000 -> erlang:error(client_stop_timeout)
            end
        after
            %% A failed server assertion must not leave a blocked client alive.
            exit(Client, kill),
            erlang:demonitor(Monitor, [flush])
        end,
        {ok, Payload} = file:read_file(Path),
        SupMonitor = erlang:monitor(process, Supervisor),
        ServerMonitor = erlang:monitor(process, Server),
        ok = application:stop(otp_service),
        down(SupMonitor, Supervisor),
        down(ServerMonitor, Server),
        undefined = whereis(otp_service),
        undefined = whereis(otp_service_sup),
        false = lists:keymember(otp_service, 1, application:which_applications()),
        ok = file:delete(Path)
    after
        _ = application:stop(otp_service),
        _ = file:delete(Path),
        ok = file:del_dir(Directory)
    end.

client(Owner, Backend, Port, Payload) ->
    {ok, Socket} = gen_tcp:connect({127, 0, 0, 1}, Port,
                                  [{inet_backend, Backend}, binary,
                                   {active, false}, {packet, 4},
                                   {send_timeout, 5000},
                                   {send_timeout_close, true}], 5000),
    try
        ok = gen_tcp:send(Socket, otp_service:compress(Payload)),
        {ok, Reply} = gen_tcp:recv(Socket, 0, 5000),
        Payload = otp_service:decompress(Reply),
        Owner ! {client_done, self(), Payload}
    after
        ok = gen_tcp:close(Socket)
    end.

down(Monitor, Pid) ->
    receive
        {'DOWN', Monitor, process, Pid, _Reason} -> ok
    after 5000 -> erlang:error(application_stop_timeout)
    end.
