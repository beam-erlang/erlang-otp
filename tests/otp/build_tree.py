#!/usr/bin/env python3
"""Check the source-shaped build tree using only task-owned temporary outputs."""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from native_process import WINDOWS, ContainedProcess, command as native_command, stop_tree


def cmake_literal(value):
    value, equals = str(value), "="
    while "]" + equals + "]" in value:
        equals += "="
    return "[" + equals + "[" + value + "]" + equals + "]"


PROBE = r'''
-module(otp_build_tree_probe).
-export([identity/0, product/0, compiler_records/0, transport_records/0]).

path(Name) -> filename:absname(os:getenv(Name)).

identity() ->
    Root = path("OTP_TREE_ROOT"),
    Root = filename:absname(code:root_dir()),
    {ok, [[Root]]} = init:get_argument(root),
    Bin = filename:join([path("OTP_TREE_BUILD"), "bin", os:getenv("OTP_TREE_TARGET")]),
    {ok, [[Bin]]} = init:get_argument(bindir),
    Boot = path("OTP_TREE_BOOT"),
    {ok, BootArguments} = init:get_argument(boot),
    true = BootArguments =/= [],
    true = lists:all(fun([Path]) -> Path =:= Boot end, BootArguments),
    {ok, BootBytes} = file:read_file(Boot ++ ".boot"),
    {script, ScriptId, _} = binary_to_term(BootBytes),
    ScriptId = init:script_id(),
    ExpectedCompiler = path("OTP_TREE_COMPILER"),
    {module, compile} = code:ensure_loaded(compile),
    ExpectedCompiler = filename:absname(code:which(compile)),
    ExpectedKernel = filename:join([Root, "lib", "kernel", "ebin", "code.beam"]),
    ExpectedKernel = filename:absname(code:which(code)),
    Flavor = list_to_atom(os:getenv("OTP_TREE_FLAVOR")),
    Flavor = erlang:system_info(emu_flavor),
    Diagnostics = case os:getenv("OTP_TREE_BUILD_TYPE") of
                      "Release" -> {opt,false,false};
                      "Debug" -> {debug,true,true}
                  end,
    Diagnostics = {erlang:system_info(build_type),
                   erlang:system_info(debug_compiled),
                   erlang:system_info(lock_checking)},
    Triple = os:getenv("OTP_TREE_TARGET"),
    Triple = erlang:system_info(system_architecture),
    Version = os:getenv("OTP_TREE_ERTS"),
    Version = erlang:system_info(version),
    "29" = erlang:system_info(otp_release),
    [file] = inet_db:res_option(lookup),
    io:format("otp-build-tree-identity-ok ~s ~s~n", [Root, ExpectedCompiler]).

product() ->
    Build = path("OTP_TREE_BUILD"),
    Source = path("OTP_TREE_SOURCE"),
    Apps = string:lexemes(os:getenv("OTP_TREE_APPS"), ","),
    35 = length(Apps),
    Records = filelib:wildcard(filename:join([Build, "lib", "*", "ebin", "build.term"])),
    ExpectedRecords = lists:sort([filename:join([Build, "lib", A, "ebin", "build.term"]) || A <- Apps]),
    ExpectedRecords = lists:sort(Records),
    SeedCompiler = filename:join([Build, "bootstrap", "lib", "compiler", "ebin", "compile.beam"]),
    lists:foreach(fun(Name) ->
        App = list_to_atom(Name),
        AppRoot = filename:join([Build, "lib", Name]),
        AppRoot = filename:absname(code:lib_dir(App)),
        Ebin = filename:join(AppRoot, "ebin"),
        {ok, [Record]} = file:consult(filename:join(Ebin, "build.term")),
        App = maps:get(application, Record),
        SeedCompiler = maps:get(compiler, Record),
        Version = maps:get(version, Record),
        {ok, [{application, App, Properties}]} = file:consult(filename:join(Ebin, Name ++ ".app")),
        Version = proplists:get_value(vsn, Properties),
        {ok, _} = file:consult(filename:join(Ebin, Name ++ ".appup")),
        Modules = lists:sort(maps:get(modules, Record)),
        Modules = lists:usort(Modules),
        [] = proplists:get_value(modules, Properties) -- Modules,
        Beams = lists:sort([filename:join(Ebin, atom_to_list(M) ++ ".beam") || M <- Modules]),
        Beams = lists:sort(maps:get(artifacts, Record)),
        Beams = lists:sort(filelib:wildcard(filename:join(Ebin, "*.beam"))),
        lists:foreach(fun(Beam) ->
            {ok, {_, [{exports, _}]}} = beam_lib:chunks(Beam, [exports])
        end, Beams),
        Sources = maps:get(sources, Record),
        Modules = lists:sort([list_to_atom(filename:basename(S, ".erl")) || S <- Sources]),
        lists:foreach(fun(S) ->
            true = filelib:is_regular(S),
            true = within(filename:join([Source, "lib", Name]), S) orelse within(AppRoot, S)
        end, Sources)
    end, Apps),
    lists:foreach(fun({App, Module}) ->
        Beam = filename:join([Build, "lib", App, "ebin", Module ++ ".beam"]),
        {ok, {_, [{compile_info, Info}]}} = beam_lib:chunks(Beam, [compile_info]),
        ExpectedSource = filename:join([Source, "lib", App, "src", Module ++ ".erl"]),
        ExpectedSource = proplists:get_value(source, Info)
    end, [{"compiler", "compile"}, {"stdlib", "gen_server"}]),
    ok = preloads(Build),
    ok = native(Build),
    io:put_chars("otp-build-tree-product-ok\n").

within(Root, File) ->
    lists:prefix(filename:split(filename:absname(Root)), filename:split(filename:absname(File))).

preloads(Build) ->
    Ebin = filename:join([Build, "erts", "ebin"]),
    Erts = filename:join(Build, "erts"),
    Erts = filename:absname(code:lib_dir(erts)),
    Files = filelib:wildcard(filename:join(Ebin, "*.beam")),
    22 = length(Files),
    {ok, Xref} = xref:start([]),
    try
        _ = xref:set_default(Xref, [{verbose, false}, {warnings, false}]),
        Modules0 = lists:map(fun(File) ->
            Module = list_to_atom(filename:basename(File, ".beam")),
            preloaded = code:which(Module),
            {Module, Object, File} = code:get_object_code(Module),
            {ok, Object} = file:read_file(File),
            {ok, Docs} = code:get_doc(Module),
            docs_v1 = element(1, Docs),
            LogicalSource = filename:join(["erts", "preloaded", "src", atom_to_list(Module) ++ ".erl"]),
            LogicalSource = maps:get(source_path, element(6, Docs)),
            true = filelib:is_regular(filename:join([Build, "erts", "preloaded", "src",
                                                   filename:basename(LogicalSource)])),
            {ok, Module} = xref:add_module(Xref, File),
            Module
        end, Files),
        Modules = lists:sort(Modules0),
        Modules = lists:sort(erlang:pre_loaded())
    after
        stopped = xref:stop(Xref)
    end,
    ok.

native(Build) ->
    Triple = os:getenv("OTP_TREE_TARGET"),
    Ext = case os:type() of {win32,_} -> ".dll"; _ -> ".so" end,
    lists:foreach(fun({App, Name}) ->
        File = filename:join([Build, "lib", App, "priv", "lib", Triple, Name ++ Ext]),
        true = filelib:is_regular(File),
        false = filelib:is_regular(filename:join([Build, "lib", App, "priv", "lib", Name ++ Ext]))
    end, [{"crypto", "crypto"}, {"asn1", "asn1rt_nif"}]),
    <<"BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD">> =
        binary:encode_hex(crypto:hash(sha256, <<"abc">>)),
    {{2, <<42>>}, <<>>} = asn1rt_nif:decode_ber_tlv(<<2, 1, 42>>),
    <<2, 1, 42>> = asn1rt_nif:encode_ber_tlv({2, <<42>>}),
    lists:foreach(fun(Name) ->
        true = filelib:is_regular(filename:join([Build, "lib", "wx", "priv", Triple, Name ++ Ext]))
    end, ["wxe_driver", "erl_gl"]),
    ok.

compiler_records() ->
    Work = path("OTP_TREE_WORK"),
    Build = path("OTP_TREE_BUILD"),
    lists:foreach(fun({Name, Expected}) ->
        Beam = filename:join([Work, Name, "otp_build_tree_asset.beam"]),
        {ok, {otp_build_tree_asset, [{attributes, Attributes}, {compile_info, Info}]}} =
            beam_lib:chunks(Beam, [attributes, compile_info]),
        Expected = proplists:get_value(compiler_origin, Attributes),
        ExpectedSource = filename:join(Work, "otp_build_tree_asset.erl"),
        ExpectedSource = proplists:get_value(source, Info)
    end, [{"product", filename:join([Build, "lib", "compiler", "ebin", "compile.beam"])},
          {"bootstrap", filename:join([Build, "bootstrap", "lib", "compiler", "ebin", "compile.beam"])}]),
    io:put_chars("otp-build-tree-compiler-records-ok\n").

transport_records() ->
    Transport = path("OTP_TREE_TRANSPORT"),
    Build = path("OTP_TREE_BUILD"),
    Beam = filename:join([Transport, "output with 'apostrophe'", "otp_execution_transport.beam"]),
    {ok, {otp_execution_transport, [{attributes, Attributes}, {compile_info, Info}]}} =
        beam_lib:chunks(Beam, [attributes, compile_info]),
    ExpectedCompiler = filename:join([Build, "bootstrap", "lib", "compiler", "ebin", "compile.beam"]),
    ExpectedCompiler = proplists:get_value(compiler_origin, Attributes),
    ExpectedSource = filename:join([Transport, "source with spaces", "otp_execution_transport.erl"]),
    ExpectedSource = proplists:get_value(source, Info),
    {module, otp_execution_transport} = code:load_abs(filename:rootname(Beam)),
    {tuple, "space and 'apostrophe'; ]=]", [one, two]} = otp_execution_transport:value(),
    io:put_chars("otp-build-tree-cmake-transport-ok\n").
'''


