%% SPDX-License-Identifier: Apache-2.0
-module(otp_build_driver).
-export([main/1]).

%% Runs only on the explicitly selected private OTP build host. Product
%% applications are outputs, never implicitly added to this host's code path.
main(["tools", Root, Out, HostRoot]) ->
    compiler_host(HostRoot),
    ok = filelib:ensure_dir(filename:join(Out, "placeholder")),
    Opts = options(Root, Out, Out),
    %% QLC's own source uses its transform. The initial transform is an explicit
    %% private-host seed; the resulting QLC pair is loaded only after both
    %% source modules have been compiled.
    {module, qlc} = code:ensure_loaded(qlc),
    {module, qlc_pt} = code:ensure_loaded(qlc_pt),
    within(HostRoot, code:which(qlc)), within(HostRoot, code:which(qlc_pt)),
    MS = filename:join([Root, "lib", "stdlib", "src", "ms_transform.erl"]),
    compile_one(MS, Opts),
    load_tool(Out, ms_transform),
    lists:foreach(fun(M) ->
        compile_one(filename:join([Root, "lib", "stdlib", "src", M ++ ".erl"]), Opts)
    end, ["qlc", "qlc_pt"]),
    load_tool(Out, qlc), load_tool(Out, qlc_pt),
    lists:foreach(fun(M) ->
        compile_one(filename:join([Root, "lib", "parsetools", "src", M ++ ".erl"]), Opts)
    end, ["yecc", "yeccscan", "yeccparser", "leex"]),
    Prologue = filename:join([filename:dirname(Out), "include", "yeccpre.hrl"]),
    ok = filelib:ensure_dir(Prologue),
    {ok, _} = file:copy(filename:join([Root, "lib", "parsetools", "include", "yeccpre.hrl"]), Prologue);
main(["parser", _Root, Tools, Input, Output, HostRoot]) ->
    compiler_host(HostRoot),
    lists:foreach(fun(M) -> load_tool(Tools, M) end,
                  [ms_transform, qlc, qlc_pt, yecc, yeccscan, yeccparser]),
    true = code:add_patha(Tools),
    ToolRoot = filename:dirname(Tools),
    ToolRoot = code:lib_dir(parsetools),
    ok = filelib:ensure_dir(Output),
    {ok, Output} = yecc:file(Input, [{parserfile, Output}, {deterministic, true}]);
main(["unicode", Input, Output, HostRoot]) ->
    compiler_host(HostRoot),
    {ok, Sections} = escript:extract(Input, [compile_source]),
    {source, Bytes} = lists:keyfind(source, 1, Sections),
    {ok, {Module, []}} = beam_lib:chunks(Bytes, []),
    {module, Module} = code:load_binary(Module, Input, Bytes),
    ok = filelib:ensure_dir(Output),
    ok = file:set_cwd(filename:dirname(Output)),
    %% No update_tests argument: the retained generator must only emit source.
    ok = Module:main([]);
main(["script", Input, HostRoot | Args]) ->
    compiler_host(HostRoot),
    {ok, Sections} = escript:extract(Input, [compile_source]),
    {source, Bytes} = lists:keyfind(source, 1, Sections),
    {ok, {Module, []}} = beam_lib:chunks(Bytes, []),
    {module, Module} = code:load_binary(Module, Input, Bytes),
    ok = Module:main(Args);
main(["diameter", Root, Generated, Application, Syntax, HostRoot, "--tools" | Arguments]) ->
    compiler_host(HostRoot),
    true = code:add_patha(Syntax),
    {module, erl_syntax} = code:ensure_loaded(erl_syntax),
    within(Syntax, code:which(erl_syntax)),
    {Sources, ["--dictionaries" | Schemas]} =
        lists:splitwith(fun(A) -> A =/= "--dictionaries" end, Arguments),
    Tools = filename:join(Generated, "compiler-tools"),
    ok = filelib:ensure_dir(filename:join(Tools, "placeholder")),
    ok = filelib:ensure_dir(filename:join(Application, "placeholder")),
    true = code:add_patha(Application),
    true = code:add_patha(Tools),
    Opts = options(Root, Tools, Generated) ++
        [{i, filename:join([Root, "lib", "diameter", "src", "compiler"])}],
    lists:foreach(fun(Source) ->
        Module = compile_one(Source, Opts),
        load_tool(Tools, Module)
    end, Sources),
    lists:foreach(fun(Schema) ->
        ok = diameter_make:codec({path, Schema}, [{outdir, Generated}, {include, Tools}]),
        ModuleName = "diameter_gen_" ++ filename:basename(Schema, ".dia"),
        Module = compile_one(filename:join(Generated, ModuleName ++ ".erl"), Opts),
        load_tool(Tools, Module)
    end, Schemas);
