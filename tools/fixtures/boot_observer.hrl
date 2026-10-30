%% SPDX-License-Identifier: Apache-2.0
%% Test-only observer included in a generated init, never product bytecode.
before_boot() ->
    checked(fun () ->
        undefined = whereis(init),
        undefined = whereis(erl_prim_loader),
        false = erlang:module_loaded(code),
        true = erts_internal:is_system_process(self()),
        ok = check_preloads(),
        ok = check_startup_loaded([erl_init, init, prim_buffer, prim_eval, prim_inet, prim_file, zlib,
     socket_registry, prim_socket, prim_net, prim_zip, erl_prim_loader, erl_tracer]),
        ok = check_primitives(),
        #{included := Embedded, excluded := Excluded} = erlang:system_info(embedded_3pps),
        [zstd] = [Name || Name <- Embedded, Name =:= zstd],
        [] = [Name || Name <- Excluded, Name =:= zstd],
        Janitor = unique_helper(prim_file),
        Registry = unique_helper(socket_registry),
        ok = persistent_term:get({prim_socket, load_nif_result}),
        ok = persistent_term:get({prim_net, load_nif_result}),
        Protocols = persistent_term:get({prim_socket, protocols}),
        true = is_map(Protocols),
        boot_activation = ets:new(boot_activation, [named_table, public]),
        true = ets:insert(boot_activation,
                          [{origin, self(), group_leader(), Janitor,
                            Registry, Protocols}, {cycle, 0}]),
        ok = check_driver_ownership(self()),
        ok = persistent_term:put({boot_probe, marker}, before_init),
        erlang:display(boot_activation_before_init)
    end).

%% Called by a generated test init before registration. The production erl_init
%% activation and native first-process entry remain unchanged.

after_boot() ->
    checked(fun () ->
        [{origin, Init, Leader, Janitor, Registry, Protocols}] =
            ets:lookup(boot_activation, origin),
        Init = whereis(init),
        {group_leader, Leader} = process_info(Init, group_leader),
        {initial_call, {erl_init, start, 2}} =
            process_info(Init, initial_call),
        Janitor = unique_helper(prim_file),
        Registry = unique_helper(socket_registry),
        Registry = whereis(socket_registry),
        Protocols = persistent_term:get({prim_socket, protocols}),
        ok = check_driver_ownership(Init),
        ok = check_primitives(),
        #{included := Embedded, excluded := Excluded} = erlang:system_info(embedded_3pps),
        [zstd] = [Name || Name <- Embedded, Name =:= zstd],
        [] = [Name || Name <- Excluded, Name =:= zstd],
        ok = check_module_policy(),
        case ets:lookup(boot_activation, cycle) of
            [{cycle, 0}] ->
                before_init = persistent_term:get({boot_probe, marker}),
                true = ets:insert(boot_activation, {cycle, 1}),
                erlang:display(boot_activation_first_boot),
                ok = init:restart();
            [{cycle, Cycle}] when Cycle < 3 ->
                missing = persistent_term:get({boot_probe, marker}, missing),
                true = ets:insert(boot_activation, {cycle, Cycle + 1}),
                ok = init:restart();
            [{cycle, 3}] ->
                missing = persistent_term:get({boot_probe, marker}, missing),
                erlang:display(boot_activation_restart_ok),
                erlang:halt(0)
        end
    end).

core_modules() ->
    [atomics, counters, persistent_term, erlang, erts_code_purger,
     erts_dirty_process_signal_handler, erts_internal,
     erts_literal_area_collector, erts_trace_cleaner].

check_preloads() ->
    Expected = core_modules() ++ [erl_init, init, prim_buffer, prim_eval, prim_inet, prim_file, zlib,
     socket_registry, prim_socket, prim_net, prim_zip, erl_prim_loader, erl_tracer],
    Actual = erlang:pre_loaded(),
    Count = length(Expected),
    Count = length(Actual),
    [] = Expected -- Actual,
    [] = Actual -- Expected,
    ok.