class Runner:
    def __init__(self, args, work):
        self.args, self.work = args, work
        self.log = []
        for name in ("home", "temporary", "ebin", "product", "bootstrap", "fake"):
            (work / name).mkdir()
        (work / "inetrc").write_text('{lookup,[file]}.\n{domain,"beam.test"}.\n')
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("ERL_", "ERLC_", "BEAM_", "LD_", "DYLD_"))
                    and key not in {"ROOTDIR", "BINDIR", "EMU", "PROGNAME", "ESCRIPT_NAME",
                                    "ESCRIPT_EMULATOR", "EPMD_PORT", "RELEASE_ROOT", "RELDIR"}}
        self.env.update(PATH=self.env['PATH'] if WINDOWS else "/usr/bin:/bin:/usr/sbin:/sbin", HOME=str(work / "home"),
                        TMPDIR=str(work / "temporary"), ERLC_USE_SERVER="no",
                        ERL_INETRC=str(work / "inetrc"), ERL_CRASH_DUMP=str(work / "crash.dump"),
                        OTP_TREE_BUILD=str(args.build), OTP_TREE_SOURCE=str(args.source),
                        OTP_TREE_TARGET=args.target, OTP_TREE_FLAVOR=args.flavor,
                        OTP_TREE_BUILD_TYPE=args.build_type,
                        OTP_TREE_ERTS=args.erts_version, OTP_TREE_APPS=",".join(args.apps),
                        OTP_TREE_WORK=str(work))
        marker = json.dumps(str(work / "startup-file-entered"))
        startup = f'file:write_file({marker}, <<"unexpected startup">>), erlang:halt(91).\n'
        (work / ".erlang").write_text(startup)
        (work / "home/.erlang").write_text(startup)
        self.log.append((args.build / "sdk-selection.txt").read_text(encoding="utf-8"))

    def run(self, label, command, *, env=None, expected=0):
        command = native_command(command)
        self.log.append(f"{label}: {command!r}")
        process = ContainedProcess(command, cwd=self.work, env=self.env if env is None else env,
                                   stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                                   errors="replace", start_new_session=True)
        try:
            output, _ = process.communicate(timeout=120)
        except BaseException:
            with contextlib.suppress(ProcessLookupError):
                stop_tree(process)
            output, _ = process.communicate()
            self.log.append(output[-200000:])
            raise
        finally:
            process.close_tree()
        self.log.append(output[-200000:])
        (self.work / "test.log").write_text("\n".join(self.log))
        if process.returncode != expected:
            raise RuntimeError(f"{label}: exited {process.returncode}, expected {expected}\n{output[-12000:]}")
        return output

    def erl(self, label, root, function, compiler):
        # The boot script controls user startup-file evaluation. start_clean
        # intentionally retains upstream .erlang behavior for ordinary users.
        boot = root / "bin/no_dot_erlang"
        env = dict(self.env, OTP_TREE_ROOT=str(root), OTP_TREE_BOOT=str(boot), OTP_TREE_COMPILER=str(compiler))
        expression = (f"try otp_build_tree_probe:{function}(),halt(0) catch C:R:S -> "
                      'io:format(standard_error,"~tp~n",[{C,R,S}]),halt(1) end.')
        return self.run(label, [root / "bin/erl", "+S", "2:2", "+SDcpu", "1", "+SDio", "1",
                               "-boot", boot, "-noshell", "-noinput",
                               "-pa", self.work / "ebin", "-eval", expression], env=env)

    def cmake_tools(self):
        cache = {}
        for line in (self.args.build / "CMakeCache.txt").read_text(encoding="utf-8").splitlines():
            match = re.match(r"([^/#][^:]*):[^=]+=(.*)$", line)
            if match:
                cache[match[1]] = match[2]
        return cache["CMAKE_COMMAND"], cache["CMAKE_MAKE_PROGRAM"]

    def migrate_ownership(self):
        root = self.work / "legacy ownership with 'apostrophe'"
        out = root / "ebin"
        out.mkdir(parents=True)
        keep, removed, sentinel = out / "kept.beam", out / "removed.beam", out / "unowned-sentinel.beam"
        for path, content in ((keep, b"current owned module"), (removed, b"obsolete owned module"),
                              (sentinel, b"unowned output must survive")):
            path.write_bytes(content)
        previous = {path: path.read_bytes() for path in (keep, removed, sentinel)}
        record = out / "build.term"
        record.write_text("#{artifacts=>[" + ",".join(json.dumps(str(path)) for path in (keep, removed)) + "]}.\n")
        previous_record = record.read_bytes()
        receipt = root / "owned-outputs.json"
        self.run("migrate-legacy-build-record", [self.args.build / "bootstrap/bin/erl", "+S", "1",
            "-noshell", "-noinput", "-pa", self.args.build / "CMakeFiles/otp/validator",
            "-s", "otp_application_validator", "migrate", "-extra", out, receipt])
        if json.loads(receipt.read_text(encoding="utf-8")) != [keep.name, removed.name]:
            raise RuntimeError("legacy artifact migration did not preserve exact basename ownership")
        if record.read_bytes() != previous_record or any(path.read_bytes() != content for path, content in previous.items()):
            raise RuntimeError("legacy artifact migration modified output files")
        script = root / "prune-owned-outputs.cmake"
        script.write_text("\n".join([
            "cmake_minimum_required(VERSION 3.25)",
            "include(" + cmake_literal(self.args.source / "cmake/OTPStaging.cmake") + ")",
            "otp_remove_obsolete(" + " ".join(cmake_literal(path) for path in (out, receipt, keep)) + ")",
            "otp_record_outputs(" + " ".join(cmake_literal(path) for path in (out, receipt, keep)) + ")",
        ]) + "\n")
        cmake, _ = self.cmake_tools()
        self.run("prune-migrated-owned-output", [cmake, "-P", script])
        if removed.exists() or keep.read_bytes() != previous[keep] or sentinel.read_bytes() != previous[sentinel]:
            raise RuntimeError("owned-output cleanup removed unowned/current data or retained obsolete data")
        if json.loads(receipt.read_text(encoding="utf-8")) != [keep.name]:
            raise RuntimeError("owned-output receipt did not advance to the current selection")
        self.run("repeat-owned-output-cleanup", [cmake, "-P", script])
        if keep.read_bytes() != previous[keep] or sentinel.read_bytes() != previous[sentinel]:
            raise RuntimeError("repeated owned-output cleanup modified current/unowned data")

    def transport(self):
        cmake, ninja = self.cmake_tools()
        root = self.work / "CMake transport with spaces and 'apostrophe'"
        source, binary, output = root / "source with spaces", root / "build with spaces", root / "output with 'apostrophe'"
        source.mkdir(parents=True)
        output.mkdir()
        module = source / "otp_execution_transport.erl"
        module.write_text('''-module(otp_execution_transport).
-compile({parse_transform,otp_build_tree_transform}).
-export([value/0]).
value() -> ?OTP_TRANSPORT.
''')
        arguments = [self.args.build / "bootstrap/bin/erlc", "-no-server", "+debug_info", "-pa", self.work / "ebin",
                     "-o", output, '+{d,\'OTP_TRANSPORT\',{tuple,"space and \'apostrophe\'; ]=]",[one,two]}}', module.name]
        project = [
            "cmake_minimum_required(VERSION 3.25)",
            "project(otp_execution_transport LANGUAGES NONE)",
            "set(OTP_BOOTSTRAP_ROOT " + cmake_literal(self.args.build / "bootstrap") + ")",
            'set(OTP_INTERNAL_ROOT "${PROJECT_BINARY_DIR}/CMakeFiles/otp")',
            'file(MAKE_DIRECTORY "${OTP_INTERNAL_ROOT}/commands")',
            'file(WRITE "${OTP_INTERNAL_ROOT}/bootstrap-inetrc" ' + cmake_literal('{lookup,[file]}.\n{domain,"beam.test"}.\n') + ")",
            "include(" + cmake_literal(self.args.source / "cmake/OTPExecution.cmake") + ")",
            "otp_command(_compile " + cmake_literal(source) + " " + " ".join(cmake_literal(arg) for arg in arguments) + ")",
            "add_custom_command(OUTPUT " + cmake_literal(output / "otp_execution_transport.beam") +
            " ${_compile} DEPENDS " + cmake_literal(module) + " ${_compile_INPUTS} VERBATIM)",
            "add_custom_target(transport ALL DEPENDS " + cmake_literal(output / "otp_execution_transport.beam") + ")",
        ]
        (source / "CMakeLists.txt").write_text("\n".join(project) + "\n")
        self.run("configure-cmake-transport", [cmake, "-S", source, "-B", binary, "-G", "Ninja",
                                              "-DCMAKE_MAKE_PROGRAM=" + ninja])
        poisoned = dict(self.env, ERL_TRANSPORT_POISON="unexpected", ERLC_TRANSPORT_POISON="unexpected",
                        BEAM_TRANSPORT_POISON="unexpected", ERLC_EMULATOR="/usr/bin/false",
                        ERLC_USE_SERVER="invalid", ERL_COMPILER_OPTIONS="[to_core]",
                        ERL_AFLAGS="-eval erlang:halt(91).", ERL_LIBS=str(self.work / "fake"),
                        ROOTDIR="transport-poison", BINDIR="transport-poison", EMU="transport-poison")
        self.run("build-cmake-transport", [cmake, "--build", binary], env=poisoned)
        self.env["OTP_TREE_TRANSPORT"] = str(root)
        self.erl("cmake-transport-records", self.args.build, "transport_records",
                 self.args.build / "lib/compiler/ebin/compile.beam")

    def check(self):
        args, build, work = self.args, self.args.build, self.work
        seed = build / "bootstrap"
        if args.build_type == "Debug" and not WINDOWS:
            alias = build / "bin" / args.target / "erl_child_setup.debug"
            if not alias.is_symlink() or alias.readlink() != Path("erl_child_setup"):
                raise RuntimeError("Debug bootstrap needs a relative erl_child_setup.debug alias")
        (work / "otp_build_tree_probe.erl").write_text(PROBE)
        self.run("compile-probe", [build / "bin/erlc", "-no-server", "+debug_info", "-o", work / "ebin",
                                   "otp_build_tree_probe.erl"])
        self.erl("product-identity", build, "identity", build / "lib/compiler/ebin/compile.beam")
        self.erl("bootstrap-identity", seed, "identity", seed / "lib/compiler/ebin/compile.beam")
        self.erl("product-content", build, "product", build / "lib/compiler/ebin/compile.beam")
        original = args.source / "bootstrap/lib/compiler/ebin"
        for source in original.glob("*.beam"):
            if hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256((seed / "lib/compiler/ebin" / source.name).read_bytes()).digest():
                raise RuntimeError(f"bootstrap compiler seed changed: {source.name}")
        (work / "otp_build_tree_transform.erl").write_text('''-module(otp_build_tree_transform).
-export([parse_transform/2]).
parse_transform(Forms, _) ->
    [false,false,false] = [os:getenv(Name) || Name <-
        ["ERL_TRANSPORT_POISON","ERLC_TRANSPORT_POISON","BEAM_TRANSPORT_POISON"]],
    lists:flatmap(fun({attribute,L,module,_}=F) ->
                         [F,{attribute,L,compiler_origin,code:which(compile)}];
                    (F) -> [F]
                 end, Forms).
''')
        (work / "otp_build_tree_asset.erl").write_text('''-module(otp_build_tree_asset).
-compile({parse_transform,otp_build_tree_transform}).
-export([run/0]).
run() -> ok.
''')
        self.run("compile-transform", [build / "bin/erlc", "-no-server", "-o", work / "ebin",
                                       "otp_build_tree_transform.erl"])
        for name, root in (("product", build), ("bootstrap", seed)):
            self.run(f"{name}-erlc", [root / "bin/erlc", "-no-server", "+debug_info", "-pa", work / "ebin",
                                      "-o", work / name, "otp_build_tree_asset.erl"])
        self.erl("compiler-records", build, "compiler_records", build / "lib/compiler/ebin/compile.beam")
        marker = work / "fake-compiler-entered"
        (work / "fake/compile.erl").write_text('''-module(compile).
-on_load(entered/0).
-export([compile/3]).
entered() -> file:write_file(''' + json.dumps(str(marker)) + ''', <<"entered">>).
compile(_,_,_) -> erlang:halt(91).
''')
        self.run("compile-fake", [build / "bin/erlc", "-no-server", "-o", work / "fake", work / "fake/compile.erl"])
        output = self.run("reject-compiler-shadow", [seed / "bin/erlc", "-no-server",
            "-pa", work / "fake", "-o", work / "fake", "otp_build_tree_asset.erl"], expected=1)
        if "OTP bootstrap selection mismatch" not in output or marker.exists():
            raise RuntimeError("compiler-origin guard did not reject the shadow module before loading it")
        self.transport()
        self.migrate_ownership()
        if (work / "startup-file-entered").exists():
            raise RuntimeError("a build launcher executed a personal/current-directory startup file")