main(["snmp", Root, Generated, Application, Asn1, Version, HostRoot, "--tools" | Arguments]) ->
    compiler_host(HostRoot),
    true = code:add_patha(Asn1),
    {module, asn1ct} = code:ensure_loaded(asn1ct),
    within(Asn1, code:which(asn1ct)),
    {Sources, ["--mibs" | Schemas]} =
        lists:splitwith(fun(A) -> A =/= "--mibs" end, Arguments),
    Misc = filename:join([Root, "lib", "snmp", "src", "misc"]),
    ok = file:set_cwd(Misc),
    ok = asn1ct:compile("snmp_pdus_basic.set.asn",
        [ber, noobj, deterministic, {outdir, Generated}, {i, Misc}]),
    Tools = filename:join(Generated, "compiler-tools"),
    Mibs = filename:join([Application, "priv", "mibs"]),
    Include = filename:join(Application, "include"),
    Ebin = filename:join(Application, "ebin"),
    lists:foreach(fun(D) -> ok = filelib:ensure_dir(filename:join(D, "placeholder")) end,
                  [Tools, Mibs, Include, Ebin]),
    true = code:add_patha(Ebin),
    Application = code:lib_dir(snmp),
    true = code:add_patha(Tools),
    Opts = options(Root, Tools, Generated) ++
        [{i, filename:join([Root, "lib", "snmp", D])} ||
         D <- ["include", "src/compile", "src/misc", "src/app"]] ++
        [{d, version, Version}, {d, default_verbosity, silence},
         {parse_transform, sys_pre_attributes}, {attribute, insert, app_vsn, "snmp-" ++ Version}],
    lists:foreach(fun(Source) ->
        Module = compile_one(Source, Opts),
        load_tool(Tools, Module)
    end, Sources),
    lists:foreach(fun(Schema) ->
        Name = filename:basename(Schema, ".mib"),
        Bin = filename:join(Mibs, Name ++ ".bin"),
        {ok, Bin} = snmpc:compile(Schema, [version, {i, [Mibs]}, {outdir, Mibs}]),
        Header = filename:join(Generated, Name ++ ".hrl"),
        ok = snmpc_mib_to_hrl:convert(Bin, Header, Name),
        {ok, _} = file:copy(Header, filename:join(Include, Name ++ ".hrl"))
    end, Schemas);
main(["megaco", Source, Generated, Asn1, HostRoot | Modules]) ->
    compiler_host(HostRoot),
    true = code:add_patha(Asn1),
    {module, asn1ct} = code:ensure_loaded(asn1ct),
    within(Asn1, code:which(asn1ct)),
    ok = filelib:ensure_dir(filename:join(Generated, "placeholder")),
    ok = file:set_cwd(Source),
    lists:foreach(fun(Module) ->
        Rule = case lists:prefix("megaco_ber_", Module) of
            true -> [ber, asn1config];
            false -> [per]
        end,
        ok = asn1ct:compile(Module ++ ".set.asn",
            Rule ++ [legacy_erlang_types, noobj, deterministic,
                     {outdir, Generated}, {i, Source}])
    end, Modules);
main(["eldap", Schema, Generated, Asn1, HostRoot]) ->
    compiler_host(HostRoot),
    true = code:add_patha(Asn1),
    {module, asn1ct} = code:ensure_loaded(asn1ct),
    within(Asn1, code:which(asn1ct)),
    ok = filelib:ensure_dir(filename:join(Generated, "placeholder")),
    ok = asn1ct:compile(Schema,
        [ber, legacy_erlang_types, noobj, deterministic, {outdir, Generated}]);
