%% SPDX-License-Identifier: Apache-2.0
-module(otp_windows_smoke).
-export([run/0]).

run() ->
    try
        ["two words", [], [$"], [16#03bb]] = init:get_plain_arguments(),
        Root = filename:absname(os:getenv("OTP_EXPECT_PREFIX")),
        Root = code:root_dir(),
        22 = length(erlang:pre_loaded()),
        lists:foreach(fun(M) ->
            {module, M} = code:ensure_loaded(M),
            true = lists:prefix(filename:join(Root, "lib") ++ "/", filename:absname(code:which(M)))
        end, [application, supervisor, gen_server, file, gen_tcp, crypto, ssl]),
        Flavor = case os:getenv("OTP_EXPECT_FLAVOR") of "emu" -> emu; "jit" -> jit end,
        Flavor = erlang:system_info(emu_flavor),
        %% ETS refs and flexible-counter snapshots have distinct native types.
        %% PE identical-code folding must preserve their destructor identities.
        Table = ets:new(windows_counts, [ordered_set]),
        0 = ets:info(Table, size),
        true = ets:insert(Table, {key, 42}),
        1 = ets:info(Table, size),
        [{key,42}] = ets:tab2list(Table),
        true = ets:delete(Table),
        %% Hash tries must retain 64-bit hashes on Windows' LLP64 data model.
        Pairs = [{I, {value, I}} || I <- lists:seq(1, 1000)],
        HashMap = maps:from_list(Pairs),
        1000 = map_size(HashMap),
        lists:foreach(fun({K, V}) -> V = map_get(K, HashMap) end, Pairs),
        Payload = <<"Windows OTP", 0, 1, 255>>,
        Path = "payload-" ++ [16#03bb] ++ ".bin",
        ok = file:write_file(Path, Payload),
        {ok, Payload} = file:read_file(Path),
        ok = file:delete(Path),
        Payload = zlib:uncompress(zlib:compress(Payload)),
        {ok, {127,0,0,1}} = inet:getaddr("localhost", inet),
        lists:foreach(fun(B) -> tcp(B, Payload) end, [inet, socket]),
        ok = supervision(),
        {ok, Registry} = win32reg:open([read]),
        ok = win32reg:close(Registry),
        {ok, _} = application:ensure_all_started(crypto),
        [{<<"OpenSSL">>, _, OpenSSLDescription}] = crypto:info_lib(),
        [<<"OpenSSL">>, OpenSSLVersion | _] = binary:split(OpenSSLDescription, <<" ">>, [global]),
        OpenSSLVersion = list_to_binary(os:getenv("OTP_TEST_OPENSSL_VERSION")),
        <<16#ba,16#78,16#16,16#bf,16#8f,16#01,16#cf,16#ea,
          16#41,16#41,16#40,16#de,16#5d,16#ae,16#22,16#23,
          16#b0,16#03,16#61,16#a3,16#96,16#17,16#7a,16#9c,
          16#b4,16#10,16#ff,16#61,16#f2,16#00,16#15,16#ad>> = crypto:hash(sha256, <<"abc">>),
        32 = byte_size(crypto:strong_rand_bytes(32)),
        %% MD4 is supplied by the bundled OpenSSL legacy provider.
        <<16#a4,16#48,16#01,16#7a,16#af,16#21,16#d8,16#52,
          16#5f,16#c1,16#0a,16#e8,16#7a,16#a6,16#72,16#9d>> = crypto:hash(md4, <<"abc">>),
        {ok, _} = application:ensure_all_started(os_mon),
        Memory = memsup:get_system_memory_data(),
        TotalMemory = proplists:get_value(total_memory, Memory),
        true = is_integer(TotalMemory) andalso TotalMemory > 0,
        ok = application:stop(os_mon),
        ok = tls(Payload),
        ok = otp_windows_nif:load(os:getenv("OTP_TEST_NIF")),
        42 = otp_windows_nif:double(21),
        Program = open_port({spawn_executable, os:getenv("OTP_TEST_PYTHON")},
            [binary, exit_status, use_stdio, {args, ["-c", "print('OTP_CHILD_OK')"]}]),
        <<"OTP_CHILD_OK\n">> = binary:replace(collect(Program, <<>>), <<"\r\n">>, <<"\n">>, [global]),
        io:format("WINDOWS_OTP_SMOKE_OK ~p~n", [Flavor]),
        halt(0)
    catch Class:Reason:Stack ->
        io:format(standard_error, "Windows OTP smoke failed: ~tp:~tp~n~tp~n", [Class,Reason,Stack]),
        halt(1)
    end.

tcp(Backend, Payload) ->
    Options = [{inet_backend, Backend}, binary, {active,false}, {packet,4}],
    {ok, Listen} = gen_tcp:listen(0, [{inet_backend,Backend},{ip,{127,0,0,1}},
                                    binary,{active,false},{packet,4}]),
    {ok, {_, Port}} = inet:sockname(Listen),
    Parent = self(),
    {Client, Monitor} = spawn_monitor(fun() ->
        {ok, Socket} = gen_tcp:connect({127,0,0,1}, Port, Options, 5000),
        ok = gen_tcp:send(Socket, Payload),
        {ok, Payload} = gen_tcp:recv(Socket, 0, 5000),
        ok = gen_tcp:close(Socket), Parent ! {done,self()}
    end),
    {ok, Peer} = gen_tcp:accept(Listen, 5000),
    {ok, Payload} = gen_tcp:recv(Peer, 0, 5000),
    ok = gen_tcp:send(Peer, Payload),
    ok = gen_tcp:close(Peer), ok = gen_tcp:close(Listen),
    completed(Client, Monitor).

supervision() ->
    ok = application:load(otp_counter),
    ok = application:set_env(otp_counter, observer, self()),
    {ok, [otp_counter]} = application:ensure_all_started(otp_counter),
    First = ready(), 41 = gen_server:call(First, value),
    42 = gen_server:call(First, increment),
    Monitor = monitor(process, First),
    ok = gen_server:cast(First, crash),
    receive {'DOWN',Monitor,process,First,deliberate_counter_crash} -> ok
    after 5000 -> error(counter_stop_timeout) end,
    Second = ready(), true = Second =/= First,
    41 = gen_server:call(Second, value),
    ok = application:stop(otp_counter),
    undefined = whereis(otp_counter), ok.

ready() -> receive {counter_ready, Pid, 41} -> Pid
           after 5000 -> error(counter_start_timeout) end.

tls(Payload) ->
    {ok, _} = application:ensure_all_started(ssl),
    Cert = os:getenv("OTP_TEST_CERT"), Key = os:getenv("OTP_TEST_KEY"),
    CA = os:getenv("OTP_TEST_CA"),
    {ok, Listen} = ssl:listen(0, [binary,{active,false},{ip,{127,0,0,1}},
                                 {certfile,Cert},{keyfile,Key}]),
    {ok, {_, Port}} = ssl:sockname(Listen), Parent = self(),
    {Client, Monitor} = spawn_monitor(fun() ->
        {ok, Socket} = ssl:connect("localhost", Port,
            [binary,{active,false},{verify,verify_peer},{cacertfile,CA},
             {server_name_indication,"localhost"}], 10000),
        ok = ssl:send(Socket, Payload),
        {ok, Payload} = ssl:recv(Socket, byte_size(Payload), 10000),
        ok = ssl:close(Socket), Parent ! {done,self()}
    end),
    {ok, Transport} = ssl:transport_accept(Listen, 10000),
    {ok, Peer} = ssl:handshake(Transport, 10000),
    {ok, Payload} = ssl:recv(Peer, byte_size(Payload), 10000),
    ok = ssl:send(Peer, Payload),
    ok = ssl:close(Peer), ok = ssl:close(Listen),
    completed(Client, Monitor).

completed(Client, Monitor) ->
    receive {done,Client} -> ok; {'DOWN',Monitor,process,Client,Why} -> error({client_failed,Why})
    after 10000 -> error(client_timeout) end,
    receive {'DOWN',Monitor,process,Client,normal} -> ok
    after 5000 -> error(client_shutdown_timeout) end.

collect(Port, Bytes) ->
    receive {Port,{data,Data}} -> collect(Port, <<Bytes/binary,Data/binary>>);
            {Port,{exit_status,0}} -> Bytes
    after 5000 -> error(child_timeout) end.
