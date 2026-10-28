%% SPDX-License-Identifier: Apache-2.0
-module(otp_product_probe).
-export([run/3, event_collection/1]).
-include_lib("diameter/include/diameter.hrl").
-include_lib("et/include/et.hrl").
-include_lib("snmp/include/snmp_types.hrl").
-include_lib("megaco/include/megaco_message_v1.hrl").

run(Prefix, Flavor, Work) ->
    Counter = filename:join(Work, "restarts"),
    Count = case file:read_file(Counter) of {error, enoent} -> 0; {ok, B} -> binary_to_integer(B) end,
    TaintFile = filename:join(Work, "taints.term"),
    ExpectedTaints = case Count of
        0 -> [];
        _ -> {ok, [PreviousTaints]} = file:consult(TaintFile), PreviousTaints
    end,
    Prefix = code:root_dir(),
    Lib = filename:join(Prefix, "lib"),
    Lib = code:lib_dir(),
    Flavor = erlang:system_info(emu_flavor),
    [kernel, stdlib] = lists:sort([Application || {Application, _, _} <- application:which_applications()]),
    22 = length(erlang:pre_loaded()),
    ErtsDirectory = filename:join(Lib, "erts-" ++ erlang:system_info(version)),
    ErtsDirectory = code:lib_dir(erts),
    %% Installed application modules preserve ordinary compiler metadata even
    %% when their original source/build locations are unavailable.
    ApplicationBeams = [File || File <- filelib:wildcard(filename:join([Lib, "*", "ebin", "*.beam"])),
                               filename:dirname(filename:dirname(File)) =/= ErtsDirectory],
    true = ApplicationBeams =/= [],
    lists:foreach(fun(File) ->
        {ok, {_, [{compile_info, Information}]}} = beam_lib:chunks(File, [compile_info]),
        {options, Options} = lists:keyfind(options, 1, Information),
        true = is_list(Options),
        {source, Source} = lists:keyfind(source, 1, Information),
        true = is_list(Source) andalso Source =/= []
    end, ApplicationBeams),
    {ok, [{application, erts, ErtsProperties}]} =
        file:consult(filename:join([ErtsDirectory, "ebin", "erts.app"])),
    ErtsVersion = erlang:system_info(version),
    ErtsVersion = proplists:get_value(vsn, ErtsProperties),
    lists:foreach(fun(Module) ->
        Beam = filename:join([ErtsDirectory, "ebin", atom_to_list(Module) ++ ".beam"]),
        {ok, {Module, _Digest}} = beam_lib:md5(Beam),
        {ok, {Module, [{abstract_code, {raw_abstract_v1, Forms}}]}} =
            beam_lib:chunks(Beam, [abstract_code]),
        {attribute, _, module, Module} = lists:keyfind(module, 3, Forms),
        true = code:is_sticky(Module)
    end, erlang:pre_loaded()),
    lists:foreach(fun(File) ->
        %% make_preload retains these chunks, following the upstream generator.
        %% Tooling gets the original file, including documentation/debug metadata.
        {ok, Module, Chunks} = beam_lib:all_chunks(File),
        {ok, {Module, [{abstract_code, {raw_abstract_v1, Forms}},
                       {attributes, Attributes}, {compile_info, CompileInfo}]}} =
            beam_lib:chunks(File, [abstract_code, attributes, compile_info]),
        true = is_list(Forms) andalso Forms =/= [],
        true = is_list(Attributes),
        true = is_list(CompileInfo),
        Embedded = [Chunk || {Name, _} = Chunk <- Chunks,
                    lists:member(Name, ["Code", "AtU8", "ImpT", "ExpT", "StrT",
                                        "FunT", "LitT", "Type"])],
        {ok, Binary} = beam_lib:build_module(Embedded),
        {ok, {Module, Digest}} = beam_lib:md5(Binary),
        preloaded = code:which(Module),
        Digest = Module:module_info(md5)
    end, [filename:join([ErtsDirectory, "ebin", atom_to_list(M) ++ ".beam"]) || M <- erlang:pre_loaded()]),
    {file, preloaded} = code:is_loaded(init),
    true = code:is_sticky(prim_eval),
    lists:foreach(fun(Module) ->
        true = lists:prefix(filename:split(Lib), filename:split(code:which(Module)))
    end, [application, gen_server, compile]),
    {ok, LoadedDrivers} = erl_ddll:loaded_drivers(),
    lists:foreach(fun(Name) ->
        true = lists:member(Name, LoadedDrivers),
        true = erl_ddll:info(Name, linked_in_driver),
        false = erl_ddll:info(Name, permanent),
        linked_in_driver = erl_ddll:info(Name, processes)
    end, ["tcp_inet", "udp_inet", "ram_file_drv"]),
    %% Retained SDK coexistence check now uses OTP's ordinary re wrapper.
    {match,[{0,8},{0,5},{6,2}]} = re:run("hello 42", "^(hello) ([0-9]+)$"),
    nomatch = re:run("goodbye", "^(hello) ([0-9]+)$"),
    Data = <<"source-built OTP on libbeam">>,
    Data = zlib:uncompress(zlib:compress(Data)),
    Data = iolist_to_binary(zstd:decompress(zstd:compress(Data))),
    ok = prim_tty:load(),
    {ok, Ram} = ram_file:open(Data, [read,write,binary]),
    {ok, Data} = file:read(Ram, byte_size(Data)),
    ok = file:close(Ram),
    %% Upstream retains dynamically loaded native taints across init:restart().
    %% Built-in initialization adds none; later boots retain the previous list.
    ExpectedTaints = erlang:system_info(taints),
    Filename = filename:join(Work, "native-file"),
    ok = file:write_file(Filename, Data),
    {ok, Data} = file:read_file(Filename),
    "otp-child" = os:cmd("printf otp-child"),
    {ok, {127,0,0,1}} = inet:getaddr("localhost", inet),
    lists:foreach(fun(Backend) ->
        {ok, Socket} = gen_tcp:listen(0, [{inet_backend, Backend}, {ip, {127,0,0,1}}]),
        {ok, {{127,0,0,1}, Port}} = inet:sockname(Socket),
        true = Port > 0,
        ok = gen_tcp:close(Socket)
    end, [inet, socket]),
    {ok, [crypto]} = application:ensure_all_started(crypto),
    true = lists:prefix(filename:split(Lib), filename:split(code:which(crypto))),
    <<16#ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad:256>> = crypto:hash(sha256, <<"abc">>),
    Key = <<0:128>>, Block = <<0:128>>,
    Cipher = <<16#66e94bd4ef8a2c3b884cfa59ca342b2e:128>>,
    Cipher = crypto:crypto_one_time(aes_128_ecb, Key, Block, true),
    Block = crypto:crypto_one_time(aes_128_ecb, Key, Cipher, false),
    32 = byte_size(crypto:strong_rand_bytes(32)),
    true = crypto:hash_equals(<<1,2,3>>, <<1,2,3>>),
    false = crypto:hash_equals(<<1,2,3>>, <<1,2,4>>),
    [_ | _] = crypto:info_lib(),
    {ok, CryptoVersion} = application:get_key(crypto, vsn),
    CryptoVersion = crypto:version(),
    {ok, [asn1, public_key]} = application:ensure_all_started(public_key),
    true = lists:prefix(filename:split(Lib), filename:split(code:which(public_key))),
    PrivateKey = public_key:generate_key({rsa, 2048, 65537}),
    PublicKey = {'RSAPublicKey', element(3, PrivateKey), element(4, PrivateKey)},
    Signature = public_key:sign(Data, sha256, PrivateKey),
    true = public_key:verify(Data, sha256, Signature, PublicKey),
    false = public_key:verify(<<"different">>, sha256, Signature, PublicKey),
    Der = public_key:der_encode('RSAPublicKey', PublicKey),
    PublicKey = public_key:der_decode('RSAPublicKey', Der),
    PemEntry = public_key:pem_entry_encode('RSAPrivateKey', PrivateKey),
    [PemEntry] = public_key:pem_decode(public_key:pem_encode([PemEntry])),
    PrivateKey = public_key:pem_entry_decode(PemEntry),
    {ok, [ssl]} = application:ensure_all_started(ssl),
    true = lists:prefix(filename:split(Lib), filename:split(code:which(ssl))),
    %% Ephemeral test chains only: credentials are never installed or reused.
    KeyOptions = [{key, PrivateKey}, {digest, sha256}],
    Chain = #{root => KeyOptions, peer => KeyOptions},
    Configs = public_key:pkix_test_data(#{server_chain => Chain, client_chain => Chain}),
    [tls_roundtrip(Version, Backend, Configs, Data) ||
        Version <- ['tlsv1.2', 'tlsv1.3'], Backend <- [inet, socket]],
    ok = application:stop(ssl),
    ok = application:stop(public_key),
    ok = application:stop(asn1),
    ok = application:stop(crypto),
    "5.5" = asn1ct:vsn(),
    true = lists:prefix(filename:split(Lib), filename:split(code:which(asn1ct))),
    lists:foreach(fun(Rule) ->
        Out = filename:join(Work, atom_to_list(Rule)),
        ok = filelib:ensure_dir(filename:join(Out, "generated")),
        ok = asn1ct:compile(filename:join(Work, "P-Record.asn"), [Rule, {outdir, Out}]),
        %% asn1ct:compile already loads the generated module. Loading it again
        %% would leave an old version and make code:delete correctly refuse.
        GeneratedBeam = filename:join(Out, "P-Record.beam"),
        GeneratedBeam = code:which('P-Record'),
        %% Supply the record in schema order. The example's generated v/0
        %% uses canonical SET order for PER; that separate value-generation
        %% discrepancy is documented in docs/application-build.md.
        Value = {'PersonnelRecord', {'Name', "John", "P", "Smith"},
                 "Director", 51, "19710917", {'Name', "Mary", "T", "Smith"},
                 [{'ChildInformation', {'Name', "Ralph", "T", "Smith"}, "19571111"},
                  {'ChildInformation', {'Name', "Susan", "B", "Jones"}, "19590717"}]},
        {ok, Encoded} = 'P-Record':encode('PersonnelRecord', Value),
        {ok, Value} = 'P-Record':decode('PersonnelRecord', Encoded),
        true = code:delete('P-Record'),
        _ = code:purge('P-Record')
    end, [ber, per, uper]),
    tracing_roundtrip(Work),
    xml_and_unit_tests(Work),
    transfer_roundtrip(Work, Data),
    ssh_roundtrip(Work, PrivateKey, Data),
    documentation_roundtrip(Work),
    diameter_roundtrip(Work),
    os_monitoring(),
    dialyzer_roundtrip(Work),
    megaco_roundtrip(),
    debugger_roundtrip(Work),
    event_collection(filename:join(Work, "events-" ++ integer_to_list(Count))),
    {ok, [odbc]} = application:ensure_all_started(odbc),
    {error, {"IM002", 0, OdbcError}} = odbc:connect("DSN=otp_missing_product_probe_dsn", [{extended_errors, on}]),
    true = is_list(OdbcError),
    ok = application:stop(odbc),
    undefined = whereis(odbc_sup),
    [snmp_roundtrip(Work, Backend) || Backend <- [inet, socket]],
    JInterface = code:lib_dir(jinterface),
    true = lists:prefix(filename:split(Lib), filename:split(JInterface)),
    {ok, [{application, jinterface, JavaProperties}]} =
        file:consult(filename:join([JInterface, "ebin", "jinterface.app"])),
    "1.16" = proplists:get_value(vsn, JavaProperties),
    [] = proplists:get_value(modules, JavaProperties),
    {ok, JavaClasses} = zip:extract(filename:join([JInterface, "priv", "OtpErlang.jar"]), [memory]),
    [begin
         {_, <<16#CAFEBABE:32, _/binary>>} = lists:keyfind(
             "com/ericsson/otp/erlang/" ++ Name ++ ".class", 1, JavaClasses)
     end || Name <- ["OtpNode", "OtpMbox", "OtpInputStream", "OtpOutputStream"]],
    {ok, [asn1, eldap]} = application:ensure_all_started(eldap),
    LDAPValue = {'AddRequest', "dc=otp,dc=example", []},
    {ok, LDAPBytes} = 'ELDAPv3':encode('AddRequest', LDAPValue),
    {ok, LDAPValue} = 'ELDAPv3':decode('AddRequest', LDAPBytes),
    true = is_list(element(2, LDAPValue)),
    ok = application:stop(eldap),
    ok = application:stop(asn1),
    database_roundtrip(Work),
    http_roundtrip(Work, Data),
    {Host, Maps} = host_images(),
    Asn1Nif = filename:join([code:priv_dir(asn1), "lib", "asn1rt_nif.so"]),
    true = binary:match(Maps, list_to_binary(Asn1Nif)) =/= nomatch,
    CryptoNif = filename:join([code:priv_dir(crypto), "lib", "crypto.so"]),
    true = binary:match(Maps, list_to_binary(CryptoNif)) =/= nomatch,
    Host = filename:join([Prefix, "erts-" ++ erlang:system_info(version), "bin", "beam.smp"]),
    true = binary:match(Maps, unicode:characters_to_binary(Host)) =/= nomatch,
    nomatch = binary:match(Maps, <<"libbeam.so">>),
    ok = file:write_file(filename:join(Work, "maps"), Maps),
    %% The boot eval runs again on restart; disk state only counts executions.
    %% Linked native implementations must retain upstream restart behavior.
    case Count of
        2 -> io:format("OTP product passed: ~p, three boots~n", [Flavor]), halt(0);
        _ ->
            ok = file:write_file(TaintFile, io_lib:format("~tp.~n", [erlang:system_info(taints)])),
            ok = file:write_file(Counter, integer_to_binary(Count + 1)),
            init:restart(),
            receive after infinity -> ok end
    end.

event_collection(Work) ->
    ok = file:make_dir(Work),
    Baseline = lists:sort(disk_log:all()),
    %% The public event-file client opens a disk_log reader owned by its caller.
    %% Keep the collector linked so timeout termination also stops the collector.
    {Pid, Ref} = spawn_monitor(fun() ->
        process_flag(trap_exit, true),
        {ok, Collector} = et_collector:start_link([{trace_global, false}]),
        CollectorRef = monitor(process, Collector),
        try
            {ok, Handle} = et_collector:report_event(Collector, 10, producer, consumer,
                                                   request, #{value => 42}),
            {ok, _} = et_collector:report_event(Handle, 20, consumer, producer,
                                              reply, #{value => 43}),
            {ok, 2} = et_collector:get_table_size(Collector),
            Collect = fun(Event, Acc) -> [Event | Acc] end,
            Events = et_collector:iterate(Collector, first, infinity, Collect, []),
            [{reply, #{value := 43}}, {request, #{value := 42}}] =
                [{E#event.label, E#event.contents} || E <- Events],
            Log = filename:join(Work, "events.log"),
            ok = et_collector:save_event_file(Collector, Log, [existing, append, keep]),
            {ok, PreviousBytes} = file:read_file(Log),
            true = byte_size(PreviousBytes) > 0,
            {ok, 2} = et_collector:get_table_size(Collector),
            Events = et_collector:iterate(Collector, first, infinity, Collect, []),
            ok = et_collector:save_event_file(Collector, Log, [existing, write, clear]),
            {ok, 0} = et_collector:get_table_size(Collector),
            {ok, PreviousBytes} = file:read_file(Log ++ ".OLD"),
            {ok, 0} = et_collector:start_trace_client(Collector, event_file, Log),
            {ok, 2} = et_collector:get_table_size(Collector),
            Events = et_collector:iterate(Collector, first, infinity, Collect, []),
            false = lists:keymember(wx, 1, application:which_applications()),
            ok = et_collector:stop(Collector),
            receive
                {'DOWN', CollectorRef, process, Collector, shutdown} -> ok;
                {'DOWN', CollectorRef, process, Collector, Reason} ->
                    error({collector_exit, Reason})
            after 3000 -> error(collector_shutdown_timeout)
            end
        catch Class:Failure:Stack ->
            exit(Collector, kill),
            receive {'DOWN', CollectorRef, process, Collector, _} -> ok
            after 1000 -> ok
            end,
            erlang:raise(Class, Failure, Stack)
        end
    end),
    receive
        {'DOWN', Ref, process, Pid, normal} -> ok;
        {'DOWN', Ref, process, Pid, Reason} -> error({event_collection_exit, Reason})
    after 10000 ->
        exit(Pid, kill),
        receive {'DOWN', Ref, process, Pid, _} -> ok after 1000 -> ok end,
        error(event_collection_timeout)
    end,
    await_event_logs(Baseline, erlang:monotonic_time(millisecond) + 3000),
    false = lists:keymember(wx, 1, application:which_applications()),
    ok.

await_event_logs(Baseline, Deadline) ->
    case lists:sort(disk_log:all()) of
        Baseline -> ok;
        Remaining ->
            case erlang:monotonic_time(millisecond) < Deadline of
                true -> receive after 10 -> await_event_logs(Baseline, Deadline) end;
                false -> error({event_logs_not_closed, Baseline, Remaining})
            end
    end.

debugger_roundtrip(Work) ->
    undefined = whereis(dbg_iserver),
    {error, {app, kernel}} = int:interpretable(file),
    {error, {app, stdlib}} = int:interpretable(lists),
    {error, {app, debugger}} = int:interpretable(dbg_ieval),
    Priv = code:priv_dir(debugger),
    {ok, <<137,80,78,71,13,10,26,10, _/binary>>} =
        file:read_file(filename:join(Priv, "erlang_bug.png")),
    Source = filename:join(Work, "otp_interpreted_probe.erl"),
    ok = file:write_file(Source,
        "-module(otp_interpreted_probe).\n-export([run/1]).\n"
        "run(N) -> N + 1.\n"),
    {ok, otp_interpreted_probe} = compile:file(Source, [debug_info, {outdir, Work}]),
    {module, otp_interpreted_probe} = int:i(Source),
    [otp_interpreted_probe] = int:interpreted(),
    42 = otp_interpreted_probe:run(41),
    ok = int:break(otp_interpreted_probe, 3),
    [{{otp_interpreted_probe, 3}, _}] = int:all_breaks(),
    ok = int:no_break(),
    ok = int:n(otp_interpreted_probe),
    [] = int:interpreted(),
    43 = otp_interpreted_probe:run(42),
    false = lists:keymember(wx, 1, application:which_applications()),
    ok.

megaco_roundtrip() ->
    {ok, [megaco]} = application:ensure_all_started(megaco),
    true = megaco_flex_scanner:is_enabled(),
    true = megaco_flex_scanner:is_reentrant_enabled(),
    {ok, Ports} = megaco_flex_scanner:start(),
    try
        lists:foreach(fun(Version) ->
            Message = #'MegacoMessage'{mess = #'Message'{version = Version,
                mId = {domainName, #'DomainName'{name = "controller", portNumber = 2944}},
                messageBody = {messageError, #'ErrorDescriptor'{errorCode = 500,
                                                               errorText = "OTP libbeam"}}}},
            lists:foreach(fun(Codec) ->
                {ok, Encoded} = Codec:encode_message([], Version, Message),
                {ok, Message} = Codec:decode_message([], Version, Encoded)
            end, [megaco_pretty_text_encoder, megaco_compact_text_encoder,
                  megaco_ber_encoder, megaco_per_encoder, megaco_erl_dist_encoder]),
            %% The retained Flex scanner lowercases quoted token text, unlike
            %% the Erlang scanner. Preserve and check that existing behavior.
            FlexMessage = Message#'MegacoMessage'{mess =
                (Message#'MegacoMessage'.mess)#'Message'{messageBody =
                    {messageError, #'ErrorDescriptor'{errorCode = 500,
                                                     errorText = "otp libbeam"}}}},
            lists:foreach(fun(Codec) ->
                {ok, Text} = Codec:encode_message([], Version, Message),
                {ok, FlexMessage} = Codec:decode_message([{flex, Ports}], Version, Text)
            end, [megaco_pretty_text_encoder, megaco_compact_text_encoder])
        end, [1,2,3])
    after
        stopped = megaco_flex_scanner:stop(Ports)
    end,
    %% The ordinary runtime selects the reentrant scanner. Exercise the retained
    %% standard driver explicitly through its public driver/port interface too.
    Name = "megaco_flex_scanner_drv",
    ok = erl_ddll:load_driver(filename:join(code:priv_dir(megaco), "lib"), Name),
    Port = open_port({spawn_driver, Name}, [binary]),
    try
        {ok, [_|_], 1, _} = megaco_flex_scanner:scan(<<"MEGACO/1 <controller> Error = 500 { \"OTP libbeam\" }">>, Port)
    after
        true = port_close(Port),
        ok = erl_ddll:unload_driver(Name)
    end,
    ok = application:stop(megaco),
    undefined = whereis(megaco_sup),
    ok.

snmp_roundtrip(Work, Backend) ->
    Root = filename:join(Work, "snmp-" ++ atom_to_list(Backend)),
    Agent = filename:join(Root, "agent"),
    Manager = filename:join(Root, "manager"),
    lists:foreach(fun(Dir) -> ok = filelib:ensure_dir(filename:join(Dir, "placeholder")) end,
                  [Agent, Manager]),
    %% Hold both reservations until distinct ephemeral ports have been chosen.
    {ok, A} = gen_udp:open(0, [{ip, {127,0,0,1}}]),
    {ok, M} = gen_udp:open(0, [{ip, {127,0,0,1}}]),
    {ok, AgentPort} = inet:port(A),
    {ok, ManagerPort} = inet:port(M),
    ok = gen_udp:close(A), ok = gen_udp:close(M),
    Name = "OTP-on-BEAM-" ++ atom_to_list(Backend),
    ok = snmp_config:write_agent_snmp_files(Agent, [v2], [127,0,0,1], ManagerPort,
                                          [127,0,0,1], AgentPort, Name),
    ok = snmp_config:write_manager_snmp_files(Manager, [127,0,0,1], ManagerPort, 484, "managerEngine"),
    Net = [{options, [{bind_to, true}, {inet_backend, Backend}]}],
    ok = application:set_env(snmp, agent,
        [{versions, [v2]}, {db_dir, Agent}, {config, [{dir, Agent}, {force_load, true}]},
         {net_if, Net}]),
    ok = application:set_env(snmp, manager,
        [{versions, [v2]}, {config, [{dir, Manager}, {db_dir, Manager}]}, {net_if, Net}]),
    {ok, [snmp]} = application:ensure_all_started(snmp),
    try
        ok = snmpm:register_user(product, snmpm_user_default, []),
        ok = snmpm:register_agent(product, "loopback",
            [{address, {127,0,0,1}}, {port, AgentPort}, {engine_id, "agentEngine"},
             {community, "public"}, {version, v2}]),
        Oid = [1,3,6,1,2,1,1,5,0],
        {ok, {noError, 0, [#varbind{oid=Oid, variabletype='OCTET STRING', value=Name}]}, _} =
            snmpm:sync_get2(product, "loopback", [Oid]),
        ok = snmpm:unregister_agent(product, "loopback"),
        ok = snmpm:unregister_user(product)
    after
        ok = application:stop(snmp),
        ok = application:unload(snmp)
    end,
    undefined = whereis(snmp_master_agent),
    undefined = whereis(snmpm_server),
    ok.

dialyzer_roundtrip(Work) ->
    Source = filename:join(Work, "installed_type_probe.erl"),
    ok = file:write_file(Source,
        "-module(installed_type_probe).\n-export([identity/1]).\n"
        "-spec identity(integer()) -> integer().\nidentity(N) when is_integer(N) -> N.\n"),
    {ok, installed_type_probe} = compile:file(Source, [debug_info, {outdir, Work}]),
    Beam = filename:join(Work, "installed_type_probe.beam"),
    Plt = filename:join(Work, "probe.plt"),
    [] = dialyzer:run([{analysis_type, plt_build}, {files, [Beam]},
                      {output_plt, Plt}, {warnings, [no_unknown]}]),
    {ok, [{files, [Beam]}]} = dialyzer:plt_info(Plt),
    BadSource = filename:join(Work, "installed_bad_type.erl"),
    ok = file:write_file(BadSource,
        "-module(installed_bad_type).\n-export([broken/0]).\n"
        "broken() -> installed_type_probe:identity(not_an_integer).\n"),
    Warnings = dialyzer:run([{analysis_type, succ_typings}, {from, src_code},
        {files, [BadSource]}, {init_plt, Plt}, {check_plt, false}, {warnings, [no_unknown]}]),
    true = lists:keymember(warn_failing_call, 1, Warnings),
    true = lists:keymember(warn_return_no_exit, 1, Warnings),
    ok.

os_monitoring() ->
    {ok, Started} = application:ensure_all_started(os_mon),
    true = lists:member(os_mon, Started),
    Count = cpu_sup:nprocs(),
    true = is_integer(Count) andalso Count > 0,
    Load = cpu_sup:avg1(),
    true = is_integer(Load) andalso Load >= 0,
    Utilization = cpu_sup:util(),
    true = is_number(Utilization) andalso Utilization >= 0 andalso Utilization =< 100,
    {Total, Used, {LargestPid, LargestBytes}} = memsup:get_memory_data(),
    true = is_integer(Total) andalso Total > 0 andalso Used >= 0 andalso Used =< Total,
    true = is_pid(LargestPid) andalso LargestBytes > 0,
    SystemTotal = proplists:get_value(total_memory, memsup:get_system_memory_data()),
    true = is_integer(SystemTotal) andalso SystemTotal > 0,
    [{_, DiskSize, Available, Percent}] = disksup:get_disk_info("/"),
    true = DiskSize > 0 andalso Available >= 0 andalso Available =< DiskSize,
    true = Percent >= 0 andalso Percent =< 100,
    Helpers = [begin
        Path = filename:join([code:priv_dir(os_mon), "bin", Name]),
        true = filelib:is_regular(Path),
        [Port] = [P || P <- erlang:ports(),
                      {name, Command} <- [erlang:port_info(P, name)],
                      string:find(Command, Path) =/= nomatch],
        {os_pid, OsPid} = erlang:port_info(Port, os_pid),
        true = is_integer(OsPid) andalso OsPid > 0,
        {Port, OsPid}
    end || Name <- ["cpu_sup", "memsup"]],
    [ok = application:stop(App) || App <- lists:reverse(Started)],
    wait_monitor_ports(Helpers, erlang:monotonic_time(millisecond) + 5000).

wait_monitor_ports(Ports, Deadline) ->
    case [{P, OsPid} || {P, OsPid} <- Ports,
                       erlang:port_info(P) =/= undefined orelse
                       native_process_alive(OsPid)] of
        [] -> ok;
        Remaining ->
            true = erlang:monotonic_time(millisecond) < Deadline,
            receive after 10 -> wait_monitor_ports(Remaining, Deadline) end
    end.

tls_roundtrip(Version, Backend, #{server_config := Server, client_config := Client}, Data) ->
    Common = [{versions, [Version]}, binary, {active, false}],
    %% gen_tcp requires backend selection before all transport options.
    {ok, Listener} = ssl:listen(0, [{inet_backend, Backend}, {ip, {127,0,0,1}}, {verify, verify_peer},
                                  {fail_if_no_peer_cert, true} | Server ++ Common]),
    {ok, {_, Port}} = ssl:sockname(Listener),
    {Pid, Monitor} = spawn_monitor(fun() ->
        {ok, Transport} = ssl:transport_accept(Listener, 5000),
        {ok, Socket} = ssl:handshake(Transport, 5000),
        {ok, Data} = ssl:recv(Socket, byte_size(Data), 5000),
        ok = ssl:send(Socket, Data),
        ok = ssl:close(Socket)
    end),
    {ok, Socket} = ssl:connect({127,0,0,1}, Port,
        [{inet_backend, Backend}, {verify, verify_peer},
         {server_name_indication, net_adm:localhost()} | Client ++ Common], 5000),
    {ok, [{protocol, Version}]} = ssl:connection_information(Socket, [protocol]),
    Certificate = proplists:get_value(cert, Server),
    {ok, Certificate} = ssl:peercert(Socket),
    ok = ssl:send(Socket, Data),
    {ok, Data} = ssl:recv(Socket, byte_size(Data), 5000),
    ok = ssl:close(Socket),
    receive {'DOWN', Monitor, process, Pid, normal} -> ok
    after 5000 -> error(tls_server_not_finished)
    end,
    ok = ssl:close(Listener).

tracing_roundtrip(Work) ->
    {ok, [runtime_tools]} = application:ensure_all_started(runtime_tools),
    none = erlang:system_info(dynamic_trace),
    false = dyntrace:available(),
    error = dyntrace:user_trace_s1("probe"),
    File = filename:join(Work, "trace.log"),
    Self = self(),
    Expected = {trace, Self, call, {dbg, get_tracer, []}},
    Handler = fun(Event, Owner) -> Owner ! {traced, Event}, Owner end,
    lists:foreach(fun(Kind) ->
        Destination = case Kind of ip -> 0; file -> File end,
        {ok, _} = dbg:tracer(port, dbg:trace_port(Kind, Destination)),
        {ok, [{matched, _, 1}]} = dbg:p(self(), call),
        {ok, _} = dbg:tp(dbg, get_tracer, []),
        {ok, _} = dbg:get_tracer(),
        Client = case Kind of
            ip ->
                {ok, Port} = dbg:trace_port_control(get_listen_port),
                dbg:trace_client(ip, Port, {Handler, Self});
            file ->
                ok = dbg:flush_trace_port(),
                ok = dbg:stop(),
                dbg:trace_client(file, File, {Handler, Self})
        end,
        true = is_pid(Client),
        Monitor = erlang:monitor(process, Client),
        receive {traced, Expected} -> ok
        after 5000 -> error({missing_trace, Kind}) end,
        ok = dbg:stop(),
        receive {'DOWN', Monitor, process, Client, _} -> ok
        after 5000 -> error({trace_client_survived, Kind}) end,
        drain_traces()
    end, [ip, file]),
    ok = application:stop(runtime_tools).

drain_traces() ->
    receive {traced, _} -> drain_traces() after 0 -> ok end.

database_roundtrip(Work) ->
    Directory = filename:join(Work, "mnesia"),
    ok = application:load(mnesia),
    ok = application:set_env(mnesia, dir, Directory),
    case filelib:is_file(filename:join(Directory, "schema.DAT")) of
        false -> ok = mnesia:create_schema([node()]);
        true -> ok
    end,
    ok = mnesia:start(),
    ok = mnesia:wait_for_tables([schema], 5000),
    case mnesia:create_table(product_records,
            [{attributes, [key, value]}, {disc_copies, [node()]}]) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, product_records}} -> ok
    end,
    ok = mnesia:wait_for_tables([product_records], 5000),
    Expected = case file:read_file(filename:join(Work, "restarts")) of
        {error, enoent} -> 0;
        {ok, Bytes} -> binary_to_integer(Bytes)
    end,
    {atomic, Expected} = mnesia:transaction(fun() ->
        case mnesia:read(product_records, count) of
            [] -> 0;
            [{product_records, count, Count}] -> Count
        end
    end),
    Next = Expected + 1,
    {atomic, ok} = mnesia:transaction(fun() ->
        mnesia:write({product_records, count, Next})
    end),
    {aborted, rejected} = mnesia:transaction(fun() ->
        mnesia:write({product_records, count, -1}),
        mnesia:abort(rejected)
    end),
    ok = mnesia:sync_log(),
    ok = mnesia:backup(filename:join(Work, "database.backup")),
    stopped = mnesia:stop(),
    ok = mnesia:start(),
    ok = mnesia:wait_for_tables([product_records], 5000),
    {atomic, [{product_records, count, Next}]} =
        mnesia:transaction(fun() -> mnesia:read(product_records, count) end),
    stopped = mnesia:stop().

http_roundtrip(Work, Data) ->
    Root = filename:join(Work, "http_server"),
    Documents = filename:join(Root, "documents"),
    Filename = filename:join(Documents, "probe.txt"),
    ok = filelib:ensure_dir(Filename),
    ok = file:write_file(Filename, Data),
    {ok, [inets]} = application:ensure_all_started(inets),
    {ok, Server} = inets:start(httpd,
        [{port, 0}, {bind_address, {127,0,0,1}}, {server_name, "otp-probe"},
         {server_root, Root}, {document_root, Documents},
         {modules, [mod_alias, mod_get, mod_head]},
         {mime_types, [{"txt", "text/plain"}]}]),
    [{port, Port}] = httpd:info(Server, [port]),
    Url = "http://127.0.0.1:" ++ integer_to_list(Port) ++ "/probe.txt",
    {ok, {{"HTTP/1.1", 200, _}, Headers, Data}} =
        httpc:request(get, {Url, []}, [{timeout, 5000}], [{body_format, binary}]),
    {ok, Version} = application:get_key(inets, vsn),
    ServerSoftware = "inets/" ++ Version,
    ServerSoftware = proplists:get_value("server", Headers),
    {ok, {{"HTTP/1.1", 200, _}, _, <<>>}} =
        httpc:request(head, {Url, []}, [{timeout, 5000}], [{body_format, binary}]),
    {ok, {{"HTTP/1.1", 404, _}, _, _}} =
        httpc:request(get, {Url ++ ".missing", []}, [{timeout, 5000}], []),
    ok = inets:stop(httpd, Server),
    ok = inets:stop().

xml_and_unit_tests(Work) ->
    {Document, []} = xmerl_scan:string("<root><item>installed XML</item></root>"),
    {xmlObj, string, "installed XML"} = xmerl_xpath:string("string(/root/item)", Document),
    Event = fun({startElement, _, _, _, _}, _, N) -> N + 1;
               (_, _, N) -> N
            end,
    {ok, 2, <<>>} = xmerl_sax_parser:stream(<<"<root><item/></root>">>,
                                             [{event_fun, Event}, {event_state, 0}]),
    Source = filename:join(Work, "installed_eunit_probe.erl"),
    ok = file:write_file(Source,
        "-module(installed_eunit_probe).\n"
        "-include_lib(\"eunit/include/eunit.hrl\").\n"
        "value_test() -> ?assertEqual(3, 1 + 2).\n"
        "xml_test() -> {_, []} = xmerl_scan:string(\"<ok/>\").\n"),
    {ok, installed_eunit_probe, Beam} = compile:file(Source, [binary, report]),
    {module, installed_eunit_probe} = code:load_binary(installed_eunit_probe, Source, Beam),
    ok = eunit:test(installed_eunit_probe),
    true = code:delete(installed_eunit_probe),
    false = code:purge(installed_eunit_probe),
    ok.

transfer_roundtrip(Work, Data) ->
    ok = application:start(ftp),
    true = is_pid(whereis(ftp_sup)),
    ok = application:stop(ftp),
    Root = filename:join(Work, "tftp-root"),
    ok = filelib:ensure_dir(filename:join(Root, "placeholder")),
    ok = application:start(tftp),
    {ok, Daemon} = tftp:start([{port, 0}, {host, {127,0,0,1}},
                             {callback, {"", tftp_file, [{root_dir, Root}]}}]),
    {ok, Options} = tftp:info(Daemon),
    {port, Port} = lists:keyfind(port, 1, Options),
    Blob = binary:copy(Data, 100),
    Size = byte_size(Blob),
    {ok, Size} = tftp:write_file("roundtrip.bin", Blob, [{port, Port}, {host, {127,0,0,1}}]),
    {ok, Blob} = tftp:read_file("roundtrip.bin", binary, [{port, Port}, {host, {127,0,0,1}}]),
    {ok, Blob} = file:read_file(filename:join(Root, "roundtrip.bin")),
    Monitor = monitor(process, Daemon),
    unlink(Daemon),
    exit(Daemon, shutdown),
    receive {'DOWN', Monitor, process, Daemon, _} -> ok after 5000 -> error(tftp_daemon_shutdown) end,
    ok = application:stop(tftp).

ssh_roundtrip(Work, PrivateKey, Data) ->
    {ok, Started} = application:ensure_all_started(ssh),
    [asn1, crypto, public_key, ssh] = lists:sort(Started),
    Root = filename:join(Work, "ssh-root"),
    ok = filelib:ensure_dir(filename:join(Root, "placeholder")),
    KeyFile = filename:join(Root, "ssh_host_rsa_key"),
    ok = file:write_file(KeyFile, public_key:pem_encode([
                                  public_key:pem_entry_encode('RSAPrivateKey', PrivateKey)])),
    ok = file:change_mode(KeyFile, 8#600),
    Exec = fun("installed-command") -> {ok, binary_to_list(Data)} end,
    {ok, Daemon} = ssh:daemon({127,0,0,1}, 0,
                    [{system_dir, Root}, {user_dir, Root}, {auth_methods, "password"},
                     {user_passwords, [{"otp-test", "temporary-test-password"}]},
                     {exec, {direct, Exec}},
                     {subsystems, [ssh_sftpd:subsystem_spec([{cwd, Root}, {root, Root}])]}]),
    {port, Port} = ssh:daemon_info(Daemon, port),
    {ok, Connection} = ssh:connect({127,0,0,1}, Port,
                    [{user, "otp-test"}, {password, "temporary-test-password"},
                     {user_dir, Root}, {user_interaction, false},
                     {silently_accept_hosts, true}, {save_accepted_host, false}], 5000),
    {ok, Channel} = ssh_connection:session_channel(Connection, 5000),
    success = ssh_connection:exec(Connection, Channel, "installed-command", 5000),
    Data = ssh_command_result(Connection, Channel, <<>>, undefined),
    {ok, Sftp} = ssh_sftp:start_channel(Connection),
    ok = ssh_sftp:write_file(Sftp, "transfer.bin", Data),
    {ok, Data} = ssh_sftp:read_file(Sftp, "transfer.bin"),
    {ok, Data} = file:read_file(filename:join(Root, "transfer.bin")),
    ok = ssh_sftp:stop_channel(Sftp),
    ok = ssh:close(Connection),
    ok = ssh:stop_daemon(Daemon),
    [ok = application:stop(App) || App <- lists:reverse(Started)],
    ok.

ssh_command_result(Connection, Channel, Data, Status) ->
    receive
        {ssh_cm, Connection, {data, Channel, 0, More}} ->
            ssh_command_result(Connection, Channel, <<Data/binary, More/binary>>, Status);
        {ssh_cm, Connection, {exit_status, Channel, Code}} ->
            ssh_command_result(Connection, Channel, Data, Code);
        {ssh_cm, Connection, {eof, Channel}} ->
            ssh_command_result(Connection, Channel, Data, Status);
        {ssh_cm, Connection, {closed, Channel}} ->
            0 = Status,
            Data
    after 5000 -> error(ssh_command_timeout)
    end.

documentation_roundtrip(Work) ->
    Source = filename:join(Work, "installed_edoc_probe.erl"),
    ok = file:write_file(Source,
        "%% @doc Installed documentation generator.\n"
        "-module(installed_edoc_probe).\n"
        "-export([value/0]).\n"
        "%% @doc Returns the installed test value.\n"
        "-spec value() -> integer().\n"
        "value() -> 42.\n"),
    HtmlDir = filename:join(Work, "edoc-html"),
    ok = edoc:files([Source], [{dir, HtmlDir}]),
    {ok, Html} = file:read_file(filename:join(HtmlDir, "installed_edoc_probe.html")),
    true = binary:match(Html, <<"Installed documentation generator">>) =/= nomatch,
    true = filelib:is_regular(filename:join(HtmlDir, "stylesheet.css")),
    ChunkDir = filename:join(Work, "edoc-chunks"),
    ok = edoc:files([Source], [{doclet, edoc_doclet_chunks},
                             {layout, edoc_layout_chunks}, {dir, ChunkDir}]),
    {ok, Chunk} = file:read_file(filename:join([ChunkDir, "chunks", "installed_edoc_probe.chunk"])),
    Docs = binary_to_term(Chunk),
    docs_v1 = element(1, Docs),
    ok = shell_docs:validate(Docs).


diameter_roundtrip(Work) ->
    Root = filename:join(Work, "diameter-example-sources"),
    Out = filename:join(Work, "diameter-examples"),
    ok = filelib:ensure_dir(filename:join(Out, "placeholder")),
    lists:foreach(fun(Module) ->
        Source = filename:join(Root, atom_to_list(Module) ++ ".erl"),
        {ok, Module} = compile:file(Source, [report_errors, report_warnings, {outdir, Out}]),
        {module, Module} = code:load_abs(filename:join(Out, atom_to_list(Module)))
    end, [client, client_cb, server, server_cb]),
    {ok, [diameter]} = application:ensure_all_started(diameter),
    Server = otp_diameter_server,
    Client = otp_diameter_client,
    ok = server:start(Server, []),
    ok = client:start(Client, []),
    true = diameter:subscribe(Client),
    try
        {ok, Listener} = server:listen(Server, {tcp, loopback, 0}),
        Port = diameter_port(Listener, erlang:monotonic_time(millisecond) + 5000),
        {ok, _} = client:connect(Client, {tcp, loopback, Port}),
        receive
            #diameter_event{service=Client, info=Info} when element(1, Info) =:= up -> ok
        after 5000 -> error(diameter_peer_timeout)
        end,
        Session = diameter:session_id("otp-product"),
        SessionBytes = iolist_to_binary(Session),
        {ok, ['ACA' | #{'Result-Code' := 2001, 'Session-Id' := SessionBytes,
                        'Accounting-Record-Number' := 7}]} =
            client:call(Client, #{'Session-Id' => Session, 'Accounting-Record-Number' => 7})
    after
        true = diameter:unsubscribe(Client),
        ok = client:stop(Client),
        ok = server:stop(Server),
        ok = application:stop(diameter)
    end.

diameter_port(Listener, Deadline) ->
    case diameter_tcp:ports(Listener) of
        [{listen, Port, _}] -> Port;
        [] ->
            case erlang:monotonic_time(millisecond) < Deadline of
                true -> receive after 10 -> diameter_port(Listener, Deadline) end;
                false -> error(diameter_listener_timeout)
            end
    end.

%% Test-owned native observations; errors remain assertion failures.
observe(Mode, Pid) ->
    Probe = os:getenv("OTP_TEST_HOST_OBSERVER"),
    true = is_list(Probe),
    Port = open_port({spawn_executable, Probe},
                     [binary, exit_status, {args, [Mode, integer_to_list(Pid)]}]),
    Read = fun F(Acc) -> receive
        {Port, {data, B}} -> F(<<Acc/binary, B/binary>>);
        {Port, {exit_status, 0}} -> json:decode(Acc)
        after 5000 -> error(host_observation_timeout)
    end end,
    Read(<<>>).

host_images() ->
    case os:type() of
        {unix, darwin} ->
            #{<<"executable">> := Executable, <<"files">> := Files} =
                observe("--images", list_to_integer(os:getpid())),
            true = Files =/= [],
            {unicode:characters_to_list(Executable),
             iolist_to_binary(lists:join(<<"\n">>, Files))};
        _ ->
            {ok, Host} = file:read_link("/proc/self/exe"),
            {ok, Maps} = file:read_file("/proc/self/maps"),
            {Host, Maps}
    end.

native_process_alive(Pid) ->
    case os:type() of
        {unix, darwin} ->
            #{<<"alive">> := Alive, <<"zombie">> := Zombie} = observe("--state", Pid),
            Alive andalso not Zombie;
        _ -> filelib:is_dir("/proc/" ++ integer_to_list(Pid))
    end.