main(["public-key", Source, Generated, Asn1, HostRoot | Modules]) ->
    compiler_host(HostRoot),
    true = code:add_patha(Asn1),
    {module, asn1ct} = code:ensure_loaded(asn1ct),
    within(Asn1, code:which(asn1ct)),
    ok = filelib:ensure_dir(filename:join(Generated, "placeholder")),
    ok = file:set_cwd(Source),
    lists:foreach(fun(M) ->
        Ext = case M of "PKCS-FRAME" -> ".set.asn"; _ -> ".asn1" end,
        ok = asn1ct:compile(M ++ Ext,
            [ber, der, noobj, asn1config, deterministic, {outdir, Generated}, {i, Source}])
    end, Modules);
main(["asn1-templates", Root, Generated, HostRoot | Modules]) ->
    compiler_host(HostRoot),
    Out = filename:join(Generated, "template-tools"),
    ok = filelib:ensure_dir(filename:join(Out, "placeholder")),
    Opts = options(Root, Out, Generated),
    compile_one(filename:join([Root, "lib", "asn1", "src", "prepare_templates.erl"]), Opts),
    load_tool(Out, prepare_templates),
    lists:foreach(fun(M) ->
        compile_one(filename:join([Root, "lib", "asn1", "src", M ++ ".erl"]), Opts)
    end, Modules),
    ok = file:set_cwd(Generated),
    %% The retained generator calls halt/1 after publishing its source output.
    prepare_templates:gen_asn1ct_rtt([filename:join("template-tools", M ++ ".beam") || M <- Modules]);
main(["asn1-eval", Root, Generated, HostRoot]) ->
    compiler_host(HostRoot),
    Out = filename:join(Generated, "eval-tools"),
    ok = filelib:ensure_dir(filename:join(Out, "placeholder")),
    Opts = options(Root, Out, Generated),
    lists:foreach(fun(M) ->
        compile_one(filename:join([Root, "lib", "asn1", "src", atom_to_list(M) ++ ".erl"]), Opts),
        load_tool(Out, M)
    end, [prepare_templates, asn1ct_func]),
    compile_one(filename:join(Generated, "asn1ct_rtt.erl"), Opts),
    load_tool(Out, asn1ct_rtt),
    {ok, _} = file:copy(filename:join([Root, "lib", "asn1", "src", "asn1ct_eval_ext.funcs"]),
                         filename:join(Generated, "asn1ct_eval_ext.funcs")),
    ok = file:set_cwd(Generated),
    prepare_templates:gen_asn1ct_eval(["asn1ct_eval_ext.funcs"]);
