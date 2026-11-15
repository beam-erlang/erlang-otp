%% SPDX-License-Identifier: Apache-2.0
%% The pinned Common Test implementation owns specs, compilation and lifecycle.
%% This module selects native inputs and checks their retained result evidence.
-module(otp_ct_evidence).
-export([plan/2, execute/3, assess/5, reconcile/3, bind_current/3]).

plan(Ctx, Prepared) ->
    Domain = maps:get(domain, Ctx),
    Profile = maps:get(profile, Ctx),
    true = is_atom(Domain),
    require(lists:member(Profile, [full, suite]), invalid_profile),
    Stage = absolute(maps:get(stage_dir, Prepared)),
    Suites = [suite_atom(S) || S <- maps:get(suites, Prepared)],
    require(Suites =/= [] andalso length(Suites) =:= length(lists:usort(Suites)),
            invalid_suite_inventory),
    Spec = absolute(maps:get(spec, Prepared, maps:get(original_spec, Prepared, ""))),
    Platform = context_platform(Ctx),
    require(safe(get(platform, Prepared, null)) =:= safe(Platform), preparation_platform_mismatch),
    Excluded = exclusions(Domain, Platform),
    Inventory = suite_inventory(Prepared, Stage, Suites),
    Base = #{domain => Domain, profile => Profile, platform => Platform, stage_dir => Stage,
             original_spec => Spec, input_identity => maps:get(input_identity, Prepared),
             excluded_suites => Excluded, staged_suite_inventory => Inventory,
             staged_suite_inventory_sha256 => digest(Inventory), spec_inputs => []},
    Selected = case Profile of
        full ->
            require(Platform =:= linux orelse private_suites(Domain) =:= [],
                    private_vm_test_prerequisite_on_selected_platform),
            require(not lists:any(fun(K) -> maps:is_key(K, Ctx) end,
                                  [suite, group, testcase]), full_with_focus_selectors),
            Overlay = filename:join(work(Ctx), "selection-exclusions.spec"),
            Terms = case Excluded of
                [] -> [];
                _ -> [{skip_suites, Stage, Excluded, exclusion_reason()}]
            end,
            write_terms(Overlay, Terms),
            Files = [Spec, Overlay],
            [{_, Native}] = native_specs([Files]),
            {Run, Skip} = ct_testspec:prepare_tests(Native, node()),
            require(Run =/= [], empty_native_plan),
            NativeSuites = native_suite_projection(Run, Inventory, Stage),
            Base#{ct_options => [{spec, Files}, {join_specs, true}, {allow_user_terms, true}],
                  run => Run, skip => Skip, selected_suites => NativeSuites,
                  spec_inputs => safe([#{path => F, sha256 => file_sha(F)} || F <- Files]),
                  lifecycle => canonical, auxiliary => [], metadata => []};
        suite -> focus(Ctx, Prepared, Base, Suites)
    end,
    Batch = maps:get(batch, Prepared, #{}),
    Source = maps:get(original_source, Prepared, maps:get(source_root, Ctx, "")),
    Rules = [{Kind, verified_rules(get(Key, Batch, []), Source)} || {Kind, Key} <-
        [{applicability, applicability_rules}, {prerequisite, prerequisite_skip_rules}]],
    NativePlan = #{run => safe(maps:get(run, Selected)), skip => safe(maps:get(skip, Selected))},
    Selection = maps:with([domain, profile, platform, selected_suites, excluded_suites,
                           staged_suite_inventory_sha256, group, testcase, lifecycle, auxiliary], Selected),
    Selected#{native_plan => NativePlan, native_plan_sha256 => digest(NativePlan),
              selection => safe(Selection), rules => Rules}.

focus(Ctx, Prepared, Base, Suites) ->
    Requested = selectors(suite, Ctx, required),
    require(lists:all(fun(S) -> lists:member(S, Suites) end, Requested), unknown_suite),
    require(not lists:any(fun(S) -> lists:member(S, maps:get(excluded_suites, Base)) end,
                          Requested), excluded_private_vm_suite),
    require(not lists:any(fun(S) -> lists:member(S, private_suites(maps:get(domain, Base))) end,
                          Requested), private_vm_test_prerequisite_on_selected_platform),
    Groups = selectors(group, Ctx, optional),
    Cases = selectors(testcase, Ctx, optional),
    require((Groups =:= all andalso Cases =:= all) orelse length(Requested) =:= 1,
            group_or_case_requires_one_suite),
    Stage = maps:get(stage_dir, Base),
    true = code:add_patha(Stage),
    true = code:add_patha(absolute(maps:get(server_dir, Prepared))),
    focus_helpers(Stage, maps:get(staged_suite_inventory, Base)),
    Metadata = [{S, focus_metadata(Stage, S, Groups, Cases)} || S <- Requested],
    case {maps:get(domain, Base), Requested} of
        {emulator, [Boundary]} when Boundary =:= a_SUITE; Boundary =:= z_SUITE ->
            require(Groups =:= all, boundary_suite_has_no_groups),
            paired_focus(Ctx, Prepared, Base, Boundary, Cases, Metadata);
        {emulator, _} ->
            require(not lists:any(fun(S) -> S =:= a_SUITE orelse S =:= z_SUITE end,
                                  Requested), mixed_boundary_focus),
            direct_focus(Base, Requested, Groups, Cases, Metadata);
        _ -> direct_focus(Base, Requested, Groups, Cases, Metadata)
    end.

%% Original Make produces this inventory. Checking its bytes and CT's actual
%% source/BEAM discovery set prevents a missing generated suite becoming a
%% smaller successful directory run. Native Run/Skip still owns selection.
suite_inventory(Prepared, Stage0, Suites) ->
    Stage = absolute(Stage0),
    Inventory = safe(maps:get(staged_suite_inventory, Prepared,
                               maps:get(suite_inventory, Prepared, #{}))),
    Names = lists:sort([safe(S) || S <- Suites]),
    require(is_map(Inventory) andalso map_size(Inventory) > 0 andalso
            lists:sort(maps:keys(Inventory)) =:= Names, staged_suite_declaration_mismatch),
    lists:foreach(fun({Name, Entry}) ->
        Path = get(path, Entry, null),
        require(absolute_value(Path) andalso same_path(filename:dirname(Path), Stage) andalso
                filename:basename(Path) =:= <<Name/binary, ".erl">> andalso
                sha_value(get(sha256, Entry, null)) andalso file_sha(Path) =:= get(sha256, Entry, null),
                missing_or_changed_staged_suite),
        require(lists:member(get(origin, Entry, null), [<<"authored">>, <<"variant">>, <<"generated">>]),
                missing_staged_suite_origin)
    end, maps:to_list(Inventory)),
    Discovered = lists:usort([safe(filename:basename(P, filename:extension(P))) || P <-
        filelib:wildcard(filename:join(Stage, "*_SUITE.erl")) ++
        filelib:wildcard(filename:join(Stage, "*_SUITE" ++ code:objfile_extension()))]),
    require(Discovered =:= Names, staged_suite_discovery_mismatch),
    Inventory.

native_suite_projection(Run, Inventory, Stage) ->
    Names = lists:sort(maps:keys(Inventory)),
    Projected = lists:append([begin
        require(same_path(Dir, Stage), unproven_native_test_directory),
        case Ss of
            <<"all">> -> Names;
            List when is_list(List), List =/= [] -> [native_suite_name(S, Dir) || S <- List];
            Name when is_binary(Name) -> [native_suite_name(Name, Dir)];
            _ -> erlang:error({invalid_selection_or_evidence, invalid_native_suite_selection})
        end
    end || [Dir, Ss, _Cases] <- safe(Run)]),
    require(Projected =/= [], empty_native_suite_projection),
    stable_unique(Projected).

native_suite_name(Name, Dir) when is_binary(Name) ->
    require(filename:basename(Name) =:= Name andalso
            filelib:is_regular(filename:join(Dir, <<Name/binary, ".erl">>)), missing_native_suite_source),
    Name.

same_path(A, B) ->
    PA = filename:absname(unicode:characters_to_list(A)),
    PB = filename:absname(unicode:characters_to_list(B)),
    case os:type() of {win32, _} -> string:casefold(PA) =:= string:casefold(PB); _ -> PA =:= PB end.

direct_focus(Base, Suites, Groups, Cases, Metadata) ->
    Dir = maps:get(stage_dir, Base),
    Terms = case {Groups, Cases} of
        {all, all} -> [{suites, Dir, Suites}];
        {all, _} -> [{cases, Dir, hd(Suites), Cases}];
        {_, all} -> [{groups, Dir, hd(Suites), Groups}];
        _ -> [{groups, Dir, hd(Suites), Groups, {cases, Cases}}]
    end,
    Native = native_terms(Terms),
    {Run, Skip} = ct_testspec:prepare_tests(Native, node()),
    Options = [{dir, Dir}, {suite, Suites}] ++ optional(group, Groups) ++ optional(testcase, Cases),
    Base#{ct_options => Options, selection_terms => Terms, run => Run, skip => Skip, selected_suites => Suites,
          group => Groups, testcase => Cases, lifecycle => fresh_vm_suite,
          auxiliary => [], metadata => Metadata}.

%% These four holders and their counterparts are a pinned OTP contract.
%% A generated native spec orders both suites inside the same CT invocation.
paired_focus(Ctx, Prepared, Base, Boundary, Cases, Metadata) ->
    Stage = maps:get(stage_dir, Base),
    verify_boundary_sources(Prepared),
    Holders = [leaked_processes, long_timers, pollset_size, used_thread_specific_events],
    ZOrder = [used_thread_specific_events, schedulers_alive, node_container_refc_check,
              long_timers, pollset_size, check_io_debug, lc_graph, leaked_processes,
              literal_area_collector],
    {ACases, ZCases, Auxiliary} = case Boundary of
        a_SUITE ->
            A = case Cases of all -> Holders; _ -> Cases end,
            Z = [C || C <- ZOrder, lists:member(C, A)],
            {A, Z, [{z_SUITE, Z}]};
        z_SUITE ->
            Z = case Cases of all -> ZOrder; _ -> Cases end,
            A = [C || C <- Holders, lists:member(C, Z)],
            {A, Z, case A of [] -> []; _ -> [{a_SUITE, A}] end}
    end,
    _ = [focus_metadata(Stage, S, all, Cs) || {S, Cs} <-
            [{a_SUITE, ACases}, {z_SUITE, ZCases}], Cs =/= []],
    Terms = [{cases, Stage, S, Cs} || {S, Cs} <-
                 [{a_SUITE, ACases}, {z_SUITE, ZCases}], Cs =/= []],
    Path = filename:join(work(Ctx), "suite-lifecycle.spec"),
    write_terms(Path, Terms),
    [{_, Native}] = native_specs([Path]),
    {Run, Skip} = ct_testspec:prepare_tests(Native, node()),
    Base#{ct_options => [{spec, [Path]}], run => Run, skip => Skip,
          selected_suites => [S || {S, Cs} <- [{a_SUITE, ACases}, {z_SUITE, ZCases}], Cs =/= []],
          requested_suite => Boundary, group => all, testcase => Cases,
          lifecycle => paired_original_holders, auxiliary => Auxiliary, metadata => Metadata,
          expected_pairs => [{S, C} || {S, Cs} <- [{a_SUITE, ACases}, {z_SUITE, ZCases}], C <- Cs]}.

verify_boundary_sources(Prepared) ->
    Stage = maps:get(stage_dir, Prepared),
    Expected = [{a_SUITE, <<"653100c2c2fc169a870f91180798bbb5f41c71624739ec980be5103dfe56d94d">>},
                {z_SUITE, <<"b1537645a9340b9a80173746d817405b7a95c145e516b2365a7848ff953f1fbf">>}],
    lists:foreach(fun({S, Hash}) ->
        require(otp_ct_support:sha(filename:join(Stage, atom_to_list(S) ++ ".erl")) =:= Hash,
                changed_boundary_lifecycle_source)
    end, Expected).

%% run_make/3 compiles suites only; CT's helper wrapper is not exported.
%% Native make owns discovery, dependencies and each original Emakefile option.
focus_helpers(Stage, Suites) ->
    {ok, Cwd} = file:get_cwd(),
    ok = file:set_cwd(Stage),
    try
        Flags = [{i, filename:join(code:lib_dir(common_test), "include")},
                 {i, filename:join(code:lib_dir(xmerl), "include")}, debug_info],
        Targets = ct_make:all([noexec | Flags]),
        require(is_list(Targets), focus_helper_discovery_failed),
        Helpers = [M || {M, out_of_date} <- Targets,
                       not maps:is_key(unicode:characters_to_binary(filename:basename(M, ".erl")), Suites)],
        case ct_make:files(Helpers, [load | Flags]) of
            {up_to_date, _} -> ok;
            _ -> require(false, focus_helper_compile_failed)
        end
    after
        ok = file:set_cwd(Cwd)
    end.

%% Only native Emakefile compilation and native group expansion are used here.
%% CT does the authoritative expansion again in its ordinary initialized context.
focus_metadata(Stage, Suite, Groups, Cases) ->
    require(ct_run:run_make(Stage, Suite, []) =:= ok, focus_suite_compile_failed),
    Beam = filename:join(Stage, atom_to_list(Suite) ++ code:objfile_extension()),
    case code:is_loaded(Suite) of
        false -> {module, Suite} = code:load_abs(filename:rootname(Beam));
        {file, Loaded} -> require(filename:absname(Loaded) =:= filename:absname(Beam),
                                  focus_suite_loaded_from_other_source)
    end,
    require(not selection_hook(Suite), dynamic_focus_selection_hook),
    GroupDefs = case erlang:function_exported(Suite, groups, 0) of
        true -> Suite:groups(); false -> []
    end,
    require(is_list(GroupDefs), invalid_native_group_definitions),
    All = Suite:all(),
    require(is_list(All) andalso All =/= [], unavailable_or_empty_suite_selection),
    Conf = ct_groups:find_groups(Suite, all, all, GroupDefs),
    Expanded = ct_groups:expand_groups(All, Conf, Suite),
    Selected = case Groups of
        all -> Expanded;
        _ ->
            Found = [ct_groups:find_groups(Suite, G, Cases, GroupDefs) || G <- Groups],
            require(lists:all(fun(X) -> X =/= [] end, Found), unknown_or_empty_group),
            lists:append(Found)
    end,
    Pairs = native_pairs(Suite, Selected),
    require(Pairs =/= [], empty_native_selection),
    case Cases of
        all -> ok;
        _ -> require(lists:all(fun(C) -> lists:member({Suite, C}, Pairs) end, Cases),
                     unknown_or_unselected_testcase)
    end,
    #{suite => Suite, native_selection => safe(Selected),
      available_pairs => safe(Pairs), metadata_only => true}.

selection_hook(Suite) ->
    Hooks = try proplists:get_value(ct_hooks, Suite:suite(), []) catch error:undef -> [] end,
    lists:any(fun(H) ->
        Mod = case H of {M, _} -> M; {M, _, _} -> M; M -> M end,
        case code:ensure_loaded(Mod) of
            {module, Mod} -> erlang:function_exported(Mod, post_all, 3) orelse
                             erlang:function_exported(Mod, post_groups, 2);
            _ -> true
        end
    end, case is_atom(Hooks) of true -> [Hooks]; false -> Hooks end).

%% Traverse native expansion for validation, retaining repetitions in the plan.
native_pairs(Suite, List) when is_list(List) ->
    lists:append([native_pairs(Suite, T) || T <- List]);
native_pairs(Suite, {conf, _, _, Tests, _}) -> native_pairs(Suite, Tests);
native_pairs(Suite, {testcase, Case, _}) when is_atom(Case) -> [{Suite, Case}];
native_pairs(_Suite, {Mod, Case}) when is_atom(Mod), is_atom(Case) -> [{Mod, Case}];
native_pairs(Suite, Case) when is_atom(Case) -> [{Suite, Case}];
native_pairs(_, _) -> [].

execute(Ctx, Prepared, Plan) ->
    LogDir = absolute(maps:get(log_dir, Ctx, filename:join(work(Ctx), "ct"))),
    EventFile = filename:join(LogDir, "events.jsonl"),
    require(case file:list_dir(LogDir) of {error, enoent} -> true; {ok, []} -> true;
                                         _ -> false end, existing_ct_log_directory),
    ok = filelib:ensure_dir(EventFile),
    Runtime = absolute(maps:get(runtime_prefix, Ctx)),
    Program = otp_ct_support:installed_command(Runtime, ct_run),
    EventDir = filename:join(work(Ctx), "event-handler"),
    ok = filelib:ensure_path(EventDir),
    EventSource = filename:join([maps:get(source_root, Ctx), "tests", "otp", "support", "otp_ct_event.erl"]),
    {ok, otp_ct_event} = compile:file(EventSource, [warnings_as_errors, {outdir, EventDir}]),
    ShortName = "otp_ct_case_" ++ binary_to_list(binary:encode_hex(crypto:strong_rand_bytes(8), lowercase)),
    ChildNode = list_to_atom(ShortName ++ "@" ++ net_adm:localhost()),
    Overlay = filename:join(work(Ctx), "controller.spec"),
    Options = [{auto_compile, true}, {abort_if_missing_suites, true},
               {event_handler, {otp_ct_event, [EventFile]}} | extra_options(Ctx, Prepared)],
    write_terms(Overlay, Options),
    SelectionFiles = case maps:find(selection_terms, Plan) of
        {ok, Terms} ->
            FocusSpec = filename:join(work(Ctx), "suite-selection.spec"),
            write_terms(FocusSpec, Terms), [FocusSpec];
        error -> proplists:get_value(spec, maps:get(ct_options, Plan))
    end,
    Files = SelectionFiles ++ [Overlay],
    [{_, Native}] = native_specs([Files], ChildNode),
    {Run, Skip} = ct_testspec:prepare_tests(Native, ChildNode),
    require(safe(#{run => Run, skip => Skip}) =:= safe(maps:get(native_plan, Plan)),
            child_native_selection_mismatch),
    SpecInputs = [receipt(F) || F <- Files],
    ProgramInput = receipt(Program),
    HandlerInput = receipt(filename:join(EventDir, "otp_ct_event.beam")),
    Args = ["-sname", ShortName, "-logdir", LogDir, "-spec"] ++ Files ++
        ["-join_specs", "-allow_user_terms", "-exit_status", "ignore_config", "-erl_args",
         "-pa", EventDir, "-pz", absolute(maps:get(server_dir, Prepared)), "-pz", ".",
         "-boot", "start_sasl", "-sasl", "errlog_type", "error", "-enable-feature", "maybe_expr",
         "-ct_test_vars", "{net_dir,\"\"}", "-noinput", "-rsh", "ssh", "-start_epmd", "false"],
    Started = timestamp(),
    OldPath = os:getenv("PATH"),
    Separator = case os:type() of {win32, _} -> ";"; _ -> ":" end,
    os:putenv("PATH", filename:join(Runtime, "bin") ++ Separator ++ case OldPath of false -> ""; _ -> OldPath end),
    Command = try otp_ct_support:command(Ctx, Program, Args, maps:get(stage_dir, Plan), "ct-run")
        catch error:{command_failed, Finished} -> Finished
        after case OldPath of false -> os:unsetenv("PATH"); _ -> os:putenv("PATH", OldPath) end
    end,
    Evidence0 = #{node => safe(ChildNode), runtime_prefix => safe(Runtime), log_dir => safe(LogDir),
        command => safe(Command), program => ProgramInput,
        runtime_copy => maps:get(copy_receipt, maps:get(runtime_view, Ctx)),
        command_receipt => receipt(unicode:characters_to_list(maps:get(log, Command)) ++ ".command.json"),
        event_handler => HandlerInput, spec_inputs => SpecInputs},
    {Result, Facts, Evidence, NativeErrors} = native_result(EventFile, Evidence0),
    ChildFacts = Facts#{<<"execution_envelope">> => safe(get(execution_envelope,
        maps:get(runtime_facts, Ctx, #{}), null))},
    Report0 = assess(Ctx#{runtime_facts => ChildFacts}, Prepared, Plan, Result, EventFile),
    ControllerErrors = NativeErrors ++ runtime_identity_errors(Facts, safe(maps:get(identity, Ctx))),
    Errors = lists:usort(maps:get(errors, Report0) ++ ControllerErrors),
    Status = case ControllerErrors of [] -> maps:get(status, Report0); _ -> <<"failed">> end,
    Report = Report0#{errors => Errors, status => Status},
    %% The entry point publishes only after checking original inputs and the
    %% complete candidate/SDK identity again. Do not publish a partial success.
    Report#{started => Started, finished => timestamp(), phase => <<"finished">>,
            controller => maps:with([<<"node">>, <<"vm_start_time">>], Facts),
            native_execution => safe(Evidence),
            ct_options => safe([{logdir, LogDir}, {spec, Files}, {join_specs, true},
                                {allow_user_terms, true} | Options])}.

receipt(Path) -> #{path => safe(Path), sha256 => file_sha(Path)}.

%% These are the pinned ct_logs totals.info and original event-handler formats.
%% The native file is not completion evidence until the child has exited and
%% both CT completion events and the final runtime snapshot have been retained.
native_result(EventFile, Evidence) ->
    try
        {Events, []} = read_events(EventFile),
        [RunDir] = [D || #{<<"event">> := <<"start_logging">>, <<"data">> := D} <- Events],
        require(same_path(filename:dirname(RunDir), get(log_dir, Evidence, null)), invalid_native_log_directory),
        Totals = filename:join(RunDir, "totals.info"),
        {ok, Raw} = file:read_file(Totals),
        {Node, _Label, Logs, {P, F, U, A, NotBuilt}} = binary_to_term(Raw, [safe]),
        Result = {P, F, {U, A}},
        require(counts(Result) =/= null andalso is_list(Logs) andalso Logs =/= [], invalid_native_totals),
        InitialPath = EventFile ++ ".runtime.json", FinalPath = EventFile ++ ".runtime-final.json",
        Initial = verified_json_receipt(receipt(InitialPath)),
        Final = verified_json_receipt(receipt(FinalPath)),
        Stable = [format, node, vm_start_time, root_dir, erts_version, otp_release, emu_flavor,
                  emu_type, system_architecture, os_type, schedulers, schedulers_online,
                  dirty_cpu_schedulers, dirty_io_schedulers, boot_argument, epmd_port_argument, home],
        RuntimeValid = get(format, Initial, null) =:= 1 andalso
            lists:all(fun(K) -> get(K, Initial, '$missing') =:= get(K, Final, '$other') end, Stable) andalso
            get(node, Initial, null) =:= safe(Node) andalso safe(Node) =:= get(node, Evidence, null) andalso
            same_path(get(root_dir, Initial, ""), get(runtime_prefix, Evidence, null)) andalso
            get(sasl_started, Initial, false) =:= true andalso
            get(sasl_errlog_type, Initial, null) =:= [<<"ok">>, <<"error">>] andalso
            get(boot_argument, Initial, null) =:= [<<"ok">>, [[<<"start_sasl">>]]] andalso
            lists:member(<<"maybe_expr">>, get(enabled_features, Initial, [])),
        Complete = length([ok || #{<<"event">> := <<"test_done">>} <- Events]) =:= 1 andalso
                   length([ok || #{<<"event">> := <<"stop_logging">>} <- Events]) =:= 1,
        Errors = unless(RuntimeValid, invalid_native_controller_runtime) ++
            unless(Complete, incomplete_native_controller) ++ unless(NotBuilt =:= 0, native_suites_not_built) ++
            unless(get(exit_status, get(command, Evidence, #{}), null) =:= 0, native_controller_nonzero_exit),
        {Result, Final, maps:merge(safe(Evidence), safe(#{totals => receipt(Totals),
            initial_runtime => receipt(InitialPath), final_runtime => receipt(FinalPath),
            counts => counts(Result), not_built => NotBuilt})), Errors}
    catch Class:Reason ->
        {{native_result_error, Class, Reason}, #{}, Evidence,
            [<<"missing_or_invalid_native_result">>]}
    end.

extra_options(Ctx, Prepared) ->
    Options = maps:get(ct_options, Ctx, []),
    Allowed = [config, userconfig, include, ct_hooks, ct_hooks_order, enable_builtin_hooks,
               multiply_timetraps, scale_timetraps, verbosity, logopts, create_priv_dir],
    require(is_list(Options) andalso lists:all(fun({K, _}) -> lists:member(K, Allowed);
                                               (_) -> false end, Options),
            reserved_or_invalid_ct_option),
    Config = case proplists:lookup(config, Options) of
        none ->
            Server = absolute(maps:get(server_dir, Prepared)),
            PlatformFile = case context_platform(Ctx) of win32 -> "ts.win32.config";
                                                        _ -> "ts.unix.config" end,
            Paths = [filename:join(Server, F) || F <- ["ts.config", PlatformFile]],
            require(lists:all(fun filelib:is_regular/1, Paths), missing_original_ct_configuration),
            [{config, Paths}];
        {config, Paths} -> require(is_list(Paths) andalso Paths =/= [], empty_explicit_ct_configuration), []
    end,
    Options ++ Config ++ case proplists:is_defined(scale_timetraps, Options) of
        true -> []; false -> [{scale_timetraps, true}]
    end.

assess(Ctx, Prepared, Plan, Result, EventFile) ->
    {Events, ReadErrors} = read_events(EventFile),
    Counts = counts(Result),
    Stats = [D || #{<<"event">> := <<"test_stats">>, <<"data">> := D} <- Events],
    Complete = length([ok || #{<<"event">> := <<"test_done">>} <- Events]) =:= 1,
    StatsMatch = Counts =/= null andalso Stats =/= [] andalso lists:last(Stats) =:= Counts,
    Skips = classify_skips(Events, Plan, maps:get(runtime_facts, Ctx, #{})),
    Unexplained = [S || S <- Skips, maps:get(classification, S) =:= <<"unexplained-skip">>],
    Gaps = [S || S <- Skips, maps:get(classification, S) =:= <<"prerequisite-gap">>],
    Failed = [E || E <- Events, failed_event(E)],
    CountedSkips = length([ok || S <- Skips, maps:get(counted, S)]),
    SkipCountMatch = case Counts of [_, _, [U, A]] -> U + A =:= CountedSkips; _ -> false end,
    {Ordering, OrderErrors} = ordering(Events, Plan),
    CoverageErrors = focus_coverage(Events, Plan),
    Errors = ReadErrors ++ event_shape_errors(Events) ++ count_errors(Counts) ++
        unless(Complete, incomplete_or_multiple_test_runs) ++
        unless(StatsMatch, statistics_mismatch) ++ unless(SkipCountMatch, raw_skip_count_mismatch) ++
        when_true(Failed =/= [], failed_events) ++ when_true(Unexplained =/= [], unexplained_skips) ++
        OrderErrors ++ CoverageErrors,
    Status = case {Errors -- [<<"zero_passing_tests">>], Gaps, Errors} of
        {[], [], []} -> <<"passed">>;
        {[], [_ | _], _} -> <<"blocked">>;
        _ -> <<"failed">>
    end,
    Identity = safe(maps:get(identity, Ctx)),
    Report0 = #{format => 3, type => <<"ct">>, domain => safe(maps:get(domain, Plan)),
        profile => safe(maps:get(profile, Plan)), status => Status,
        errors => lists:usort(Errors), 
        identity => Identity, epoch => digest(Identity),
        selection => maps:get(selection, Plan), native_plan => maps:get(native_plan, Plan),
        native_plan_sha256 => maps:get(native_plan_sha256, Plan),
        spec_inputs => maps:get(spec_inputs, Plan),
        stage_dir => safe(maps:get(stage_dir, Plan)),
        staged_suite_inventory => maps:get(staged_suite_inventory, Plan),
        staged_suite_inventory_sha256 => maps:get(staged_suite_inventory_sha256, Plan),
        input_identity => safe(maps:get(input_identity, Plan)),
        raw_counts => Counts, raw_result => term_text(Result),
        event_file => safe(EventFile), event_sha256 => file_sha(EventFile),
        event_count => length(Events), events_complete => Complete,
        statistics_match => StatsMatch, skip_count_match => SkipCountMatch,
        skips => Skips, prerequisite_gaps => Gaps, failed_events => Failed,
        ordering => Ordering, raw_outcomes => [E || E <- Events, outcome(E)],
        runtime_facts => safe(maps:get(runtime_facts, Ctx, #{})),
        start_info => [D || #{<<"event">> := <<"start_info">>, <<"data">> := D} <- Events]},
    Report = case maps:find(source_root, Ctx) of
        {ok, Product} ->
            Manifest = filename:join(Product, "tests/otp/manifest.json"),
            Report0#{policy_manifest => safe(Manifest), policy_source_root =>
                safe(maps:get(original_source, Prepared, Product))};
        error -> Report0
    end,
    case maps:find(session, Ctx) of {ok, Session} -> Report#{session => safe(Session)}; error -> Report end.

classify_skips(Events, Plan, Facts) ->
    Rules = maps:get(rules, Plan, []),
    Apps = proplists:get_value(applicability, Rules, []),
    Prereqs = proplists:get_value(prerequisite, Rules, []),
    Propagated = [{R, propagated(Events, R)} || R <- Apps, get(propagate_group_skip, R, false)],
    lists:filtermap(fun({E, Index}) ->
        case skip_data(E) of
            false -> false;
            {Suite, FuncSpec, Reason} ->
                {Func, Group} = function(FuncSpec),
                {Class, Evidence} = case true of
                    _ when Suite =:= undefined -> {<<"unexplained-skip">>, null};
                    _ -> classify(Suite, Func, Group, Reason, E, Index, Plan,
                                  Apps, Prereqs, Facts, Propagated)
                end,
                {true, #{raw => E, event_index => Index, classification => Class, evidence => Evidence,
                         counted => counted_skip(E, Func)}}
        end
    end, lists:zip(Events, lists:seq(1, length(Events)))).

classify(Suite, Func, Group, Reason, Event, Index, Plan, Apps, Prereqs, Facts, Propagated) ->
    Explicit = lists:member(Suite, [safe(S) || S <- maps:get(excluded_suites, Plan)]) andalso
               Reason =:= safe(exclusion_reason()),
    Authored = [Skip || Skip <- maps:get(skip, Plan), native_skip_matches(Skip, Suite, Func, Group, Reason)],
    Prerequisite = [R || R <- Prereqs,
        rule_location(R, Suite, Func, Group) andalso prerequisite_reason(R, Reason, Event)
    ],
    Applicable = [R || R <- Apps,
        rule_location(R, Suite, Func, Group, Index, Propagated) andalso
        reason_matches(R, Reason) andalso predicate(get(predicate, R, #{}), Facts)
    ],
    case {Explicit, Authored, Prerequisite, Applicable, missing_requirement(Reason)} of
        {true, _, _, _, _} -> {<<"excluded-by-request">>, #{kind => <<"user-exclusion">>}};
        {_, [Skip | _], _, _, _} -> {<<"not-applicable">>, #{kind => <<"native-spec-skip">>, entry => safe(Skip)}};
        {_, _, [Rule | _], _, _} -> {<<"prerequisite-gap">>, #{kind => <<"prerequisite-rule">>, rule => Rule}};
        {_, _, _, _, true} -> {<<"prerequisite-gap">>, #{kind => <<"missing-ct-configuration">>}};
        {_, _, _, [Rule | _], _} -> {<<"not-applicable">>, #{kind => <<"applicability-rule">>, rule => Rule}};
        _ -> {<<"unexplained-skip">>, null}
    end.

native_skip_matches([Dir, Suite, Reason], S, F, G, R) -> native_skip_matches({Dir, Suite, Reason}, S, F, G, R);
native_skip_matches([Dir, Suite, Case, Reason], S, F, G, R) -> native_skip_matches({Dir, Suite, Case, Reason}, S, F, G, R);
native_skip_matches({_Dir, Suite, Reason}, S, _F, _G, R) -> suite_matches(Suite, S) andalso safe(Reason) =:= R;
native_skip_matches({_Dir, Suite, Case, Reason}, S, F, G, R) ->
    suite_matches(Suite, S) andalso safe(Reason) =:= R andalso case Case of
        {Group, Cases} -> safe(Group) =:= G andalso
                         native_case_member(F, Cases);
        [Group, Cases] when is_list(Cases); Cases =:= <<"all">> ->
            safe(Group) =:= G andalso native_case_member(F, Cases);
        all -> true;
        <<"all">> -> true;
        C when is_atom(C); is_binary(C) -> safe(C) =:= F;
        Cs when is_list(Cs) -> lists:member(F, safe(Cs));
        _ -> false
    end;
native_skip_matches(_, _, _, _, _) -> false.

suite_matches(Suite, S) -> safe(Suite) =:= S orelse safe(Suite) =:= <<"all">>.
native_case_member(_, all) -> true;
native_case_member(_, <<"all">>) -> true;
native_case_member(F, Cases) when is_list(Cases) -> lists:member(F, safe(Cases));
native_case_member(_, _) -> false.

rule_location(R, Suite, Func, Group) ->
    get(suite, R, undefined) =:= Suite andalso
    optional_equal(get('case', R, undefined), Func) andalso
    optional_member(get(cases, R, undefined), Func) andalso
    optional_equal(get(group, R, undefined), Group) andalso
    optional_member(get(allowed_groups, R, undefined), Group).

rule_location(R, S, F, G, Index, Propagated) ->
    Direct = rule_location(R, S, F, G),
    Inherited = get(suite, R, undefined) =:= S andalso
        optional_equal(get('case', R, undefined), F) andalso
        optional_member(get(cases, R, undefined), F) andalso
        lists:member(Index, proplists:get_value(R, Propagated, [])),
    Direct orelse Inherited.

predicate(Predicate, Facts) ->
    Fact = get(fact, Predicate, undefined),
    Actual = get(Fact, Facts, '$missing'),
    Value = get(value, Predicate, '$missing'),
    Actual =/= '$missing' andalso Value =/= '$missing' andalso
        case get(operator, Predicate, undefined) of
            <<"equal">> -> safe(Actual) =:= Value;
            <<"not_equal">> -> safe(Actual) =/= Value;
            _ -> false
        end.

reason_matches(R, Reason) ->
    case get(reason_matcher, R, undefined) of
        undefined -> get(reason, R, undefined) =:= Reason;
        <<"ktls-darwin-os-guard">> -> ktls_reason(Reason);
        _ -> false
    end.

ktls_reason([<<"ktls_notsup">>, [<<"os">>, [[<<"unix">>, <<"darwin">>], Version]]]) ->
    is_list(Version) andalso length(Version) =:= 3 andalso
        lists:all(fun(N) -> is_integer(N) andalso N >= 0 end, Version);
ktls_reason([<<"error">>, Reason]) -> ktls_reason(Reason);
ktls_reason(_) -> false.

prerequisite_reason(R, Reason, Event) ->
    case get(reason_matcher, R, undefined) of
        undefined -> get(reason, R, undefined) =:= Reason;
        <<"ct-telnet-missing-testconn-init">> ->
            lists:member(maps:get(<<"event">>, Event), [<<"tc_done">>, <<"tc_auto_skip">>]) andalso
                telnet_reason(Reason);
        _ -> false
    end.

telnet_reason([<<"failed">>, [<<"ct_telnet_SUITE">>, <<"init_per_testcase">>,
    [[<<"test_case_failed">>, <<"No connection to telnet server! Reason: {no_such_name,testconn}">>], Frames]]]) ->
    Ids = [[<<"test_server">>, <<"do_init_per_testcase">>, 2],
           [<<"test_server">>, <<"run_test_case_eval1">>, 6],
           [<<"test_server">>, <<"run_test_case_eval">>, 9]],
    is_list(Frames) andalso length(Frames) =:= 3 andalso
        lists:all(fun({Frame, Id}) -> is_list(Frame) andalso length(Frame) =:= 4 andalso
                      lists:sublist(Frame, 3) =:= Id end, lists:zip(Frames, Ids));
telnet_reason(_) -> false.

missing_requirement([Kind, [<<"not_available">>, _]]) ->
    lists:member(Kind, [<<"require_failed">>, <<"require_failed_in_suite0">>]);
missing_requirement(_) -> false.

%% Only a completed sequential skipped-group window can classify descendants
%% lacking a group label. Any running testcase/callback closes that window.
propagated(Events, Rule) ->
    Suite = get(suite, Rule, undefined), Group = get(group, Rule, undefined),
    {Result, _} = lists:foldl(fun({E, I}, {Accepted, Pending}) ->
        case E of
            #{<<"event">> := <<"tc_start">>, <<"data">> := [Suite, _]} -> {Accepted, none};
            #{<<"event">> := <<"tc_done">>, <<"data">> := [Suite, [<<"init_per_group">>, Group | _],
                [<<"skipped">>, Reason]]} ->
                {Accepted, case reason_matches(Rule, Reason) of true -> []; false -> none end};
            #{<<"event">> := <<"tc_done">>, <<"data">> := [Suite, _, _]} -> {Accepted, none};
            #{<<"event">> := <<"tc_user_skip">>, <<"data">> := [Suite, [<<"end_per_group">>, Group | _], Reason]}
              when is_list(Pending) ->
                {case reason_matches(Rule, Reason) of true -> Pending ++ Accepted; false -> Accepted end, none};
            #{<<"event">> := <<"tc_user_skip">>, <<"data">> := [Suite, _, Reason]} when is_list(Pending) ->
                {Accepted, case reason_matches(Rule, Reason) of true -> [I | Pending]; false -> none end};
            _ -> {Accepted, Pending}
        end
    end, {[], none}, lists:zip(Events, lists:seq(1, length(Events)))),
    Result.

verified_rules(Rules, Source) ->
    lists:foreach(fun(Rule) ->
        verify_source(get(source, Rule, undefined), get(source_sha256, Rule, undefined), Source),
        case get(caller_source, Rule, undefined) of
            undefined -> ok;
            Caller -> verify_source(Caller, get(caller_sha256, Rule, undefined), Source)
        end,
        lists:foreach(fun(H) -> verify_source(get(path, H, get(source, H, undefined)),
                                             get(sha256, H, get(source_sha256, H, undefined)), Source)
                      end, get(helper_sources, Rule, []))
    end, Rules),
    Rules.

verify_source(Path, Hash, Source) ->
    require(is_binary(Path) andalso is_binary(Hash) andalso byte_size(Hash) =:= 64,
            invalid_rule_source_identity),
    Parts = filename:split(binary_to_list(Path)),
    require(filename:pathtype(Path) =:= relative andalso not lists:member("..", Parts),
            invalid_rule_source_path),
    require(otp_ct_support:sha(filename:join(Source, Path)) =:= Hash, rule_source_identity_mismatch).

ordering(Events, Plan) ->
    Starts = [S || #{<<"event">> := <<"tc_start">>, <<"data">> := [S, _]} <- Events,
                   S =/= <<"ct_framework">>],
    Order = stable_unique(Starts),
    Nodes = lists:usort([N || #{<<"event">> := <<"tc_start">>, <<"node">> := N} <- Events]),
    Domain = maps:get(domain, Plan), Profile = maps:get(profile, Plan),
    Errors = case {Profile, Domain, maps:get(lifecycle, Plan)} of
        {full, emulator, _} -> unless(Order =/= [] andalso hd(Order) =:= <<"a_SUITE">> andalso
                                      lists:last(Order) =:= <<"z_SUITE">>, canonical_emulator_order);
        {full, system, _} -> unless(Order =/= [] andalso lists:last(Order) =:= <<"z_SUITE">>,
                                    canonical_system_order);
        {suite, emulator, paired_original_holders} ->
            unless(Order =:= [safe(S) || S <- maps:get(selected_suites, Plan)], paired_lifecycle_order);
        _ -> []
    end,
    {#{suite_start_order => Order, controller_nodes => Nodes, same_vm => length(Nodes) =:= 1},
     Errors ++ unless(length(Nodes) =:= 1, multiple_or_missing_ct_controller_nodes)}.

focus_coverage(Events, #{profile := suite} = Plan) ->
    Observed = [{S, element(1, function(F))} || E <- Events,
        {S, F, _} <- [outcome_data(E)], S =/= undefined,
        not callback(element(1, function(F)))],
    case maps:find(expected_pairs, Plan) of
        {ok, Pairs} -> unless(lists:sort(Observed) =:= lists:sort([{safe(S), safe(C)} || {S, C} <- Pairs]),
                             suite_lifecycle_case_mismatch);
        error ->
            Requested = maps:get(testcase, Plan, all),
            Metadata = maps:get(metadata, Plan, []),
            Allowed = lists:usort(lists:append([metadata_modules(S, M) || {S, M} <- Metadata])),
            Unknown = [S || {S, _} <- Observed, not lists:member(S, Allowed)],
            Missing = case Requested of
                all -> [S || {S, M} <- Metadata, not lists:any(fun(Mod) ->
                    lists:keymember(Mod, 1, Observed) end, metadata_modules(S, M))];
                _ -> [C || C <- Requested, not lists:member({safe(hd(maps:get(selected_suites, Plan))), safe(C)}, Observed)]
            end,
            Extra = case Requested of all -> []; _ -> [C || {_, C} <- Observed,
                not lists:member(C, [safe(X) || X <- Requested])] end,
            unless(Unknown =:= [] andalso Missing =:= [] andalso Extra =:= [], suite_case_mismatch)
    end;
focus_coverage(_, _) -> [].

metadata_modules(Suite, Metadata) ->
    lists:usort([safe(Suite) | [M || [M, _] <- get(available_pairs, Metadata, [])]]).

read_events(Path) ->
    case file:read_file(Path) of
        {ok, <<>>} -> {[], [<<"empty_event_log">>]};
        {ok, Raw} ->
            Ending = unless(binary:last(Raw) =:= $\n, unterminated_event_log),
            try
                Raw = unicode:characters_to_binary(Raw, utf8, utf8),
                Rows = [strict_json(Line) || Line <- binary:split(Raw, <<"\n">>, [global]), Line =/= <<>>],
                true = lists:all(fun(#{<<"event">> := N, <<"data">> := _, <<"node">> := _}) -> is_binary(N);
                                    (_) -> false end, Rows),
                {Rows, Ending}
            catch _:_ -> {[], [<<"invalid_event_log">> | Ending]} end;
        _ -> {[], [<<"missing_event_log">>]}
    end.

skip_data(#{<<"event">> := Name, <<"data">> := [S, F, R]})
  when Name =:= <<"tc_user_skip">>; Name =:= <<"tc_auto_skip">> -> {S, F, R};
skip_data(#{<<"event">> := <<"tc_done">>, <<"data">> := [S, F, [Kind, R]]})
  when Kind =:= <<"skipped">>; Kind =:= <<"auto_skipped">> -> {S, F, R};
skip_data(_) -> false.

counted_skip(#{<<"event">> := <<"tc_auto_skip">>}, Func) ->
    not lists:member(Func, [<<"end_per_suite">>, <<"end_per_group">>]);
counted_skip(_, Func) -> not callback(Func).

outcome_data(#{<<"event">> := Name, <<"data">> := [S, F, R]})
  when Name =:= <<"tc_done">>; Name =:= <<"tc_user_skip">>; Name =:= <<"tc_auto_skip">> -> {S, F, R};
outcome_data(_) -> {undefined, undefined, undefined}.
outcome(#{<<"event">> := N}) -> lists:member(N, [<<"tc_start">>, <<"tc_done">>, <<"tc_user_skip">>,
    <<"tc_auto_skip">>, <<"test_stats">>, <<"severe_error">>, <<"test_done">>]).
failed_event(#{<<"event">> := <<"severe_error">>}) -> true;
failed_event(#{<<"event">> := <<"tc_done">>, <<"data">> := [_, _, [Kind | _]]}) ->
    lists:member(Kind, [<<"failed">>, <<"framework_error">>, <<"error">>]);
failed_event(#{<<"event">> := <<"tc_done">>, <<"data">> := [<<"ct_framework">>, <<"error_in_suite">>, _]}) -> true;
failed_event(_) -> false.

event_shape_errors(Events) ->
    Known = [E || E <- Events, lists:member(maps:get(<<"event">>, E),
        [<<"tc_start">>, <<"tc_done">>, <<"tc_user_skip">>, <<"tc_auto_skip">>, <<"test_stats">>])],
    unless(lists:all(fun valid_outcome/1, Known), malformed_or_unknown_ct_outcome) ++
        unless(length([ok || #{<<"event">> := <<"start_info">>} <- Events]) =:= 1,
               incomplete_or_multiple_native_plans).

valid_outcome(#{<<"event">> := <<"tc_start">>, <<"data">> := [S, F]}) -> valid_function(S, F);
valid_outcome(#{<<"event">> := <<"tc_done">>, <<"data">> := [S, F, Result]}) ->
    valid_function(S, F) andalso case Result of
        <<"ok">> -> true;
        [Kind, _] -> lists:member(Kind, [<<"failed">>, <<"skipped">>, <<"auto_skipped">>, <<"framework_error">>]);
        _ -> false
    end;
valid_outcome(#{<<"event">> := N, <<"data">> := [S, F, _]})
  when N =:= <<"tc_user_skip">>; N =:= <<"tc_auto_skip">> -> valid_function(S, F);
valid_outcome(#{<<"event">> := <<"test_stats">>, <<"data">> := [P, F, [U, A]]}) ->
    lists:all(fun(N) -> is_integer(N) andalso N >= 0 end, [P, F, U, A]);
valid_outcome(_) -> false.

valid_function(Suite, Name) when is_binary(Suite), is_binary(Name) -> true;
valid_function(Suite, [Name, Group | _]) -> is_binary(Suite) andalso is_binary(Name) andalso is_binary(Group);
valid_function(_, _) -> false.

function([Name, Group | _]) -> {Name, Group};
function(Name) -> {Name, undefined}.
callback(Name) -> lists:member(Name, [<<"init_per_suite">>, <<"end_per_suite">>, <<"init_per_group">>,
    <<"end_per_group">>, <<"init_per_testcase">>, <<"end_per_testcase">>]).
counts({P, F, {U, A}}) when is_integer(P), P >= 0, is_integer(F), F >= 0,
                            is_integer(U), U >= 0, is_integer(A), A >= 0 -> [P, F, [U, A]];
counts(_) -> null.
count_errors(null) -> [<<"invalid_ct_result">>];
count_errors([P, F, [_U, _A]]) -> unless(P > 0, zero_passing_tests) ++ when_true(F > 0, failed_testcases).

%% Reconciliation accepts one finished full report per domain/configuration,
%% with a single immutable input epoch/session. It rechecks the evidence.
reconcile(Paths, ExpectedDomains, Output) ->
    Expected = [safe(D) || D <- ExpectedDomains],
    require(Expected =/= [] andalso length(Expected) =:= length(lists:usort(Expected)), invalid_expected_domains),
    Attempts = [read_report(P) || P <- Paths],
    ParseErrors = [maps:get(error, A) || A <- Attempts, maps:is_key(error, A)],
    Reports = [maps:get(report, A) || A <- Attempts, maps:is_key(report, A)],
    Errors0 = ParseErrors ++ when_true(length(Paths) =/= length(lists:usort(Paths)), duplicate_report_path),
    Errors1 = Errors0 ++ lists:append([safe_report_errors(R, Expected) || R <- Reports]),
    Epochs = lists:usort([get(epoch, R, null) || R <- Reports]),
    Sessions = lists:usort([get(session, R, null) || R <- Reports]),
    Errors2 = Errors1 ++ unless(length(Epochs) =:= 1, mixed_or_missing_identity_epochs) ++
        unless(case Sessions of [S] -> valid_session(S); _ -> false end, mixed_or_missing_sessions),
    Domains = [get(domain, R, null) || R <- Reports],
    Missing = [D || D <- Expected, not lists:member(D, Domains)],
    Duplicate = [D || D <- lists:usort(Domains), length([X || X <- Domains, X =:= D]) > 1],
    Errors = Errors2 ++ when_true(Missing =/= [], missing_domains) ++ when_true(Duplicate =/= [], duplicate_domains),
    Matrix = #{format => 3, type => <<"reconciliation">>, phase => <<"finished">>,
        finished => timestamp(), complete => Errors =:= [], errors => lists:usort(Errors),
        expected_domains => Expected, missing_domains => Missing, duplicate_domains => Duplicate,
        epochs => Epochs, sessions => Sessions, attempts => Attempts},
    case Output of undefined -> ok; _ -> ok = otp_ct_support:write_json(Output, Matrix) end,
    Matrix.

%% The entry point obtains this identity from the same live verifier used for
%% component runs, after checking retained evidence and before publication.
bind_current(Matrix, Identity0, Session0) ->
    Identity = safe(Identity0), Session = safe(Session0), Epoch = digest(Identity),
    Errors = maps:get(errors, Matrix) ++
        unless(maps:get(epochs, Matrix) =:= [Epoch], reports_do_not_match_current_identity) ++
        unless(valid_session(Session) andalso maps:get(sessions, Matrix) =:= [Session],
               reports_do_not_belong_to_current_session),
    Matrix#{complete => maps:get(complete, Matrix) andalso Errors =:= [],
            errors => lists:usort(Errors), current_identity => Identity,
            current_epoch => Epoch, current_session => Session, finished => timestamp()}.

read_report(Path) ->
    try
        {ok, Raw} = file:read_file(Path),
        Report = strict_json(Raw), true = is_map(Report),
        #{path => safe(Path), sha256 => digest_bytes(Raw), report => Report}
    catch Class:Reason -> #{path => safe(Path), error => term_text({invalid_report, Class, Reason})} end.

report_errors(R, Expected) ->
    Identity = get(identity, R, #{}),
    Kind = get(type, R, undefined),
    Domain = get(domain, R, undefined),
    Basic = unless(get(format, R, undefined) =:= 3, invalid_report_format) ++
        unless(lists:member(Kind, [<<"ct">>, <<"supplemental-tool">>]), invalid_report_type) ++
        unless((Kind =:= <<"supplemental-tool">> andalso Domain =:= <<"yielding-c-fun">>) orelse
               (Kind =:= <<"ct">> andalso Domain =/= <<"yielding-c-fun">>), domain_report_type_mismatch) ++
        unless(get(phase, R, undefined) =:= <<"finished">> andalso valid_timestamp(get(finished, R, undefined)), unfinished_report) ++
        unless(get(profile, R, undefined) =:= <<"full">>, suite_report_cannot_complete_full_run) ++
        unless(lists:member(get(domain, R, undefined), Expected), unexpected_domain) ++
        unless(is_map(Identity) andalso map_size(Identity) > 0 andalso get(epoch, R, undefined) =:= digest(Identity), invalid_epoch) ++
        unless(get(identity_at_finish, R, undefined) =:= Identity andalso
               get(inputs_changed_during_run, R, undefined) =:= false, unverified_final_identity) ++
        unless(get(status, R, undefined) =:= <<"passed">> andalso get(errors, R, undefined) =:= [], nonpassing_report) ++
        identity_errors(Identity),
    case Kind of
        <<"ct">> -> Basic ++
            unless(get(events_complete, R, false) andalso get(statistics_match, R, false) andalso
                   get(skip_count_match, R, false), incomplete_ct_evidence) ++
            unless(valid_count_list(get(raw_counts, R, null)), invalid_ct_counts) ++
            unless(valid_native_plan(get(native_plan, R, null)), empty_or_malformed_native_plan) ++
            unless(get(native_plan_sha256, R, undefined) =:= digest(get(native_plan, R, null)), invalid_native_plan_hash) ++
            unless(get(failed_events, R, undefined) =:= [] andalso
                   get(prerequisite_gaps, R, undefined) =:= [], unresolved_ct_failures_or_prerequisites) ++
            selection_report_errors(R) ++ preparation_errors(R) ++ event_report_errors(R) ++
            native_execution_errors(R);
        <<"supplemental-tool">> -> Basic ++ tool_report_errors(R);
        _ -> Basic
    end.

preparation_errors(R) ->
    Receipt = get(preparation, R, #{}),
    Prepared = verified_json_receipt(Receipt),
    Input = get(input_identity, R, #{}),
    Input = get(input_identity, Prepared, undefined),
    InputReceipt = verified_json_receipt(Input),
    OriginalReceipt = get(original_inventory, Prepared, #{}),
    Originals = verified_json_receipt(OriginalReceipt),
    ClosureKeys = [stage_input_inventory, retained_input_inventory, source_generated_inventory],
    _ = [begin Body = verified_json_receipt(get(K, Prepared, #{})),
               require(is_map(Body), invalid_preparation_closure_receipt) end || K <- ClosureKeys],
    Stage = get(stage_dir, Prepared, undefined),
    Declared = [suite_atom(S) || S <- get(suites, Prepared, [])],
    Inventory = suite_inventory(#{staged_suite_inventory => get(staged_suite_inventory, Prepared, #{} )},
                                 Stage, Declared),
    SourceIdentity = get(source, get(identity, R, #{}), #{}),
    Binding = get(domain, Prepared, undefined) =:= get(domain, R, undefined) andalso
        get(profile, Prepared, undefined) =:= <<"full">> andalso
        get(platform, Prepared, null) =:= safe(report_platform(R)) andalso
        get(target, Prepared, null) =:= get(host_triple, get(sdk, get(identity, R, #{}), #{}), undefined) andalso
        get(source_commit, Prepared, undefined) =:= get(source_commit, SourceIdentity, null) andalso
        file_identity(get(manifest, Prepared, #{})) andalso file_identity(get(source_archive, Prepared, #{})) andalso
        get(sha256, get(manifest, Prepared, #{}), undefined) =:= get(manifest, SourceIdentity, null) andalso
        get(preparation_contract, Prepared, null) =:= <<"original-make-inputs-v2">> andalso
        get(stage_dir, R, null) =:= Stage andalso get(staged_suite_inventory, R, null) =:= Inventory andalso
        get(staged_suite_inventory_sha256, R, null) =:= digest(Inventory) andalso
        get(staged_suite_inventory_sha256, get(selection, R, #{}), null) =:= digest(Inventory) andalso
        get(selected_suites, get(selection, R, #{}), []) =:=
            native_suite_projection(get(run, get(native_plan, R, #{}), []), Inventory, Stage) andalso
        lists:all(fun(K) -> get(K, InputReceipt, '$missing') =:= get(K, Prepared, '$missing') end,
                  [domain, profile, platform, target, source_commit, manifest, source_archive, original_inventory,
                   staged_suite_inventory | ClosureKeys]),
    Root = get(source_dir, Prepared, undefined),
    require(absolute_value(Root) andalso is_map(Originals) andalso map_size(Originals) > 0,
            invalid_original_source_receipt),
    Current = otp_ct_prepare:verify(Prepared),
    Integrity = get(source_integrity, R, #{}),
    unless(Binding, preparation_identity_mismatch) ++ full_native_plan_errors(R, Prepared) ++
        unless(get(status, Integrity, null) =:= <<"passed">> andalso
               get(scope, Integrity, null) =:= <<"prepared_execution_inputs">> andalso
               get(original_inputs_unchanged, Integrity, false) =:= true andalso
               get(checked_files, Integrity, 0) =:= map_size(Originals) andalso
               get(changed, Integrity, undefined) =:= [] andalso
               safe(Current) =:= Integrity, unverified_original_source_integrity).

%% Reuse the original CT parser to check the saved full Run/Skip, including
%% authored cases/groups. The only term inspected directly is our own overlay.
full_native_plan_errors(R, Prepared) ->
    [Original, Overlay] = get(spec_inputs, R, []),
    lists:foreach(fun(E) -> require(file_identity(E) andalso
        file_sha(get(path, E, null)) =:= get(sha256, E, null), changed_native_spec_input) end,
        [Original, Overlay]),
    Spec = get(spec, Prepared, get(original_spec, Prepared, null)),
    require(get(path, Original, null) =:= Spec, wrong_original_full_specification),
    Stage = unicode:characters_to_list(get(stage_dir, Prepared, null)),
    Excluded = exclusions(canonical_domain(get(domain, R, null)), report_platform(R)),
    ExpectedOverlay = case Excluded of [] -> [];
        _ -> [{skip_suites, Stage, Excluded, exclusion_reason()}] end,
    {ok, ExpectedOverlay} = file:consult(get(path, Overlay, null)),
    Paths = [unicode:characters_to_list(get(path, E, null)) || E <- [Original, Overlay]],
    [{_, Native}] = native_specs([Paths]),
    {Run, Skip} = ct_testspec:prepare_tests(Native, node()),
    Expected = safe(#{run => Run, skip => Skip}),
    unless(Expected =:= get(native_plan, R, null), full_native_specification_mismatch).

verified_json_receipt(Receipt) ->
    require(file_identity(Receipt), malformed_file_receipt),
    Path = get(path, Receipt, undefined),
    require(file_sha(Path) =:= get(sha256, Receipt, undefined), changed_file_receipt),
    {ok, Raw} = file:read_file(Path), strict_json(Raw).

tool_report_errors(R) ->
    Command = get(command, R, #{}), Log = get(log, Command, undefined),
    unless(get(exit_status, R, undefined) =:= 0 andalso get(exit_status, Command, undefined) =:= 0,
           failed_tool_result) ++
        unless(get(inputs_unchanged, R, false) =:= true andalso get(tools_unchanged, R, false) =:= true,
               unverified_tool_inputs) ++
        unless(absolute_value(Log) andalso sha_value(get(log_sha256, Command, null)) andalso
               file_sha(Log) =:= get(log_sha256, Command, undefined), missing_or_changed_tool_log) ++
        unless(file_identity(get(tool, R, #{})) andalso file_identity(get(compiler, R, #{})) andalso
               file_identity(get(bash, R, #{})) andalso sha_value(get(input_identity, R, null)),
               malformed_tool_receipts).

valid_timestamp(Value) when is_binary(Value), byte_size(Value) > 0 ->
    try is_integer(calendar:rfc3339_to_system_time(binary_to_list(Value))) catch _:_ -> false end;
valid_timestamp(_) -> false.

valid_session(Session) when is_map(Session) ->
    Id = get(id, Session, null),
    get(format, Session, null) =:= 1 andalso is_binary(Id) andalso byte_size(Id) =:= 32 andalso
        lists:all(fun(C) -> (C >= $0 andalso C =< $9) orelse (C >= $a andalso C =< $f) end, binary_to_list(Id)) andalso
        valid_timestamp(get(started, Session, null));
valid_session(_) -> false.

%% Validate recorded receipts without substituting the reconciliation host's
%% tools or filesystem for the selected candidate. The entry point separately
%% binds reports to the current explicitly selected identity and session.
identity_errors(I) ->
    Configuration = get(configuration, I, null),
    ConfigValid = case Configuration of
        [System, Arch, Flavor, Type] ->
            lists:member({System, Arch}, [{<<"Linux">>, <<"x86_64">>}, {<<"Linux">>, <<"aarch64">>},
                {<<"Darwin">>, <<"arm64">>}, {<<"Darwin">>, <<"x86_64">>}, {<<"Windows">>, <<"x86_64">>}]) andalso
                lists:member(Flavor, [<<"emu">>, <<"jit">>]) andalso
                lists:member(Type, [<<"Release">>, <<"Debug">>]);
        _ -> false
    end,
    Source = get(source, I, #{}), Adapter = get(adapter, Source, #{}),
    RequiredAdapters = [<<"otp_ct.escript">>, <<"otp_ct_support.erl">>, <<"otp_ct_prepare.erl">>,
        <<"otp_ct_evidence.erl">>, <<"otp_ct_yielding.erl">>, <<"otp_ct_event.erl">>],
    SourceValid = get(source_commit, Source, null) =:=
        <<"550d7b7898706c7822362c42e7b93120c1d1f29a">> andalso
        sha_value(get(manifest, Source, null)) andalso sha_value(get(yielding_input_registry, Source, null)) andalso
        hash_map(Adapter) andalso lists:all(fun(K) -> sha_value(get(K, Adapter, null)) end, RequiredAdapters),
    SDK = get(sdk, I, #{}),
    SDKValid = lists:all(fun(K) -> sha_value(get(K, SDK, null)) end,
        [selection_sha256, manifest_sha256, source_id, build_id, toolchain_id]) andalso
        safe_component(get(host_triple, SDK, null)),
    Candidate = get(candidate, I, #{}), Files = get(files, Candidate, #{}),
    CandidateValid = absolute_value(get(root, Candidate, null)) andalso sha_value(get(tree_sha256, Candidate, null)) andalso
        get(erts, Candidate, null) =:= <<"17.0">> andalso artifact_map(Files) andalso
        lists:all(fun(K) -> maps:is_key(K, Files) end, required_candidate_files(Configuration)) andalso
        case Configuration of [_, _, F, T] ->
            get(flavor, Candidate, null) =:= F andalso get(build_type, Candidate, null) =:= T;
            _ -> false end,
    Tools = get(tools, I, #{}),
    ToolsValid = is_map(Tools) andalso
        lists:all(fun(K) -> file_identity(get(K, Tools, null)) end, [make, cc, cxx, git, tar]) andalso
        lists:all(fun(V) -> V =:= null orelse file_identity(V) end, maps:values(Tools)),
    Make = get(configured_make, I, #{}),
    TargetMake = case get(host_triple, SDK, null) of
        Target when is_binary(Target) -> <<"make/", Target/binary, "/otp.mk">>;
        _ -> null
    end,
    MakeValid = is_map(Make) andalso lists:all(fun(K) -> sha_value(get(K, Make, null)) end,
        [<<"make/make_emakefile">>, <<"make/output.mk">>, TargetMake]),
    Runtime = get(runtime_configuration, I, #{}),
    RuntimeValid = positive(get(schedulers, Runtime, null)) andalso
        nonnegative(get(dirty_cpu_schedulers, Runtime, null)) andalso positive(get(dirty_io_schedulers, Runtime, null)),
    unless(ConfigValid, invalid_recorded_configuration) ++ unless(SourceValid, invalid_recorded_source_identity) ++
        unless(SDKValid, invalid_recorded_sdk_identity) ++ unless(CandidateValid, invalid_recorded_candidate_identity) ++
        unless(ToolsValid, invalid_recorded_tool_identity) ++ unless(MakeValid, invalid_recorded_make_identity) ++
        unless(RuntimeValid, invalid_recorded_runtime_configuration) ++
        unless(is_map(get(inputs, I, null)), invalid_recorded_input_identity).

required_candidate_files([<<"Windows">>, _, _, Type]) ->
    Beam = case Type of <<"Debug">> -> <<"beam.debug.smp.dll">>; _ -> <<"beam.smp.dll">> end,
    [<<"bin/erl.exe">>, <<"bin/erlc.exe">>, <<"bin/escript.exe">>,
     <<"erts-17.0/bin/", Beam/binary>>, <<"erts-17.0/bin/erlexec.dll">>, <<"erts-17.0/bin/epmd.exe">>];
required_candidate_files([System, _, _, Type]) when System =:= <<"Linux">>; System =:= <<"Darwin">> ->
    [<<"bin/erl">>, <<"bin/erlc">>, <<"bin/escript">>, <<"erts-17.0/bin/beam.smp">>,
     <<"erts-17.0/bin/erl_child_setup">>, <<"erts-17.0/bin/epmd">>] ++
        case Type of <<"Debug">> -> [<<"erts-17.0/bin/erl_child_setup.debug">>]; _ -> [] end;
required_candidate_files(_) -> [<<"invalid-platform-artifact">>].

hash_map(Map) when is_map(Map), map_size(Map) > 0 -> lists:all(fun sha_value/1, maps:values(Map));
hash_map(_) -> false.
artifact_map(Map) when is_map(Map), map_size(Map) > 0 ->
    lists:all(fun({K, V}) -> relative_value(K) andalso
        lists:member(get(kind, V, null), [<<"regular">>, <<"symlink">>]) andalso
        nonnegative(get(mode, V, null)) andalso get(mode, V, 512) =< 8#777 andalso
        sha_value(get(sha256, V, null)) end, maps:to_list(Map));
artifact_map(_) -> false.
file_identity(Map) -> absolute_value(get(path, Map, null)) andalso sha_value(get(sha256, Map, null)).
sha_value(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun(C) -> (C >= $0 andalso C =< $9) orelse (C >= $a andalso C =< $f) end, binary_to_list(Value));
sha_value(_) -> false.
absolute_value(Value) when is_binary(Value), byte_size(Value) > 0 ->
    Portable = binary:replace(Value, <<"\\">>, <<"/">>, [global]),
    Rooted = case Portable of <<"/", _/binary>> -> true;
        <<Drive, $:, $/, _/binary>> when (Drive >= $A andalso Drive =< $Z) orelse
                                         (Drive >= $a andalso Drive =< $z) -> true;
        _ -> false end,
    Rooted andalso not lists:member(<<"..">>, binary:split(Portable, <<"/">>, [global]));
absolute_value(_) -> false.
relative_value(Value) when is_binary(Value), byte_size(Value) > 0 ->
    Portable = binary:replace(Value, <<"\\">>, <<"/">>, [global]),
    not absolute_value(Value) andalso binary:match(Portable, <<":">>) =:= nomatch andalso
        not lists:member(<<"..">>, binary:split(Portable, <<"/">>, [global]));
relative_value(_) -> false.
safe_component(Value) when is_binary(Value), byte_size(Value) > 0 ->
    Value =/= <<".">> andalso Value =/= <<"..">> andalso
        lists:all(fun(C) -> C > 32 andalso C =/= $/ andalso C =/= $\\ andalso C =/= $: end, binary_to_list(Value));
safe_component(_) -> false.
positive(N) -> is_integer(N) andalso N > 0.
nonnegative(N) -> is_integer(N) andalso N >= 0.

safe_report_errors(R, Expected) ->
    try report_errors(R, Expected)
    catch _:_ -> [<<"malformed_report_evidence">>] end.

selection_report_errors(R) ->
    Selection = get(selection, R, #{}),
    Suites = get(selected_suites, Selection, []),
    Domain = canonical_domain(get(domain, R, <<"invalid">>)),
    unless(get(domain, Selection, undefined) =:= get(domain, R, undefined) andalso
           get(profile, Selection, undefined) =:= <<"full">> andalso
           get(lifecycle, Selection, undefined) =:= <<"canonical">> andalso
           is_list(Suites) andalso Suites =/= [] andalso
           get(platform, Selection, undefined) =:= safe(report_platform(R)) andalso
           get(excluded_suites, Selection, undefined) =:= safe(exclusions(Domain, report_platform(R))),
           invalid_full_selection_evidence).

event_report_errors(R) ->
    case get(event_file, R, undefined) of
        Path when is_binary(Path) ->
            {Events, Errors} = read_events(Path),
            Stats = [D || #{<<"event">> := <<"test_stats">>, <<"data">> := D} <- Events],
            Done = length([ok || #{<<"event">> := <<"test_done">>} <- Events]),
            RawSkips = [E || E <- Events, skip_data(E) =/= false],
            Skips = get(skips, R, []),
            Counted = length([ok || S <- Skips, get(counted, S, false) =:= true]),
            SkipCount = case get(raw_counts, R, null) of [_, _, [U, A]] -> U + A; _ -> -1 end,
            SkipRowsMatch = RawSkips =:= [get(raw, S, null) || S <- Skips],
            Apps = report_applicability_rules(R, Skips),
            Resolved = lists:all(fun(S) ->
                lists:member(get(classification, S, null), [<<"not-applicable">>, <<"excluded-by-request">>])
                andalso is_boolean(get(counted, S, null)) andalso
                counted_skip(get(raw, S, #{}), element(1, function(element(2, outcome_data(get(raw, S, #{}))))))
                    =:= get(counted, S, null) andalso resolved_skip(S, R, Events, Apps)
            end, Skips),
            {_, OrderErrors} = ordering(Events, #{profile=>full,
                domain=>canonical_domain(get(domain, R, <<"invalid">>)),lifecycle=>canonical}),
            Errors ++ event_shape_errors(Events) ++
                unless(get(event_sha256, R, undefined) =:= file_sha(Path), changed_event_evidence) ++
                unless(length(Events) =:= get(event_count, R, undefined), changed_event_count) ++
                unless(Done =:= 1, incomplete_raw_test_run) ++
                unless(Stats =/= [] andalso lists:last(Stats) =:= get(raw_counts, R, null), raw_statistics_mismatch) ++
                unless(SkipRowsMatch andalso Resolved andalso Counted =:= SkipCount, unresolved_raw_skip_evidence) ++
                unless(get(raw_outcomes, R, undefined) =:= [E || E <- Events, outcome(E)], raw_outcomes_mismatch) ++
                when_true(lists:any(fun failed_event/1, Events), failed_raw_events) ++ OrderErrors;
        _ -> [<<"missing_event_evidence_path">>]
    end.

native_execution_errors(R) ->
    Evidence = get(native_execution, R, #{}),
    Command = get(command, Evidence, #{}),
    Specs = get(spec_inputs, Evidence, []),
    lists:foreach(fun(E) -> require(file_identity(E) andalso
        file_sha(get(path, E, null)) =:= get(sha256, E, null), changed_native_execution_input) end,
        Specs ++ [get(program, Evidence, #{}), get(event_handler, Evidence, #{}),
                  get(totals, Evidence, #{}), get(initial_runtime, Evidence, #{}),
                  get(final_runtime, Evidence, #{}), get(command_receipt, Evidence, #{})]),
    require(Specs =/= [], missing_native_execution_specifications),
    ChildNode = binary_to_atom(get(node, Evidence, null)),
    Paths = [unicode:characters_to_list(get(path, E, null)) || E <- Specs],
    [{_, Native}] = native_specs([Paths], ChildNode),
    {Run, Skip} = ct_testspec:prepare_tests(Native, ChildNode),
    EventFile = unicode:characters_to_list(get(event_file, R, null)),
    {Result, Facts, Recomputed, Errors} = native_result(EventFile, Evidence),
    Installation = get(runtime_installation, R, #{}),
    Copy = get(copy, Installation, #{}), Changes = get(changes, Installation, #{}),
    Runtime = otp_ct_support:verify_runtime_receipts(get(receipt, Copy, #{}), get(receipt, Changes, #{})),
    unless(safe(#{run => Run, skip => Skip}) =:= get(native_plan, R, null),
           native_execution_selection_mismatch) ++ Errors ++ runtime_identity_errors(Facts, get(identity, R, #{})) ++
        unless(safe(Recomputed) =:= Evidence andalso counts(Result) =:= get(raw_counts, R, null),
               native_execution_result_mismatch) ++
        unless(maps:without([<<"execution_envelope">>], get(runtime_facts, R, #{})) =:= Facts,
               native_runtime_facts_mismatch) ++
        unless(get(runtime_copy, Evidence, null) =:= get(receipt, Copy, null) andalso
               get(runtime_prefix, Runtime, null) =:= get(runtime_prefix, Evidence, undefined) andalso
               get(producer_prefix, Runtime, null) =:= get(root, get(candidate, get(identity, R, #{}), #{}), undefined) andalso
               get(producer_tree_sha256, Runtime, null) =:= get(tree_sha256, get(candidate, get(identity, R, #{}), #{}), undefined),
               native_runtime_copy_mismatch) ++
        unless(get(requires_review, Runtime, true) =:= false, unresolved_runtime_installation_changes) ++
        unless(get(program, Command, null) =:= get(path, get(program, Evidence, #{}), undefined) andalso
               get(log_sha256, Command, null) =:= file_sha(get(log, Command, null)) andalso
               verified_json_receipt(get(command_receipt, Evidence, #{})) =:= Command,
               changed_native_command_evidence).

runtime_identity_errors(Facts, Identity) ->
    Candidate = get(candidate, Identity, #{}), Runtime = get(runtime_configuration, Identity, #{}),
    Configuration = get(configuration, Identity, []),
    ExpectedType = case get(build_type, Candidate, null) of <<"Debug">> -> <<"debug">>;
                                                         <<"Release">> -> <<"opt">>; _ -> null end,
    unless(length(Configuration) =:= 4 andalso get(system_name, Facts, null) =:= hd(Configuration) andalso
        get(emu_flavor, Facts, null) =:= get(flavor, Candidate, undefined) andalso
        get(emu_type, Facts, null) =:= ExpectedType andalso
        get(erts_version, Facts, null) =:= get(erts, Candidate, undefined) andalso
        lists:all(fun(K) -> get(K, Facts, null) =:= get(K, Runtime, undefined) end,
                  [schedulers, dirty_cpu_schedulers, dirty_io_schedulers]), native_controller_identity_mismatch).

resolved_skip(Row, Report, Events, Apps) ->
    Raw = get(raw, Row, #{}), {Suite, FuncSpec, Reason} = skip_data(Raw),
    {Func, Group} = function(FuncSpec),
    Index = get(event_index, Row, 0),
    Evidence = get(evidence, Row, #{}),
    Indexed = is_integer(Index) andalso Index > 0 andalso Index =< length(Events) andalso
              lists:nth(Index, Events) =:= Raw,
    Indexed andalso case {get(classification, Row, null), get(kind, Evidence, null)} of
        {<<"excluded-by-request">>, <<"user-exclusion">>} ->
            lists:member(Suite, safe(exclusions(canonical_domain(get(domain, Report, null)), report_platform(Report)))) andalso
                Reason =:= safe(exclusion_reason());
        {<<"not-applicable">>, <<"native-spec-skip">>} ->
            Entry = get(entry, Evidence, null),
            lists:member(Entry, get(skip, get(native_plan, Report, #{}), [])) andalso
                native_skip_matches(Entry, Suite, Func, Group, Reason);
        {<<"not-applicable">>, <<"applicability-rule">>} ->
            Rule = get(rule, Evidence, #{}),
            Propagated = [{Rule, propagated(Events, Rule)}],
            lists:member(Rule, Apps) andalso
                rule_location(Rule, Suite, Func, Group, Index, Propagated) andalso
                reason_matches(Rule, Reason) andalso predicate(get(predicate, Rule, #{}), get(runtime_facts, Report, #{}));
        _ -> false
    end.

report_applicability_rules(Report, Skips) ->
    Needed = lists:any(fun(S) -> get(kind, get(evidence, S, #{}), null) =:= <<"applicability-rule">> end, Skips),
    case Needed of
        false -> [];
        true ->
            Path = get(policy_manifest, Report, undefined),
            Identity = get(identity, Report, #{}),
            SourceIdentity = get(source, Identity, #{}),
            require(file_sha(Path) =:= get(manifest, SourceIdentity, undefined), changed_policy_manifest),
            {ok, Bytes} = file:read_file(Path), Manifest = strict_json(Bytes),
            Batches = maps:merge(get(batches, Manifest, #{}), get(supplemental_batches, Manifest, #{})),
            Batch = maps:get(get(domain, Report, undefined), Batches),
            verified_rules(get(applicability_rules, Batch, []), get(policy_source_root, Report, undefined))
    end.

canonical_domain(<<"emulator">>) -> emulator;
canonical_domain(<<"system">>) -> system;
canonical_domain(_) -> other.

valid_count_list([P, 0, [U, A]]) -> is_integer(P) andalso P > 0 andalso
    is_integer(U) andalso U >= 0 andalso is_integer(A) andalso A >= 0;
valid_count_list(_) -> false.

valid_native_plan(Plan) ->
    Run = get(run, Plan, []), Skip = get(skip, Plan, undefined),
    is_list(Run) andalso Run =/= [] andalso is_list(Skip) andalso
        lists:all(fun([Dir, Suites, Cases]) -> absolute_value(Dir) andalso
            (is_binary(Suites) orelse (is_list(Suites) andalso Suites =/= [])) andalso
            (Cases =:= <<"all">> orelse (is_list(Cases) andalso Cases =/= [])); (_) -> false end, Run) andalso
        lists:all(fun([Dir, _, _]) -> absolute_value(Dir);
                     ([Dir, _, _, _]) -> absolute_value(Dir); (_) -> false end, Skip).

strict_json(Raw) ->
    Push = fun(K, V, Acc) -> require(not lists:keymember(K, 1, Acc), duplicate_json_key), [{K, V} | Acc] end,
    {Value, ok, Rest} = json:decode(Raw, ok, #{object_push => Push}),
    require(string:trim(Rest) =:= <<>>, trailing_json_data), Value.

native_specs(Files) ->
    %% Upstream ts:run also retains user-specific terms in original specs.
    case ct_testspec:collect_tests_from_file(Files, true) of
        Specs when is_list(Specs), Specs =/= [] -> Specs;
        Error -> erlang:error({invalid_native_specification, Error})
    end.
native_specs(Files, Node) ->
    case ct_testspec:collect_tests_from_file(Files, [Node], true) of
        Specs when is_list(Specs), Specs =/= [] -> Specs;
        Error -> erlang:error({invalid_native_specification, Error})
    end.
native_terms(Terms) ->
    case ct_testspec:collect_tests_from_list(Terms, false) of
        {error, Reason} -> erlang:error({invalid_native_selection, Reason});
        Native -> Native
    end.
write_terms(Path, Terms) ->
    ok = filelib:ensure_dir(Path),
    require(not filelib:is_file(Path), existing_selection_spec),
    ok = file:write_file(Path, [io_lib:format("~tp.~n", [T]) || T <- Terms]).
selectors(Key, Ctx, Requirement) ->
    case maps:find(Key, Ctx) of
        error when Requirement =:= optional -> all;
        error -> erlang:error({invalid_selection, missing_suite});
        {ok, A} when is_atom(A), A =/= all -> [A];
        {ok, List} when is_list(List), List =/= [] ->
            require(lists:all(fun(A) -> is_atom(A) andalso A =/= all end, List) andalso
                    length(List) =:= length(lists:usort(List)), invalid_or_duplicate_selector), List;
        _ -> erlang:error({invalid_selection, empty_or_invalid_selector})
    end.
optional(_, all) -> [];
optional(K, Value) -> [{K, Value}].
exclusions(emulator, linux) -> [mtx_SUITE];
exclusions(system, linux) -> [ethread_SUITE, erl_print_SUITE];
exclusions(_, _) -> [].
private_suites(emulator) -> [mtx_SUITE];
private_suites(system) -> [ethread_SUITE, erl_print_SUITE];
private_suites(_) -> [].
context_platform(Ctx) ->
    case maps:get(platform, Ctx, os:type()) of
        {unix, linux} -> linux; {unix, darwin} -> darwin; {win32, _} -> win32;
        linux -> linux; darwin -> darwin; win32 -> win32;
        Other -> erlang:error({unsupported_test_platform, Other})
    end.
report_platform(Report) ->
    case get(configuration, get(identity, Report, #{}), []) of
        [<<"Linux">> | _] -> linux;
        [<<"Darwin">> | _] -> darwin;
        [<<"Windows">> | _] -> win32;
        _ -> unknown
    end.
exclusion_reason() -> "Excluded by selected Erlang/OTP test scope: private VM integration".
suite_atom(#{<<"module">> := S}) -> suite_atom(S);
suite_atom(S) when is_atom(S) -> S;
suite_atom(S) when is_binary(S) -> binary_to_atom(S);
suite_atom(S) when is_list(S) -> list_to_atom(S).
absolute(Path) ->
    P = case is_binary(Path) of true -> unicode:characters_to_list(Path); false -> Path end,
    require(is_list(P) andalso P =/= [] andalso filename:pathtype(P) =:= absolute, relative_or_missing_path), P.
work(Ctx) -> absolute(maps:get(work, Ctx, maps:get(work_dir, Ctx, maps:get(work_root, Ctx, "")))).
get(Key, Map, Default) when is_atom(Key), is_map(Map) -> maps:get(Key, Map, maps:get(atom_to_binary(Key), Map, Default));
get(Key, Map, Default) when is_binary(Key), is_map(Map) ->
    case maps:find(Key, Map) of {ok, Value} -> Value; error ->
        try maps:get(binary_to_existing_atom(Key), Map, Default) catch error:badarg -> Default end end;
get(_, _, Default) -> Default.
optional_equal(undefined, _) -> true;
optional_equal(A, B) -> A =:= B.
optional_member(undefined, _) -> true;
optional_member(Values, Value) when is_list(Values) -> lists:member(Value, Values);
optional_member(_, _) -> false.
stable_unique(Values) -> lists:reverse(lists:foldl(fun(V, A) ->
    case lists:member(V, A) of true -> A; false -> [V | A] end end, [], Values)).
safe(Term) -> otp_ct_support:json(Term).
digest(Term) -> otp_ct_support:hash(Term).
digest_bytes(Bytes) -> binary:encode_hex(crypto:hash(sha256, Bytes), lowercase).
file_sha(Path) -> case file:read_file(Path) of {ok, Bytes} -> digest_bytes(Bytes); _ -> null end.
term_text(Term) -> iolist_to_binary(io_lib:format("~tp", [Term])).
timestamp() -> list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second), [{unit, second}, {offset, "Z"}])).
require(true, _) -> ok;
require(false, Reason) -> erlang:error({invalid_selection_or_evidence, Reason}).
when_true(true, Reason) -> [safe(Reason)];
when_true(false, _) -> [].
unless(Condition, Reason) -> when_true(not Condition, Reason).