check_startup_loaded([Module | Rest]) ->
    true = erlang:module_loaded(Module),
    check_startup_loaded(Rest);
check_startup_loaded([]) ->
    ok.

check_module_policy() ->
    ok = check_preloads(),
    Loaded = code:all_loaded(),
    lists:foreach(fun(Module) ->
        preloaded = code:which(Module),
        {file, preloaded} = code:is_loaded(Module),
        {Module, preloaded} = lists:keyfind(Module, 1, Loaded),
        true = code:is_sticky(Module)
    end, [erl_init, init, prim_buffer, prim_eval, prim_inet, prim_file, zlib,
     socket_registry, prim_socket, prim_net, prim_zip, erl_prim_loader, erl_tracer]),
    lists:foreach(fun(Module) ->
        preloaded = code:which(Module),
        true = code:is_sticky(Module)
    end, core_modules()),
    true = lists:member(prim_eval, [erl_init, init, prim_buffer, prim_eval, prim_inet, prim_file, zlib,
     socket_registry, prim_socket, prim_net, prim_zip, erl_prim_loader, erl_tracer]),
    preloaded = code:which(prim_eval),
    ok.

check_primitives() ->
    %% These run even before the Erlang code loader exists. They require real
    %% native attachment, not just exported placeholder functions.
    Atomics = atomics:new(2, [{signed, true}]),
    ok = atomics:put(Atomics, 1, 9),
    12 = atomics:add_get(Atomics, 1, 3),
    12 = atomics:exchange(Atomics, 1, 17),
    ok = atomics:compare_exchange(Atomics, 1, 17, 20),
    20 = atomics:get(Atomics, 1),
    #{size := 2} = atomics:info(Atomics),
    Counters = counters:new(2, [write_concurrency]),
    ok = counters:put(Counters, 1, 10),
    ok = counters:add(Counters, 1, 5),
    15 = counters:get(Counters, 1),
    #{size := 2} = counters:info(Counters),
    ok = persistent_term:put({boot_probe, data}, #{sample => 42}),
    #{sample := 42} = persistent_term:get({boot_probe, data}),
    true = persistent_term:erase({boot_probe, data}),
    #{count := _} = persistent_term:info(),
    Stream = zlib:open(),
    ok = zlib:close(Stream),
    discard = erl_tracer:enabled(trace_status, self(), self()),
    Buffer = prim_buffer:new(),
    ok = prim_buffer:write(Buffer, [<<"boot">>]),
    <<"boot">> = prim_buffer:read(Buffer, 4),
    0 = prim_buffer:size(Buffer),
    {ok, Directory} = prim_file:get_cwd(),
    true = is_list(Directory),
    true = is_map(prim_socket:info()),
    true = is_map(prim_net:info()),
    {ok, Tcp} = prim_inet:open(tcp, inet, stream),
    true = erlang:port_close(Tcp),
    {ok, Udp} = prim_inet:open(udp, inet, dgram),
    true = erlang:port_close(Udp),
    ok.

check_driver_ownership(_Owner) ->
    check_linked_drivers(["tcp_inet", "udp_inet", "ram_file_drv"]).

check_linked_drivers([Driver | Drivers]) ->
    true = erl_ddll:info(Driver, linked_in_driver),
    false = erl_ddll:info(Driver, permanent),
    linked_in_driver = erl_ddll:info(Driver, processes),
    check_linked_drivers(Drivers);
check_linked_drivers([]) -> ok.

unique_helper(Module) ->
    [Pid] = helpers(Module, erlang:processes()),
    true = erts_internal:is_system_process(Pid),
    Pid.

helpers(_Module, []) -> [];
helpers(Module, [Pid | Rest]) ->
    case process_info(Pid, initial_call) of
        {initial_call, {Module, start, 0}} ->
            [Pid | helpers(Module, Rest)];
        _ -> helpers(Module, Rest)
    end.

checked(Fun) ->
    try Fun() catch
        Class:Reason:Stack ->
            erlang:display({boot_activation_failed, Class, Reason, Stack}),
            erlang:halt(1)
    end.