main(["application", Root, Tools, App, Version, Out, Generated, Resources, HostRoot | Arguments]) ->
    compiler_host(HostRoot),
    {Dependencies, ["--sources" | Sources]} = lists:splitwith(fun(A) -> A =/= "--sources" end, Arguments),
    lists:foreach(fun(Dependency) ->
        true = filelib:is_dir(Dependency),
        true = code:add_patha(Dependency)
    end, Dependencies),
    lists:foreach(fun(M) -> load_tool(Tools, M) end, [ms_transform, qlc, qlc_pt]),
    ok = filelib:ensure_dir(filename:join(Out, "placeholder")),
    case App of
        A when A =:= "ssl"; A =:= "inets"; A =:= "eunit"; A =:= "tftp"; A =:= "ssh"; A =:= "diameter"; A =:= "snmp"; A =:= "megaco" -> true = code:add_patha(Out);
        _ -> ok
    end,
    SourceIncludes = lists:usort([filename:dirname(S) || S <- Sources]),
    %% Product modules retain ordinary OTP compiler options and source metadata
    %% for inspection tools. Deterministic bootstrap tools remain separate.
    BaseOptions = lists:delete(deterministic, options(Root, Out, Generated)) ++
        [{i, I} || I <- SourceIncludes] ++
        [{i, filename:join([Root, "lib", App, Sub])} || Sub <- ["src", "include"]] ++
        case App of
            "wx" -> [{d, 'CAN_BUILD_DRIVER'}];
            "observer" -> [{i, filename:join([Root, "lib", "et", "include"])}];
            "megaco" -> [{d, megaco_parser_inline}, {d, 'ENABLE_MEGACO_FLEX_SCANNER', true},
                         {d, 'MEGACO_REENTRANT_FLEX_SCANNER', true}];
            "snmp" -> [{d, version, Version}, {d, default_verbosity, silence},
                       {d, empty_pdu_size, 21}];
            "edoc" -> [no_docs];
            "common_test" -> [{i, filename:join([Root, "lib", "snmp", "include"])}];
            Versioned when Versioned =:= "ssl"; Versioned =:= "ftp" -> [{d, 'VSN', Version}];
            _ -> []
        end,
    Modules = lists:map(fun(Source) ->
        AttributeOptions = case App =:= "inets" orelse App =:= "diameter" orelse App =:= "snmp" orelse App =:= "megaco" orelse App =:= "reltool" orelse
                          (App =:= "public_key" andalso lists:prefix("pub", filename:basename(Source))) of
            true -> [{parse_transform, sys_pre_attributes},
                     {attribute, insert, app_vsn, App ++ "-" ++ Version} | BaseOptions];
            false -> BaseOptions
        end,
        AppOptions = case {App, filename:basename(filename:dirname(Source))} of
            {"inets", "http_server"} -> [{d, 'SERVER_SOFTWARE', "inets/" ++ Version} | AttributeOptions];
            _ -> AttributeOptions
        end,
        Opts = case filename:basename(Source) of
            DialyzerModule when App =:= "dialyzer",
                (DialyzerModule =:= "dialyzer_cl_parse.erl" orelse
                 DialyzerModule =:= "dialyzer_plt.erl" orelse
                 DialyzerModule =:= "dialyzer_cplt.erl" orelse
                 DialyzerModule =:= "dialyzer_iplt.erl" orelse
                 DialyzerModule =:= "typer.erl") ->
                [{d, 'VSN', "v" ++ Version} | BaseOptions];
            "asn1ct.erl" -> [{d, vsn, Version} | BaseOptions];
            "beam_asm.erl" -> [{d, 'COMPILER_VSN', Version} | BaseOptions];
            "merl_transform.erl" when App =:= "syntax_tools" ->
                %% Upstream bootstraps this transform without applying itself,
                %% then uses that seed to compile the final product transform.
                lists:foreach(fun(M) -> load_tool(Out, M) end,
                    [erl_syntax, erl_syntax_lib, erl_comment_scan, erl_prettypr,
                     prettypr, merl]),
                Bootstrap = filename:join(Generated, "transform-bootstrap"),
                ok = filelib:ensure_dir(filename:join(Bootstrap, "placeholder")),
                merl_transform = compile_one(Source,
                    [{d, 'MERL_NO_TRANSFORM'}, {outdir, Bootstrap} |
                     proplists:delete(outdir, BaseOptions)]),
                load_tool(Bootstrap, merl_transform),
                BaseOptions;
            _ -> AppOptions
        end,
        compile_one(Source, Opts)
    end, Sources),
    true = length(Modules) =:= length(lists:usort(Modules)),
    AppSource = filename:join(Resources, App ++ ".app.src"),
    AppOutput = filename:join(Out, App ++ ".app"),
    resource(AppSource, AppOutput, Version),
    {ok, [{application, Name, Properties}]} = file:consult(AppOutput),
    Name = list_to_atom(App),
    {modules, Declared} = lists:keyfind(modules, 1, Properties),
    case Declared -- Modules of
        [] -> ok;
        Missing -> error({unbuilt_application_modules, App, Missing})
    end,
    Appup = filename:join(Resources, App ++ ".appup.src"),
    resource(Appup, filename:join(Out, App ++ ".appup"), Version),
    %% Publish a content record only after every declared module is available.
    Artifacts = [filename:join(Out, atom_to_list(M) ++ ".beam") || M <- Modules],
    Record = #{application => Name, version => Version,
               compiler => code:which(compile), dependencies => Dependencies, sources => Sources,
               modules => lists:sort(Modules), artifacts => Artifacts},
    ok = file:write_file(filename:join(Out, "build.term"), io_lib:format("~tp.~n", [Record]));
main(["preloads", Root, Out, HostRoot | Sources]) ->
    compiler_host(HostRoot),
    ok = filelib:ensure_dir(filename:join(Out, "placeholder")),
    lists:foreach(fun(Source) ->
        Extra = case filename:extension(Source) of ".S" -> [from_asm]; _ -> [] end,
        compile_one(Source, Extra ++ options(Root, Out, Out))
    end, Sources),
    %% prim_eval executes assembly but upstream supplies inspection forms from
    %% its Erlang stub. The retained add_abstract_code script combines them.
    compile_one(filename:join([Root, "erts", "preloaded", "src", "prim_eval.erl"]),
                [dabstr | options(Root, Out, Out)]);