def main():
    def interrupted(signum, _frame):
        raise RuntimeError(f"interrupted by signal {signum}")

    signal.signal(signal.SIGTERM, interrupted)
    if hasattr(signal, 'SIGHUP'):
        signal.signal(signal.SIGHUP, interrupted)
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "build"):
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ("erts-version", "flavor", "target"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--build-type", choices=("Release", "Debug"), default="Release")
    parser.add_argument("--apps", nargs="+", required=True)
    args = parser.parse_args()
    args.source, args.build = args.source.resolve(), args.build.resolve()
    if len(args.apps) != 35 or len(set(args.apps)) != 35:
        parser.error("the build-tree check requires the explicit 35-application product selection")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", args.target):
        parser.error("target must be the selected SDK's safe runtime architecture component")
    scratch = args.source.parent / "tmp"
    scratch.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="otp-build-tree-", dir=scratch))
    runner = None
    try:
        runner = Runner(args, work)
        runner.check()
    except BaseException:
        if runner is not None:
            (work / "test.log").write_text("\n".join(runner.log))
        print(f"otp-build-tree: failed; evidence retained at {work}", file=sys.stderr)
        raise
    else:
        shutil.rmtree(work)
        print("otp-build-tree: passed; build/bootstrap launchers, compiler selection, 35 apps, preloads and native loading")


if __name__ == "__main__":
    main()
