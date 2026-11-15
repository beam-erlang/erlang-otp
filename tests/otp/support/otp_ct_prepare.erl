%% SPDX-License-Identifier: Apache-2.0
%% Original OTP preparation for one explicitly selected installed candidate.
%% Make, ts and Common Test retain ownership of their recipe semantics.
-module(otp_ct_prepare).
-export([prepare/1, verify/1]).
-include_lib("kernel/include/file.hrl").

prepare(Ctx) ->
    Platform = maps:get(platform, Ctx, otp_ct_support:platform()),
    Target = maps:get(target, Ctx, undefined),
    Architecture = maps:get(architecture, Ctx, otp_ct_support:architecture()),
    Product = absolute(maps:get(source_root, Ctx)),
    Candidate = absolute(maps:get(candidate_prefix, Ctx)),
    Candidate = filename:absname(code:root_dir()),
    Work = absolute(maps:get(work_root, Ctx)),
    Domain = string_value(maps:get(domain, Ctx)),
    Profile = string_value(maps:get(profile, Ctx, "full")),
    case Profile of
        "full" ->
            true = lists:all(fun(K) -> maps:get(K, Ctx, undefined) =:= undefined end,
                             [suite, group, testcase]);
        "suite" -> ok;
        _ -> error({unsupported_profile, Profile})
    end,
    ManifestPath = filename:join(Product, "tests/otp/manifest.json"),
    {ok, Bytes} = file:read_file(ManifestPath),
    Manifest = json:decode(Bytes),
    Pin = maps:get(<<"source_commit">>, Manifest),
    Pin = pin(),
    {ok, ProductPin} = file:read_file(filename:join(Product, "UPSTREAM_COMMIT")),
    Pin = unicode:characters_to_binary(string:trim(string_value(ProductPin))),
    Batches = maps:merge(maps:get(<<"batches">>, Manifest),
                         maps:get(<<"supplemental_batches">>, Manifest, #{})),
    Batch = maps:get(bin(Domain), Batches),
    Suites = [string_value(S) || S <- maps:get(<<"suites">>, Batch)],
    Variants = maps:get(<<"variants">>, Batch, []),
    Declared = lists:usort(Suites ++ [string_value(maps:get(<<"module">>, V)) || V <- Variants] ++
                           [string_value(S) || S <- maps:get(<<"generated_suites">>, Batch, [])]),
    Selected = selected_suites(Ctx, Profile, Declared),
    PreparationSuites = preparation_suites(Domain, Profile, Selected),
    SpecName = spec_name(Domain, Profile, Batch),
    SourceDir = safe_relative(string_value(maps:get(<<"source_dir">>, Batch))),
    SpecRelative = safe_relative(SourceDir ++ "/" ++ SpecName),
    true = lists:member(bin(SpecRelative), maps:get(<<"specs">>, Batch)),
    Base = #{domain => bin(Domain), profile => bin(Profile),
             platform => Platform, target => Target, architecture => Architecture,
             system => otp_ct_support:system_name(),
             source_commit => Pin, manifest => identity(ManifestPath),
             original_spec_name => bin(SpecName), declared_suites => Declared,
             suites => Declared, source_spec => bin(SpecRelative),
             batch => Batch, preparation_suites => PreparationSuites,
             declared_specs => maps:get(<<"specs">>, Batch),
             selected_suites => Selected, variants => Variants,
             excluded_private_suites => case Platform of linux -> private_suites(Domain); _ -> [] end,
             source_root => Product, work_root => Work,
             candidate_prefix => Candidate},
    case prerequisite(Ctx, Domain, Profile, Batch, PreparationSuites, Candidate) of
        ok -> prepare_original(Ctx, Manifest, Batch, Base, SpecName);
        {blocked, Reason} ->
            Base#{status => blocked, classification => prerequisite_gap, reason => Reason}
    end.

prepare_original(Ctx, Manifest, Batch, Base, SpecName) ->
    Work = maps:get(work_root, Base),
    Source = filename:join(Work, "source"),
    Release = filename:join(Work, "tests"),
    fresh_directory(Source),
    fresh_directory(Release),
    Tools = maps:get(tools, Ctx),
    Archive = filename:join(Work, "otp-inputs.tar"),
    {error, enoent} = file:read_link_info(Archive),
    ArchiveCommand = otp_ct_support:command(Ctx, maps:get(git, Tools),
        ["-C", absolute(maps:get(reference_git, Ctx)), "archive", "--format=tar",
         "--output=" ++ Archive, string_value(pin())], Work, "archive-otp"),
    ArchiveIdentity = identity(Archive),
    ExtractCommand = otp_ct_support:command(Ctx, maps:get(tar, Tools),
        ["-xf", Archive, "-C", Source], Work, "extract-otp"),
    Originals = inventory(Source),
    InventoryPath = filename:join(Work, "source-inputs.json"),
    ok = otp_ct_support:write_json(InventoryPath, Originals),
    Verified = verify_manifest(Manifest, maps:get(source_root, Base), Source),
    Configured = absolute(maps:get(configured_source, Ctx)),
    Target = string_value(maps:get(target, Ctx)),
    Generated = ["make/make_emakefile", "make/output.mk", "make/" ++ Target ++ "/otp.mk"] ++
        case maps:get(domain, Base) of <<"wx">> -> ["lib/wx/config.mk"]; _ -> [] end,
    GeneratedEvidence = [copy_generated(Configured, Source, P) || P <- Generated],
    Opcode = filename:join([code:lib_dir(compiler), "src", "beam_opcodes.hrl"]),
    OpcodeTarget = filename:join(Source, "lib/compiler/src/beam_opcodes.hrl"),
    ok = otp_ct_support:copy(Opcode, OpcodeTarget),
    MakeArgs = ["release_tests_spec", "ERL_TOP=" ++ Source, "TARGET=" ++ Target,
                "RELEASE_PATH=" ++ Release,
                "ERLC=" ++ shell_word(otp_ct_support:installed_command(maps:get(candidate_prefix, Base), erlc)) ++ " -W",
                "ERL=" ++ shell_word(otp_ct_support:installed_command(maps:get(candidate_prefix, Base), erl)) ++ " -boot start_clean",
                "ESCRIPT=" ++ shell_word(otp_ct_support:installed_command(maps:get(candidate_prefix, Base), escript))] ++
        case maps:get(platform, Base) of
            win32 -> ["SHELL=" ++ maps:get(bash, Tools)];
            _ -> []
        end,
    Make = maps:get(make, Tools),
    ServerCommand = otp_ct_support:command(Ctx, Make, MakeArgs,
        filename:join(Source, "lib/common_test/test_server"), "release-test-server"),
    DomainAssignments = case maps:get(domain, Base) of
        <<"ftp">> ->
            %% The original FTP release defaults omit its property suite/tree.
            %% Keep the declared scope by passing original Make variables; its
            %% own helper still generates every compiler option and Emakefile.
            Modules = [filename:basename(string_value(P), ".erl") ||
                          P <- maps:get(<<"compile_sources">>, Batch)],
            ["ftp_SUITE", "ftp_format_SUITE", "ftp_test_lib", "ftp_property_test_SUITE"] = Modules,
            ["MODULES=" ++ string:join(Modules, " "),
             "FTP_DATADIRS=ftp_SUITE_data property_test"];
        _ -> []
    end,
    DomainCommand = otp_ct_support:command(Ctx, Make, MakeArgs ++ DomainAssignments,
        filename:join(Source, string_value(maps:get(<<"source_dir">>, Batch))), "release-domain"),
    Stage = filename:join(Release, safe_relative(string_value(maps:get(<<"release_dir">>, Batch)))),
    Spec = filename:join(Stage, SpecName),
    true = filelib:is_regular(Spec),
    %% Capture the original Make outputs before any native preparation or CT
    %% compilation can add files. There is no project-owned suite generator.
    SuiteInventory = suite_outputs(Stage, Source, Batch, maps:get(declared_suites, Base)),
    Emakefile = emakefile_identity(Stage),
    Server = filename:join(Release, "test_server"),
    load_test_server(Server),
    InstallLog = filename:join(Work, "ts-install.log"),
    ok = in_directory(Server, fun() ->
        capture(InstallLog, fun() -> ts:install([{make_command, Make}]) end)
    end),
    VariablesPath = filename:join(Server, "variables"),
    {ok, Variables} = file:consult(VariablesPath),
    DataDirs = data_directories(Stage, Batch, maps:get(preparation_suites, Base)),
    Native = [prepare_data(Server, Dir, Work) || Dir <- DataDirs],
    RetainedReceipt = write_entries(Work, "retained-inputs.json",
        retained_entries(Manifest, maps:get(source_root, Base))),
    StageReceipt = write_entries(Work, "stage-inputs.json",
        maps:merge(path_entries(Stage, false), server_entries(Server))),
    GeneratedSource = maps:filter(fun(Relative, _) ->
        not maps:is_key(Relative, Originals) andalso filename:extension(string_value(Relative)) =/= ".beam"
    end, inventory(Source)),
    GeneratedReceipt = write_entries(Work, "source-generated-inputs.json",
        absolute_entries(Source, GeneratedSource)),
    Prepared = Base#{status => prepared, source_dir => Source, original_source => Source,
        preparation_contract => <<"original-make-inputs-v2">>,
        stage_root => Release, stage_dir => Stage, server_dir => Server,
        original_spec => Spec, spec => Spec, variables => Variables,
        variables_file => identity(VariablesPath),
        original_inventory => identity(InventoryPath),
        original_input_count => map_size(Originals),
        source_archive => ArchiveIdentity,
        verified_manifest_files => Verified,
        generated_make_inputs => GeneratedEvidence,
        installed_opcode_header => identity(Opcode),
        staged_opcode_header => identity(OpcodeTarget),
        commands => [ArchiveCommand, ExtractCommand, ServerCommand, DomainCommand],
        domain_make_assignments => DomainAssignments,
        native_install => identity(InstallLog), native => Native,
        staged_suite_inventory => SuiteInventory, suite_inventory => SuiteInventory,
        emakefile => Emakefile, stage_input_inventory => StageReceipt,
        retained_input_inventory => RetainedReceipt, source_generated_inventory => GeneratedReceipt,
        staged_inventory => inventory(Stage),
        tools => maps:from_list([{K, identity(P)} || {K, P} <- maps:to_list(Tools), P =/= undefined]),
        inputs => maps:get(inputs, Ctx, #{})},
    ReceiptPath = filename:join(Work, "preparation-inputs.json"),
    ok = otp_ct_support:write_json(ReceiptPath, preparation_identity(Prepared)),
    Sealed = Prepared#{input_identity => identity(ReceiptPath)},
    #{status := passed} = Integrity = verify(Sealed),
    Sealed#{original_integrity => Integrity}.

%% This receipt is specific to the selected preparation. The common execution
%% epoch is owned by the caller and must not absorb this domain-specific value.
preparation_identity(Prepared) ->
    maps:with([atom_to_binary(K) || K <-
        [domain, profile, platform, target, architecture, system, source_commit, manifest, source_archive,
         preparation_contract, original_inventory, selected_suites, preparation_suites,
         generated_make_inputs, domain_make_assignments, installed_opcode_header, variables_file, native, tools, inputs,
         staged_suite_inventory, emakefile, stage_input_inventory,
         retained_input_inventory, source_generated_inventory]], otp_ct_support:json(Prepared)).

%% The caller repeats this after CT. Additional generated files are allowed;
%% every original file, link target, type and executable bit must be preserved.
verify(Prepared) ->
    Originals = read_inventory(value(original_inventory, Prepared)),
    Root = string_value(value(source_dir, Prepared)),
    Changed = [Relative || {Relative, Expected} <- maps:to_list(Originals),
        not same_entry(filename:join(Root, string_value(Relative)), Expected)],
    Staged = verify_entries(stage_input_inventory, Prepared),
    Retained = verify_entries(retained_input_inventory, Prepared),
    Generated = verify_entries(source_generated_inventory, Prepared),
    SuiteChanges = verify_suite_inventory(Prepared),
    ArtifactChanges = verify_artifacts(Prepared),
    ReceiptChanges = verify_preparation_receipt(Prepared),
    AllChanges = Changed ++ Staged ++ Retained ++ Generated ++ SuiteChanges ++ ArtifactChanges ++ ReceiptChanges,
    #{status => case AllChanges of [] -> passed; _ -> failed end,
      scope => case value(preparation_contract, Prepared, undefined) of
                   undefined -> original_sources_only; _ -> prepared_execution_inputs end,
      original_inputs_unchanged => Changed =:= [],
      checked_files => map_size(Originals), changed => Changed,
      changed_staged => lists:usort(Staged ++ SuiteChanges), changed_retained => Retained,
      changed_generated => Generated, changed_artifacts => ArtifactChanges,
      changed_receipts => ReceiptChanges}.

selected_suites(Ctx, Profile, Declared) ->
    case maps:get(suite, Ctx, undefined) of
        undefined when Profile =:= "suite" -> error(suite_requires_suite);
        undefined -> Declared;
        [] -> error(empty_suite_selection);
        Value ->
            Selected = suite_values(Value),
            true = Selected =/= [],
            true = lists:all(fun(S) -> lists:member(S, Declared) end, Selected),
            true = length(Selected) =:= length(lists:usort(Selected)),
            Selected
    end.

suite_values([First | _] = Values) when not is_integer(First) ->
    [string_value(V) || V <- Values];
suite_values(Value) -> [string_value(Value)].

preparation_suites("emulator", "suite", Selected) ->
    case lists:any(fun(S) -> S =:= "a_SUITE" orelse S =:= "z_SUITE" end, Selected) of
        true -> lists:usort(["a_SUITE", "z_SUITE" | Selected]);
        false -> Selected
    end;
preparation_suites(_, _, Selected) -> Selected.

spec_name(_Domain, Profile, Batch) when Profile =:= "full"; Profile =:= "suite" ->
    string_value(maps:get(<<"main_spec">>, Batch));
spec_name(_, Profile, _) -> error({unsupported_profile, Profile}).

prerequisite(Ctx, Domain, Profile, Batch, Selected, Candidate) ->
    case lifecycle_gate(Ctx, Domain, Profile) of
        ok ->
            Platform = maps:get(platform, Ctx, otp_ct_support:platform()),
            PrivateSelection = case Platform of linux -> explicit_suites(Ctx); _ -> Selected end,
            case lists:any(fun(S) -> lists:member(S, private_suites(Domain)) end, PrivateSelection) of
                true when Platform =:= linux ->
                    {blocked, <<"Selected suite is intentionally excluded from the agreed Linux test scope.">>};
                true ->
                    {blocked, <<"Selected suites need unavailable VM-private native support on this platform; no private SDK fixtures are provided.">>};
                false ->
                    case ei_gate(Batch, Selected, Candidate) of
                        ok -> host_gate(Ctx, Domain, Candidate);
                        Block -> Block
                    end
            end;
        Block -> Block
    end.

host_gate(Ctx, Domain, Candidate) ->
    Platform = maps:get(platform, Ctx, otp_ct_support:platform()),
    Target = maps:get(target, Ctx, undefined),
    Tools = maps:get(tools, Ctx, #{}),
    Configured = maps:get(configured_source, Ctx, undefined),
    Architecture = string_value(maps:get(architecture, Ctx, otp_ct_support:architecture())),
    case {Platform =:= otp_ct_support:platform() andalso Architecture =:= otp_ct_support:architecture(),
          lists:member(Platform, [linux, darwin, win32]),
          Target =/= undefined, Configured =/= undefined} of
        {true, true, true, true} ->
            TargetName = string_value(Target),
            true = filename:basename(TargetName) =:= TargetName andalso TargetName =/= "..",
            Required = [make, cc, cxx, git, tar] ++ case Platform of win32 -> [bash]; _ -> [] end,
            MissingTools = [K || K <- Required, not regular_tool(maps:get(K, Tools, undefined))],
            ConfigNames = ["make/make_emakefile", "make/output.mk", "make/" ++ TargetName ++ "/otp.mk"] ++
                case Domain of "wx" -> ["lib/wx/config.mk"]; _ -> [] end,
            MissingFiles = [filename:join(string_value(Configured), P) || P <- ConfigNames,
                not filelib:is_regular(filename:join(string_value(Configured), P))] ++
                [otp_ct_support:installed_command(Candidate, N) || N <- [erl, erlc, escript],
                 not filelib:is_regular(otp_ct_support:installed_command(Candidate, N))],
            case {MissingTools, MissingFiles} of
                {[], []} -> ok;
                _ -> {blocked, otp_ct_support:text({missing_original_host_capabilities,
                                                    MissingTools, MissingFiles})}
            end;
        _ -> {blocked, <<"Original preparation requires a matching native platform, explicit SDK target and configured original source.">>}
    end.

regular_tool(undefined) -> false;
regular_tool(Path) -> filelib:is_regular(Path).

lifecycle_gate(Ctx, Domain, _) when Domain =:= "ssl"; Domain =:= "ftp";
                                   Domain =:= "epmd"; Domain =:= "os_mon" ->
    try
        otp_ct_support:linux_envelope(Ctx),
        case Domain of
            "epmd" ->
                Config=otp_ct_support:owned_path(maps:get(source_root,Ctx),os:getenv("OTP_CT_LINUX_EPMD_CONFIG")),
                {ok,[{ssh_proxy_host,"otp-epmd-peer"}]}=file:consult(Config);
            _ -> ok
        end,
        ok
    catch _:_ ->
        {blocked, <<"Selected original setup requires a verified Linux process/network envelope and its owned services.">>}
    end;
lifecycle_gate(_, _, _) -> ok.

explicit_suites(Ctx) ->
    case maps:get(suite, Ctx, undefined) of undefined -> []; Value -> suite_values(Value) end.

ei_gate(Batch, Selected, Candidate) ->
    DataNames = selected_data_names(Batch, Selected),
    Recipes = maps:get(<<"native_recipes">>, Batch, []),
    SourceDir = string_value(maps:get(<<"source_dir">>, Batch)),
    HasSelectedData = lists:any(fun(Input) ->
        Path = string_value(maps:get(<<"path">>, Input)),
        lists:any(fun(Name) -> lists:prefix(SourceDir ++ "/" ++ Name ++ "/", Path) end,
                  DataNames)
    end, maps:get(<<"inputs">>, Batch)),
    NeedsEI = lists:any(fun(Recipe) ->
        Path = string_value(maps:get(<<"path">>, Recipe)),
        Dir = filename:basename(filename:dirname(Path)),
        Text = maps:get(<<"text">>, Recipe, <<>>),
        ((HasSelectedData andalso Dir =:= "all_SUITE_data") orelse lists:member(Dir, DataNames)) andalso
            binary:match(Text, <<"@erl_interface_mk_include@">>) =/= nomatch
    end, Recipes),
    case NeedsEI of
        false -> ok;
        true ->
            Path = filename:join([code:lib_dir(erl_interface), "src", "eidefs.mk"]),
            true = lists:prefix(Candidate ++ "/", filename:absname(Path)),
            case filelib:is_regular(Path) of
                true -> ok;
                false -> {blocked, <<"Original native preparation requires the installed public Erl_Interface src/eidefs.mk, which this candidate does not provide.">>}
            end
    end.

private_suites("emulator") -> ["mtx_SUITE"];
private_suites("system") -> ["ethread_SUITE", "erl_print_SUITE"];
private_suites(_) -> [].

selected_data_names(Batch, Selected) ->
    Variants = maps:get(<<"variants">>, Batch, []),
    lists:usort([original_suite(S, Variants) ++ "_data" || S <- Selected,
        not lists:member(S, ["mtx_SUITE", "ethread_SUITE", "erl_print_SUITE"])]).

original_suite(Suite, Variants) ->
    case [V || V <- Variants, string_value(maps:get(<<"module">>, V)) =:= Suite] of
        [] -> Suite;
        [Variant] -> filename:basename(string_value(maps:get(<<"source">>, Variant)), ".erl")
    end.

data_directories(Stage, Batch, Selected) ->
    Dirs = [filename:join(Stage, Name) || Name <- selected_data_names(Batch, Selected)],
    lists:filter(fun filelib:is_dir/1, Dirs).

prepare_data(Server, Dir, Work) ->
    %% Pass an exact path to the original wildcard API, not an unbounded glob.
    [Dir] = filelib:wildcard(Dir),
    Before = inventory(Dir),
    Log = filename:join(Work, "native-" ++ filename:basename(Dir) ++ ".log"),
    ok = in_directory(Server, fun() ->
        capture(Log, fun() -> ts:compile_datadirs("variables", Dir) end)
    end),
    #{data_dir => Dir, log => identity(Log), before => Before, after_preparation => inventory(Dir)}.

load_test_server(Server) ->
    true = code:add_patha(Server),
    lists:foreach(fun(Module) ->
        {module, Module} = code:load_abs(filename:join(Server, atom_to_list(Module)))
    end, [ts, ts_run, ts_lib, ts_make, ts_erl_config, ts_autoconf_win32,
          ts_install, ts_install_cth, ts_benchmark]).

suite_outputs(Stage, Source, Batch, Expected0) ->
    Expected = lists:sort(Expected0),
    Actual = suite_names(Stage),
    case Actual =:= Expected of
        true -> ok;
        false -> error({released_suite_inventory_mismatch,
                        #{missing => Expected -- Actual, unexpected => Actual -- Expected}})
    end,
    Terms = emakefile_terms(Stage),
    Variants = maps:get(<<"variants">>, Batch, []),
    Generated = maps:get(<<"generated_suites">>, Batch, []),
    DomainDir = string_value(maps:get(<<"source_dir">>, Batch)),
    maps:from_list([begin
        Path = filename:join(Stage, Name ++ ".erl"),
        {ok, #file_info{type = regular}} = file:read_link_info(Path),
        Hash = otp_ct_support:sha(Path),
        Options = suite_options(Name, Terms),
        Provenance = case [V || V <- Variants, maps:get(<<"module">>, V) =:= bin(Name)] of
            [Variant] ->
                %% The wrapper is an output of the original source-tree Make
                %% target. Compare its released copy; do not repeat its sed or
                %% Core-to-Erlang generation in project code.
                Original = string_value(maps:get(<<"source">>, Variant)),
                OriginalIdentity = identity(filename:join(Source, Original)),
                MakeOutput = case filename:extension(Original) of
                    ".core" ->
                        %% Original Make removes its temporary dummy .erl after
                        %% release. The real compiler input is the copied Core.
                        Core = identity(filename:join(Stage, Name ++ ".core")),
                        true = maps:get(sha256, Core) =:= maps:get(sha256, OriginalIdentity),
                        #{dummy_source => identity(Path), core => Core};
                    ".erl" ->
                        Wrapper = filename:join([Source, DomainDir, Name ++ ".erl"]),
                        Hash = otp_ct_support:sha(Wrapper),
                        #{source_tree_wrapper => identity(Wrapper)}
                end,
                lists:foreach(fun(Flag) ->
                    true = lists:any(fun(O) -> is_atom(O) andalso atom_to_binary(O) =:= Flag end, Options)
                end, maps:get(<<"flags">>, Variant)),
                #{<<"origin">> => <<"variant">>, <<"make_output">> => MakeOutput,
                  <<"source">> => OriginalIdentity};
            [] ->
                case lists:member(bin(Name), Generated) of
                    true -> #{<<"origin">> => <<"generated">>,
                              <<"recipe">> => maps:get(<<"top_recipe">>, Batch)};
                    false -> authored_suite(Name, Path, Hash, Source, Batch)
                end
        end,
        {bin(Name), Provenance#{<<"path">> => bin(Path), <<"sha256">> => Hash,
                               <<"emakefile_options">> => Options}}
    end || Name <- Expected]).

authored_suite(Name, _Path, Hash, Source, Batch) ->
    [Original] = [P || P <- maps:get(<<"compile_sources">>, Batch),
                      filename:basename(string_value(P)) =:= Name ++ ".erl"],
    Identity = identity(filename:join(Source, string_value(Original))),
    Relation = case maps:get(sha256, Identity) =:= Hash of
        true -> identical_copy;
        false ->
            %% The original Diameter release target applies release.sed to
            %% public header includes. Its pinned Make/recipe owns that change.
            <<"lib/diameter/test">> = maps:get(<<"source_dir">>, Batch),
            original_release_transform
    end,
    #{<<"origin">> => <<"authored">>, <<"source">> => Identity,
      <<"copy_relation">> => Relation}.

suite_names(Stage) ->
    {ok, Names} = file:list_dir(Stage),
    lists:sort([filename:basename(N, ".erl") || N <- Names, lists:suffix("_SUITE.erl", N)]).

emakefile_terms(Stage) ->
    case file:consult(filename:join(Stage, "Emakefile")) of
        {ok, Terms} -> Terms;
        {error, enoent} -> [];
        Error -> error({invalid_original_emakefile, Error})
    end.

suite_options(Name, Terms) ->
    Matches = [Opts || {Modules, Opts} <- Terms, is_list(Modules),
        lists:any(fun(M) -> is_atom(M) andalso atom_to_list(M) =:= Name end, Modules)],
    case Matches of [] -> []; [Options] -> Options; _ -> error({ambiguous_original_emakefile, Name}) end.

emakefile_identity(Stage) ->
    Path = filename:join(Stage, "Emakefile"),
    case filelib:is_regular(Path) of
        true -> (identity(Path))#{terms => emakefile_terms(Stage)};
        false -> null
    end.

retained_entries(Manifest, Product) ->
    Paths = [string_value(P) || P <- maps:keys(records(Manifest, #{})),
             filelib:is_file(filename:join(Product, string_value(P)))] ++
        ["tests/otp/manifest.json", "UPSTREAM_COMMIT", "OTP_VERSION", "otp_versions.table"],
    maps:from_list([{bin(filename:join(Product, P)), entry(filename:join(Product, P))}
                   || P <- lists:usort(Paths)]).

path_entries(Root, IncludeBeams) ->
    absolute_entries(Root, maps:filter(fun(P, _) ->
        IncludeBeams orelse filename:extension(string_value(P)) =/= ".beam"
    end, inventory(Root))).

absolute_entries(Root, Entries) ->
    maps:from_list([{bin(filename:join(Root, string_value(P))), E} || {P, E} <- maps:to_list(Entries)]).

server_entries(Server) ->
    maps:filter(fun(P, _) ->
        Name = filename:basename(string_value(P)),
        lists:member(filename:extension(Name), [".erl", ".hrl", ".beam", ".config"]) orelse
            lists:member(Name, ["configure", "config.guess", "config.sub", "install-sh",
                                "conf_vars.in", "conf_vars", "variables"])
    end, path_entries(Server, true)).

write_entries(Work, Name, Entries) ->
    Path = filename:join(Work, Name),
    ok = otp_ct_support:write_json(Path, Entries),
    identity(Path).

read_inventory(Identity) ->
    Path = string_value(value(path, Identity)),
    true = value(sha256, Identity) =:= otp_ct_support:sha(Path),
    {ok, Bytes} = file:read_file(Path),
    json:decode(Bytes).

verify_entries(Key, Prepared) ->
    case value(Key, Prepared, undefined) of
        undefined -> [];
        Receipt ->
            Entries = read_inventory(Receipt),
            [Path || {Path, Expected} <- maps:to_list(Entries),
                     not same_entry(string_value(Path), Expected)]
    end.

verify_suite_inventory(Prepared) ->
    case value(staged_suite_inventory, Prepared, undefined) of
        undefined -> [];
        Entries ->
            Stage = string_value(value(stage_dir, Prepared)),
            Expected = lists:sort([string_value(N) || N <- maps:keys(Entries)]),
            Actual = suite_names(Stage),
            NameChanges = [bin(N) || N <- (Expected -- Actual) ++ (Actual -- Expected)],
            NameChanges ++ [Name || {Name, E} <- maps:to_list(Entries),
                try otp_ct_support:sha(string_value(value(path, E))) =/= value(sha256, E)
                catch _:_ -> true end]
    end.

verify_artifacts(Prepared) ->
    Generated = value(generated_make_inputs, Prepared, []),
    Artifacts = lists:append([[value(input, E), value(staged, E)] || E <- Generated]) ++
        [value(K, Prepared) || K <- [installed_opcode_header, variables_file, source_archive],
                                value(K, Prepared, undefined) =/= undefined] ++
        maps:values(value(tools, Prepared, #{})),
    [value(path, E) || E <- Artifacts,
        try otp_ct_support:sha(string_value(value(path, E))) =/= value(sha256, E)
        catch _:_ -> true end].

verify_preparation_receipt(Prepared) ->
    case value(input_identity, Prepared, undefined) of
        undefined -> [];
        Receipt ->
            Actual = read_inventory(Receipt),
            case Actual =:= preparation_identity(Prepared) of
                true -> [];
                false -> [<<"preparation_receipt_mismatch">>]
            end
    end.

value(Key, Map) ->
    case maps:find(Key, Map) of {ok, V} -> V; error -> maps:get(atom_to_binary(Key), Map) end.
value(Key, Map, Default) ->
    case maps:find(Key, Map) of {ok, V} -> V; error -> maps:get(atom_to_binary(Key), Map, Default) end.

verify_manifest(Manifest, Product, Source) ->
    Records = records(Manifest, #{}),
    maps:foreach(fun(Relative, Record) ->
        Path = safe_relative(string_value(Relative)),
        Expected = maps:get(<<"sha256">>, Record),
        Expected = content_sha(filename:join(Source, Path)),
        verify_mode(filename:join(Source, Path), Record),
        case maps:find(<<"text">>, Record) of
            {ok, Text} ->
                TextHash = text_hash(Record),
                TextHash = binary:encode_hex(crypto:hash(sha256, Text), lowercase);
            error -> ok
        end,
        case file:read_link_info(filename:join(Product, Path)) of
            {error, enoent} -> ok;
            {ok, _} ->
                Expected = content_sha(filename:join(Product, Path)),
                verify_mode(filename:join(Product, Path), Record)
        end
    end, Records),
    map_size(Records).

%% Git identifies a symlink by its target text. Embedded recipe text is the
%% resolved file content and has its own original identity in the manifest.
text_hash(#{<<"resolved_recipe">> := Resolved}) -> maps:get(<<"sha256">>, Resolved);
text_hash(Record) -> maps:get(<<"sha256">>, Record).

verify_mode(Path, Record) ->
    {ok, #file_info{type = Type, mode = Mode}} = file:read_link_info(Path),
    case maps:get(<<"mode">>, Record) of
        <<"120000">> -> symlink = Type;
        <<"100755">> -> regular = Type, verify_execute_mode(Mode, true);
        <<"100644">> -> regular = Type, verify_execute_mode(Mode, false)
    end,
    ok.

verify_execute_mode(Mode, Expected) ->
    case os:type() of
        {win32, _} -> ok;
        _ -> true = ((Mode band 8#111) =/= 0) =:= Expected
    end.

records(Value, Acc0) when is_map(Value) ->
    Acc = case Value of
        #{<<"path">> := Path, <<"sha256">> := Hash} ->
            case maps:find(Path, Acc0) of
                {ok, #{<<"sha256">> := Other}} when Other =/= Hash ->
                    error({conflicting_manifest_identity, Path});
                _ -> Acc0#{Path => Value}
            end;
        _ -> Acc0
    end,
    lists:foldl(fun records/2, Acc, maps:values(Value));
records(Value, Acc) when is_list(Value) -> lists:foldl(fun records/2, Acc, Value);
records(_, Acc) -> Acc.

copy_generated(Configured, Source, Relative) ->
    From = filename:join(Configured, Relative),
    To = filename:join(Source, Relative),
    ok = otp_ct_support:copy(From, To),
    #{relative => bin(Relative), input => identity(From), staged => identity(To)}.

fresh_directory(Path) ->
    {error, enoent} = file:read_link_info(Path),
    ok = filelib:ensure_path(Path),
    {ok, []} = file:list_dir(Path).

inventory(Root) -> inventory(Root, Root, #{}).
inventory(Root, Dir, Acc) ->
    {ok, Names} = file:list_dir(Dir),
    lists:foldl(fun(Name, A) ->
        Path = filename:join(Dir, Name),
        {ok, #file_info{type = Type}} = file:read_link_info(Path),
        case Type of
            directory -> inventory(Root, Path, A);
            _ -> A#{bin(string:prefix(Path, Root ++ "/")) => entry(Path)}
        end
    end, Acc, lists:sort(Names)).

entry(Path) ->
    {ok, #file_info{type = Type, mode = Mode}} = file:read_link_info(Path),
    case Type of
        regular -> #{<<"type">> => <<"regular">>, <<"sha256">> => content_sha(Path),
                     <<"executable">> => (Mode band 8#111) =/= 0};
        symlink -> {ok, Target} = file:read_link(Path),
                   #{<<"type">> => <<"symlink">>, <<"target">> => bin(Target)};
        _ -> error({unsupported_input_type, Path, Type})
    end.

same_entry(Path, Expected) ->
    try entry(Path) =:= Expected catch _:_ -> false end.

content_sha(Path) ->
    case file:read_link(Path) of
        {ok, Target} -> binary:encode_hex(crypto:hash(sha256, bin(Target)), lowercase);
        {error, _} -> otp_ct_support:sha(Path)
    end.

identity(Path0) ->
    Path = absolute(Path0),
    {ok, #file_info{type = regular, size = Size}} = file:read_file_info(Path),
    #{path => Path, sha256 => otp_ct_support:sha(Path), bytes => Size}.

capture(Path, Fun) ->
    {ok, Device} = file:open(Path, [write, {encoding, utf8}]),
    Previous = group_leader(),
    true = group_leader(Device, self()),
    try Fun()
    after
        true = group_leader(Previous, self()),
        ok = file:close(Device)
    end.

in_directory(Dir, Fun) ->
    {ok, Previous} = file:get_cwd(),
    ok = file:set_cwd(Dir),
    try Fun() after ok = file:set_cwd(Previous) end.

safe_relative(Path) ->
    relative = filename:pathtype(Path),
    false = lists:member("..", filename:split(Path)),
    Path.

absolute(Path0) ->
    Path = string_value(Path0),
    absolute = filename:pathtype(Path),
    filename:absname(Path).

shell_word(Path0) ->
    Path = string_value(Path0),
    "\"" ++ lists:append([case C of
        $\" -> "\\\""; $$ -> "\\$"; $` -> "\\`"; $\\ -> "\\\\"; _ -> [C]
    end || C <- Path]) ++ "\"".

string_value(Value) when is_atom(Value) -> atom_to_list(Value);
string_value(Value) when is_binary(Value) -> unicode:characters_to_list(Value);
string_value(Value) when is_list(Value) -> Value.
bin(Value) -> unicode:characters_to_binary(Value).
pin() -> <<"550d7b7898706c7822362c42e7b93120c1d1f29a">>.