main(["boot", Sasl, Lib, Output, HostRoot]) ->
    compiler_host(HostRoot),
    lists:foreach(fun(M) -> load_tool(Sasl, M) end,
        [systools, systools_make, systools_lib]),
    Paths = filelib:wildcard(filename:join([Lib, "*", "ebin"])),
    %% Default systools paths use $ROOT/lib/<application-version>/ebin.
    BootOptions = case filename:basename(Output) of
        "no_dot_erlang" -> [no_dot_erlang];
        _ -> []
    end,
    case systools:make_script(Output, BootOptions ++ [{path, Paths}, {outdir, filename:dirname(Output)}, silent]) of
        {ok, _, Warnings} -> io:format("Boot generation warnings: ~tp~n", [Warnings]);
        Error -> error({boot_generation_failed, Error})
    end;
main(["release-index", Sasl, Release, Out, HostRoot]) ->
    compiler_host(HostRoot),
    load_tool(Sasl, release_handler),
    ok = filelib:ensure_dir(filename:join(Out, "placeholder")),
    ok = release_handler:create_RELEASES("%ERL_ROOT%", Out, Release, []),
    ok = file:rename(filename:join(Out, "RELEASES"), filename:join(Out, "RELEASES.src"));
main(["verify-compiler", Compiler, Stdlib, Probe, Out, HostRoot]) ->
    compiler_host(HostRoot),
    %% Replace the seed compiler in this disposable host with every module from
    %% the source-built compiler application, plus its generated Erlang parser.
    Paths = filelib:wildcard(filename:join(Compiler, "*.beam")) ++
        [filename:join(Stdlib, "erl_parse.beam")],
    Inputs = lists:map(fun(Path) ->
        {ok, Bytes} = file:read_file(Path),
        {ok, {Module, []}} = beam_lib:chunks(Bytes, []),
        true = code:unstick_mod(Module),
        {Module, Path, Bytes}
    end, Paths),
    ok = code:atomic_load(Inputs),
    lists:foreach(fun({Module, Path, _}) -> Path = code:which(Module) end, Inputs),
    ok = filelib:ensure_dir(filename:join(Out, "placeholder")),
    otp_compiler_probe = compile_one(Probe, [deterministic, report_errors,
                                            report_warnings, {outdir, Out}]),
    load_tool(Out, otp_compiler_probe),
    42 = otp_compiler_probe:run(),
    io:format("Source-built compiler and generated parser verified (~p modules).~n", [length(Inputs)]);
main(Args) -> error({invalid_build_driver_arguments, Args}).

compiler_host(HostRoot) ->
    {module, compile} = code:ensure_loaded(compile),
    within(HostRoot, code:which(compile)),
    "29" = erlang:system_info(otp_release),
    ok.

within(Root, Path) when is_list(Path) ->
    true = lists:prefix(filename:split(filename:absname(Root)),
                        filename:split(filename:absname(Path))),
    ok.

options(Root, Out, Generated) ->
    Includes = [Generated, filename:join(Root, "lib")] ++
        [filename:join([Root, "lib", A, Sub]) ||
            A <- ["kernel", "stdlib", "compiler", "parsetools"], Sub <- ["src", "include"]],
    [deterministic, debug_info, report_errors, report_warnings,
     {outdir, Out} | [{i, I} || I <- Includes]].

compile_one(Source, Options) ->
    case compile:noenv_file(Source, Options) of
        {ok, Module} -> Module;
        {ok, Module, _} -> Module;
        Error -> error({compilation_failed, Source, Error})
    end.

load_tool(Directory, Module) ->
    Path = filename:join(Directory, atom_to_list(Module) ++ ".beam"),
    {ok, Bytes} = file:read_file(Path),
    true = code:unstick_mod(Module),
    {module, Module} = code:load_binary(Module, Path, Bytes),
    Path = code:which(Module),
    ok.

resource(Source, Output, Version) ->
    {ok, Contents} = file:read_file(Source),
    Replaced = binary:replace(Contents, <<"%VSN%">>, list_to_binary(Version), [global]),
    ok = file:write_file(Output, Replaced).
