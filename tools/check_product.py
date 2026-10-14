#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Install, relocate and exercise the initial OTP product (not full certification)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from scratch import scratch
import pty
import re
import select
import signal
import time
import sys
from host_testing import work_root, seatbelt, select_observer, identity_expression, owned_runtime_scope

from installation_inventory import inventory, verify_installation


def term(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'


def shell_check(command, work, environment):
    pid, terminal = pty.fork()
    if pid == 0:
        os.chdir(work)
        os.execvpe(command[0], command, dict(environment, TERM="xterm"))
    waited = False
    transcript = bytearray()

    def prompt(marker):
        deadline = time.monotonic() + 20
        output = bytearray()
        while time.monotonic() < deadline:
            clean = re.sub(rb"\x1b\[[0-9;?]*[ -/]*[@-~]", b"", output)
            if marker in clean:
                return clean.replace(b"\r\n", b"\n")
            readable, _, _ = select.select([terminal], [], [], max(0, deadline - time.monotonic()))
            if readable:
                try:
                    chunk = os.read(terminal, 65536)
                except OSError as error:
                    raise RuntimeError(f"Shell closed before {marker!r}: {bytes(transcript)!r}") from error
                if not chunk:
                    break
                output.extend(chunk)
                transcript.extend(chunk)
        raise RuntimeError(f"Shell did not reach {marker!r}: {bytes(transcript)!r}")

    try:
        prompt(b"1> ")
        os.write(terminal, b"X = 40 + 2.\n")
        if b"\n42\n" not in prompt(b"2> "):
            raise RuntimeError(f"Shell evaluation failed: {bytes(transcript)!r}")
        os.write(terminal, b"X + 1.\n")
        if b"\n43\n" not in prompt(b"3> "):
            raise RuntimeError(f"Shell binding was not retained: {bytes(transcript)!r}")
        os.write(terminal, b"halt().\n")
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            result, status = os.waitpid(pid, os.WNOHANG)
            if result:
                waited = True
                if not os.WIFEXITED(status) or os.WEXITSTATUS(status):
                    raise RuntimeError(f"Shell exit status: {status}")
                return
            if select.select([terminal], [], [], 0.02)[0]:
                try:
                    transcript.extend(os.read(terminal, 65536))
                except OSError:
                    pass
        raise RuntimeError("Shell did not halt")
    finally:
        if not waited:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(pid, 0)
        os.close(terminal)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "sdk"):
        parser.add_argument("--" + name, required=True, type=Path)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--build", type=Path)
    selection.add_argument("--prefix", type=Path,
                           help="Reuse a source-attested candidate installation for fixture-only changes")
    parser.add_argument("--provenance", type=Path)
    parser.add_argument("--work-root", type=Path)
    parser.add_argument("--cmake", default="cmake")
    parser.add_argument("--cc", required=True)
    parser.add_argument("--bwrap", type=Path)
    parser.add_argument("--flavor", required=True, choices=["emu", "jit"])
    args = parser.parse_args()
    if args.prefix and (not args.provenance or not args.work_root):
        parser.error("--prefix requires --provenance and --work-root")
    if args.provenance and not args.prefix:
        parser.error("--provenance requires --prefix")
    installed = verify_installation(args.prefix, args.provenance) if args.prefix else None
    if installed and (installed["runtime"] != "candidate" or installed["flavor"] != args.flavor):
        parser.error("Product acceptance requires a candidate of the selected flavor")
    sdk_selection = installed["build"]["sdk_selection"] if installed else json.loads((args.build / "sdk-selection.json").read_text())
    if installed:
        sdk_root = args.sdk.resolve(strict=True)
        sdk_artifacts = json.loads((sdk_root / "lib/beam/runtime-artifacts.json").read_text())
        if sdk_artifacts["build-id"] != sdk_selection["build_id"]:
            raise RuntimeError("Selected SDK differs from the candidate's source-attested SDK")
        for name, digest in sdk_selection["artifacts"].items():
            artifact = sdk_artifacts["artifacts"][name]
            if artifact["sha256"] != digest or hashlib.sha256((sdk_root / artifact["path"]).read_bytes()).hexdigest() != digest:
                raise RuntimeError(f"Selected SDK artifact differs: {name}")
    checks = args.work_root.resolve() if args.work_root else work_root(args.build, "product")
    if args.prefix and checks.is_relative_to(args.prefix.resolve()):
        parser.error("Test output must be outside the selected installation")
    checks.mkdir(parents=True, exist_ok=True)
    work = checks / ('product-' + str(time.time_ns()))
    work.mkdir()
    with scratch(work), owned_runtime_scope(args.build, work):
        original, prefix = work / "original", work / "relocated OTP"
        if installed:
            shutil.copytree(args.prefix.resolve(), original, symlinks=True)
            if inventory(original) != installed["entries"]:
                raise RuntimeError("Copied candidate differs from its external provenance")
        else:
            subprocess.run([args.cmake, "--install", str(args.build), "--prefix", str(original)],
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        original.rename(prefix)
        # OTP native paths must deploy this product's source-built
        # outputs, not copies of the SDK's transitional OTP implementation.
        # A verified existing prefix binds all native bytes to its original
        # build evidence. Fresh build mode additionally checks live outputs.
        for primitive in ([] if installed else json.loads((args.build / "native-components.json").read_text())):
            if primitive["kind"].startswith("builtin-"):
                if primitive["installed"]:
                    raise RuntimeError("Linked native implementation has an installation path")
                continue
            installed_artifact = prefix / primitive["installed"]
            built = Path(primitive["library"])
            if not installed_artifact.is_file() or installed_artifact.read_bytes() != built.read_bytes():
                raise RuntimeError(f"OTP-owned primitive differs from its built output: {installed_artifact}")
        fixture = work / "otp_product_probe.erl"
        shutil.copyfile(args.source / "tools/fixtures/otp_product_probe.erl", fixture)
        schema = args.source / "lib/asn1/examples/P-Record.asn"
        shutil.copyfile(schema, work / schema.name)
        diameter_sources = work / "diameter-example-sources"
        diameter_sources.mkdir()
        diameter_hashes = {}
        for module in ("client", "client_cb", "server", "server_cb"):
            original_source = args.source / "lib/diameter/examples/code" / (module + ".erl")
            copied_source = diameter_sources / original_source.name
            shutil.copyfile(original_source, copied_source)
            diameter_hashes[str(original_source.relative_to(args.source))] = hashlib.sha256(copied_source.read_bytes()).hexdigest()
        phase = "isolated" if args.bwrap else "relocated"
        (checks / f"diameter-fixture-inputs-{args.flavor}-{phase}.json").write_text(
            json.dumps(diameter_hashes, indent=2) + "\n")
        expression = (f'{{ok,otp_product_probe}}=compile:file({term(fixture)},[report_errors,report_warnings,{{outdir,{term(work)}}}]),'
                      f'{{module,otp_product_probe}}=code:load_abs({term(work / "otp_product_probe")}),'
                      f'otp_product_probe:run({term(prefix)},{args.flavor},{term(work)}).')
        environment = {k: v for k, v in os.environ.items()
                       if not k.startswith(("ERL_", "ERLC_", "ESCRIPT_", "LD_", "DYLD_")) and k not in {"BINDIR", "ROOTDIR", "EMU"}}
        environment["HOME"] = str(work)
        environment["PATH"] = str(prefix / "bin") + ":/usr/bin:/bin"
        if sys.platform == 'darwin':
            select_observer(args.build, work, environment)

        def invocation(command):
            if not args.bwrap:
                return command
            if sys.platform == 'darwin':
                return [*seatbelt(args, work, [args.source, args.build or args.prefix, args.sdk]), *command]
            isolation = [str(args.bwrap), "--unshare-user", "--unshare-pid", "--die-with-parent"]
            for system_path in ("/usr", "/bin", "/lib", "/lib64", "/etc"):
                if Path(system_path).exists():
                    isolation += ["--ro-bind", system_path, system_path]
            isolation += ["--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                          "--ro-bind", str(prefix), "/otp", "--bind", str(work), "/work",
                          "--chdir", "/work", "--setenv", "HOME", "/work",
                          "--setenv", "PATH", "/otp/bin:/usr/bin:/bin", "--"]
            return isolation + [str(arg).replace(str(prefix), "/otp").replace(str(work), "/work")
                                for arg in command]

        def execute(command, expected=0):
            process = subprocess.Popen(invocation(command), cwd=work, env=environment, text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)
            try:
                output, _ = process.communicate(timeout=60)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    output, _ = process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    output, _ = process.communicate()
                raise RuntimeError(f"{command}: timeout\n{output}")
            except BaseException:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.communicate()
                raise
            with (work / 'execution.log').open('a') as log:
                log.write(json.dumps(command, ensure_ascii=False) + '\n' + output + '\n')
            if process.returncode != expected:
                raise RuntimeError(f"{command}: exit {process.returncode}\n{output}")
            return output

        if args.bwrap:
            # No workspace mounts: these paths must be inaccessible, not merely
            # unused by the dynamic loader in one successful launch.
            for absent in (args.source, args.build or args.prefix, args.sdk):
                execute(["/bin/test", "!", "-e", str(absent.resolve())])

        source = work / "otp_compiler_probe.erl"
        shutil.copyfile(args.source / "tools/fixtures/otp_compiler_probe.erl", source)
        execute([str(prefix / "bin/erlc"), "-o", str(work), str(source)])
        execute([str(prefix / "bin/erl"), "+S1", "+A0", "+P65536", "+Q1024", "+sbtu",
                 "-noshell", "-pa", str(work), "-eval",
                 "1=erlang:system_info(schedulers),0=erlang:system_info(thread_pool_size),"
                 "unbound=erlang:system_info(scheduler_bind_type),"
                 "65536=erlang:system_info(process_limit),42=otp_compiler_probe:run(),halt()."])
        execute([str(prefix / "bin/erl"), "+S1", "-boot", "start_sasl", "-noshell", "-eval",
                 "[kernel,sasl,stdlib]=lists:sort([A || {A,_,_} <- application:which_applications()]),halt()."])
        resolver_output = execute([str(prefix / "bin/erl"), "+S1", "-noshell", "-eval",
            "{ok,{hostent,_,_,inet,4,Addresses}}=inet_gethost_native:gethostbyname(\"localhost\",inet),"
            "true=lists:member({127,0,0,1},Addresses),"
            "{ok,{hostent,_,_,inet,4,_}}=inet_gethost_native:gethostbyaddr({127,0,0,1}),"
            "ok=inet_gethost_native:control({debug_level,1}),"
            "{ok,_}=inet_gethost_native:gethostbyname(\"localhost\",inet),"
            "ok=inet_gethost_native:control({debug_level,0}),"
            "ok=inet_gethost_native:control(soft_restart),"
            "{ok,_}=inet_gethost_native:gethostbyname(\"localhost\",inet),"
            "{links,Links}=process_info(whereis(inet_gethost_native),links),"
            "[Port]=[P || P <- Links,is_port(P)],{name,Name}=erlang:port_info(Port,name),"
            "Helper=filename:join([code:root_dir(),\"erts-\"++erlang:system_info(version),\"bin\",\"inet_gethost\"]),"
            "true=lists:prefix(Helper,Name),io:format(\"native_resolver_passed~n\"),halt()."])
        if "native_resolver_passed\n" not in resolver_output or "(DEBUG):" not in resolver_output:
            raise RuntimeError(f"Native resolver or its diagnostics failed: {resolver_output}")
        mode = "isolated" if args.bwrap else "relocated"
        (checks / f"native-resolver-{mode}.json").write_text(json.dumps({
            "flavor": args.flavor, "mode": mode,
            "checks": ["native forward/reverse lookup", "debug control and output",
                       "soft restart", "product helper port origin"],
        }, indent=2) + "\n")
        for protocol, operation in (("tcp", "listen"), ("udp", "open")):
            diagnostics = execute([str(prefix / "bin/erl"), "+S1", "-noshell", "-eval",
                f"{{ok,P}}=gen_{protocol}:{operation}(0,[{{inet_backend,inet}},{{ip,{{127,0,0,1}}}},{{debug,true}}]),"
                f"{{ok,_}}=inet:sockname(P),ok=gen_{protocol}:close(P),"
                "io:format(\"native_driver_caller=~p~n\",[self()]),halt()."])
            # %T prints the calling process returned by driver_caller, not
            # the port. Match its actual PID in each protocol's diagnostics.
            caller = re.search(r"native_driver_caller=(<\d+\.\d+\.\d+>)", diagnostics)
            if not caller or not re.search(
                    r"INET-DRV-DBG\[\d+\]\[\d+," + re.escape(caller[1]) + r"\]", diagnostics):
                raise RuntimeError(f"Missing {protocol} caller term diagnostics: {diagnostics}")
        (checks / f"native-driver-diagnostics-{mode}.json").write_text(json.dumps({
            "flavor": args.flavor, "mode": mode, "protocols": ["tcp", "udp"],
            "formatter": "actual caller PID through public native %T",
        }, indent=2) + "\n")
        socket_expression = (
            "{ok,S}=socket:open(inet,dgram,udp),"
            "ok=socket:bind(S,#{family=>inet,addr=>{127,0,0,1},port=>0}),"
            "{ok,#{port:=P}}=socket:sockname(S),true=P>0,ok=socket:close(S),"
            "{ok,_}=net:getaddrinfo(\"localhost\",undefined),{ok,_}=net:getifaddrs(),"
            "{ok,Maps}=file:read_file(\"/proc/self/maps\"),"
            "Host=filename:join([code:root_dir(),\"erts-\"++erlang:system_info(version),\"bin\",\"beam.smp\"]),"
            "{ok,Host}=file:read_link(\"/proc/self/exe\"),"
            "true=binary:match(Maps,unicode:characters_to_binary(Host))=/=nomatch,"
            "nomatch=binary:match(Maps,<<\"libbeam.so\">>),"
            "io:format(\"product_socket_net_passed~n\"),halt().")
        if sys.platform == 'darwin':
            begin = socket_expression.index('{ok,Maps}=')
            end = socket_expression.index('io:format(')
            socket_expression = socket_expression[:begin] + identity_expression(args.build, work) + socket_expression[end:]
        socket_output = execute([str(prefix / "bin/erl"), "+S1", "-noshell", "-eval", socket_expression])
        if "product_socket_net_passed\n" not in socket_output:
            raise RuntimeError(f"OTP-owned socket/net activation failed: {socket_output}")
        (checks / f"native-socket-net-{mode}.json").write_text(json.dumps({
            "flavor": args.flavor, "mode": mode,
            "checks": ["UDP open/bind/name/close", "native address resolution", "native interface enumeration",
                       "linked socket/net behavior", "product executable origin", "no shared VM mapping"],
        }, indent=2) + "\n")
        escript = work / "command probe.escript"
        shutil.copyfile(args.source / "tools/fixtures/otp_command_probe.escript", escript)
        if execute([str(prefix / "bin/escript"), str(escript), "space arg", "λ", "+literal"]) != "escript_passed\n":
            raise RuntimeError("Unexpected escript output")
        ei_source = work / "ei_probe.c"
        shutil.copyfile(args.source / "tools/fixtures/ei_probe.c", ei_source)
        for library in ("ei", "ei_st"):
            client = work / f"{library}_probe"
            execute([args.cc, str(ei_source), "-I", str(prefix / "usr/include"),
                     str(prefix / f"usr/lib/lib{library}.a"),
                     *(["-pthread"] if library == "ei" else []), "-lm", "-o", str(client)])
            if execute([str(client)]) != "ei_passed\n":
                raise RuntimeError(f"Unexpected {library} client output")
        snmp = next((prefix / "lib").glob("snmp-*"))
        mib_out = work / "mib-output"
        mib_out.mkdir()
        execute([str(prefix / "bin/escript"), str(snmp / "bin/snmpc"),
                 "--o", str(mib_out), str(snmp / "mibs/OTP-SNMPEA-MIB.mib")])
        execute([str(prefix / "bin/erlc"), "-o", str(mib_out),
                 str(mib_out / "OTP-SNMPEA-MIB.bin")])
        if not (mib_out / "OTP-SNMPEA-MIB.hrl").is_file():
            raise RuntimeError("Installed SNMP compiler did not produce its header")
        # The retained converter's v1 output is an installed product input too.
        v1_mib = work / "OTP-SNMPEA-MIB.mib"
        shutil.copyfile(snmp / "mibs/v1/OTP-SNMPEA-MIB.mib.v1", v1_mib)
        execute([str(prefix / "bin/escript"), str(snmp / "bin/snmpc"),
                 "--o", str(mib_out), str(v1_mib)])
        diameter = prefix / "lib/diameter-2.7"
        dictionary_out = work / "dictionary-output"
        dictionary_out.mkdir()
        execute([str(prefix / "bin/escript"), str(diameter / "bin/diameterc"),
                 "--name", "otp_generated_dictionary", "-o", str(dictionary_out),
                 str(diameter / "src/dict/relay.dia")])
        execute([str(prefix / "bin/erlc"), "-o", str(dictionary_out),
                 str(dictionary_out / "otp_generated_dictionary.erl")])
        execute([str(prefix / "bin/erl"), "+S1", "-noshell", "-pa", str(dictionary_out),
                 "-eval", "4294967295=otp_generated_dictionary:id(),halt()."])
        for command_name in ("dialyzer", "typer"):
            version = execute([str(prefix / "bin" / command_name), "--version"])
            if "v6.0" not in version:
                raise RuntimeError(f"Unexpected {command_name} version: {version}")
        type_source = work / "command_type_probe.erl"
        type_source.write_text("-module(command_type_probe).\n-export([identity/1]).\n"
                               "identity(N) when is_integer(N) -> N.\n")
        execute([str(prefix / "bin/erlc"), "+debug_info", "-o", str(work), str(type_source)])
        plt = work / "command.plt"
        execute([str(prefix / "bin/dialyzer"), "--build_plt", "--output_plt", str(plt),
                 "-Wno_unknown", str(work / "command_type_probe.beam")])
        inferred = execute([str(prefix / "bin/typer"), "--plt", str(plt), str(type_source)])
        if "-spec identity(integer()) -> integer()." not in inferred:
            raise RuntimeError(f"Missing inferred integer signature: {inferred}")
        bad_source = work / "command_bad_type.erl"
        bad_source.write_text("-module(command_bad_type).\n-export([broken/0]).\n"
                              "broken() -> command_type_probe:identity(not_an_integer).\n")
        diagnostics = execute([str(prefix / "bin/dialyzer"), "--no_check_plt", "--plt", str(plt),
                               "-Wno_unknown", "--src", str(bad_source)], expected=2)
        if "will never return" not in diagnostics or "not_an_integer" not in diagnostics:
            raise RuntimeError(f"Missing Dialyzer call diagnostic: {diagnostics}")
        # Compile unchanged upstream extension fixtures using only installed
        # public headers. In isolation neither source nor SDK trees are visible.
        upstream_inputs = {}
        for relative in (
            "erts/emulator/test/nif_SUITE_data/nif_mod.1.c",
            "erts/emulator/test/nif_SUITE_data/nif_mod.c",
            "erts/emulator/test/nif_SUITE_data/nif_mod.h",
            "erts/emulator/test/nif_SUITE_data/nif_mod.erl",
            "erts/emulator/test/dirty_nif_SUITE_data/echo_drv.c",
        ):
            original_input = args.source / relative
            copied_input = work / original_input.name
            shutil.copyfile(original_input, copied_input)
            upstream_inputs[relative] = hashlib.sha256(copied_input.read_bytes()).hexdigest()
        for native_source, library, include in (
            ("nif_mod.1.c", "nif_mod.1.so", prefix / "usr/include"),
            ("echo_drv.c", "echo_drv.so", prefix / "erts-17.0/include"),
        ):
            execute([args.cc, "-fPIC", *(["-bundle", "-undefined", "dynamic_lookup"] if sys.platform == 'darwin' else ["-shared"]), "-I", str(include),
                     str(work / native_source), "-o", str(work / library)])
        execute([str(prefix / "bin/erlc"), "-o", str(work), str(work / "nif_mod.erl")])
        native_expression = (
            f'ok=nif_mod:load_nif_lib([{{data_dir,{term(work)}}}],1),'
            '1=nif_mod:lib_version(),1=nif_mod:lib_version_check(),'
            f'ok=erl_ddll:load_driver({term(work)},"echo_drv"),'
            'P=open_port({spawn_driver,"echo_drv"},[binary]),'
            'B = <<0,1,127,128,255>>,true=port_command(P,B),'
            'receive {P,{data,B}} -> ok after 5000 -> error(driver_timeout) end,'
            '{native,42}=erlang:port_call(P,0,{native,42}),true=port_close(P),'
            'ok=erl_ddll:unload_driver("echo_drv"),'
            'io:format("native_extensions_passed~n"),halt().')
        native_output = execute([str(prefix / "bin/erl"), "+S1", "-noshell", "-pa", str(work),
                                 "-eval", native_expression])
        if native_output != "native_extensions_passed\n":
            raise RuntimeError(f"Unexpected native extension output: {native_output}")
        mode = "isolated" if args.bwrap else "relocated"
        evidence = {"flavor": args.flavor, "mode": mode, "inputs": upstream_inputs,
                    "sdk": sdk_selection,
                    "installation_provenance_sha256": hashlib.sha256(args.provenance.read_bytes()).hexdigest() if installed else None,
                    "nif": "load and call", "driver": "load, output, call, close and unload"}
        (checks / f"native-extensions-{mode}.json").write_text(json.dumps(evidence, indent=2) + "\n")
        shell_check(invocation([str(prefix / "bin/erl"), "+S1"]), work, environment)
        output = execute([str(prefix / "bin/erl"), "-noshell", "-eval", expression])
        expected = f"OTP product passed: {args.flavor}, three boots"
        if expected not in output:
            raise RuntimeError(f"Missing product success marker: {output}")
        maps = (work / "maps").read_text()
        dyntrace = next((prefix / "lib").glob("runtime_tools-*/priv/lib/dyntrace.so"))
        # /proc/maps names the resolved file, not the application-owned alias.
        native_origin = dyntrace.resolve()
        if args.bwrap and sys.platform != "darwin":
            native_origin = Path("/otp") / native_origin.relative_to(prefix)
        if str(native_origin) not in maps:
            raise RuntimeError("Runtime Tools NIF did not load from the relocated product")
        if str(args.sdk.resolve()) in maps or str(original) in maps:
            raise RuntimeError("Product loaded a library outside its relocated runtime")
        (checks / f"asn1-{mode}.json").write_text(json.dumps({
            "flavor": args.flavor, "sdk": evidence["sdk"],
            "schema": "lib/asn1/examples/P-Record.asn",
            "sha256": hashlib.sha256(schema.read_bytes()).hexdigest(),
            "rules": ["ber", "per", "uper"], "boots": 3,
            "checks": ["compiler version", "compile", "encode/decode", "native origin"],
        }, indent=2) + "\n")
        print(output.strip())
        print("Source-built applications, native services, restart and relocated library origin passed.")
        print("Upstream erlc/escript launchers, typed startup options and installed EI clients passed.")
        print("Unchanged upstream NIF and driver fixtures compiled against installed public headers and executed.")
        print("Interactive OTP shell evaluation, bindings and normal halt passed.")
        print("ASN.1 BER/PER/UPER compilation and codec round trips passed on all three boots.")
        print("Public Key application startup, RSA signing and DER/PEM round trips passed on all three boots.")
        print("Mutually authenticated TLS 1.2/1.3 round trips passed on inet/socket backends on all three boots.")
        if args.bwrap:
            print("Workspace, original SDK and source/build trees were unavailable in the filesystem namespace.")


if __name__ == "__main__":
    main()
