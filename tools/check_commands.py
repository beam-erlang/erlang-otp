#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise upstream launcher policy and local distribution in a fresh product."""
import argparse
import selectors
import hashlib
import json
import os
from pathlib import Path
from scratch import scratch
import signal
import shutil
import re
import socket
import subprocess
import time
import sys
from host_testing import work_root, owned_runtime_scope, owned_processes, stop_owned_processes
from check_start import root_discovery, isolated_chain


def term(value):
    return json.dumps(str(value), ensure_ascii=False)


def stop(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()


def kernel_poll_options(run, erl, work):
    expression = ('1=erlang:system_info(schedulers),'
                  '3=erlang:system_info(thread_pool_size),'
                  'io:format("~p~n",[{erlang:system_info(kernel_poll),'
                  'init:get_arguments(),init:get_plain_arguments()}]),halt().')
    command = [erl, "+S1", "+A3"]
    entry = ["-noshell", "-eval", expression]
    baseline = run([*command, *entry])
    for flags in (["+K", "true"], ["+Ktrue"], ["+K", "false"], ["+Kfalse"],
                  ["+K", "nonsense"], ["+Knonsense"], ["+K", ""],
                  ["+Ktrue", "+K", "false"], ["+K", "+S2"]):
        if run([*command, *flags, *entry]) != baseline:
            raise RuntimeError(f"Obsolete kernel-poll option changed startup: {flags}")
    if run([erl, "+S2", "+A1", "+Kfalse", "+S1", "+A3", "+Ktrue", *entry]) != baseline:
        raise RuntimeError("Obsolete kernel-poll option consumed an adjacent option")
    marker = work / "missing-kernel-poll-started"
    for flags in (["+K"], ["+K", "--"], ["+K", "-extra", "plain"]):
        output = run([*command, "-noshell", "-eval",
                      f'ok=file:write_file({term(marker)},<<"started">>),halt().', *flags],
                     expected=1)
        if marker.exists() or "Missing argument(s) for '+K'" not in output:
            raise RuntimeError("Missing kernel-poll value reached application startup")


def allocator_options(run, erl, work):
    allocators = "[binary_alloc,std_alloc,ets_alloc,eheap_alloc,ll_alloc,driver_alloc,fix_alloc,sl_alloc]"

    def expression(mode):
        expected = ("lists:member(A,[binary_alloc,driver_alloc])" if mode is None
                    else str(mode).lower())
        return (
            f'lists:foreach(fun(A)->Expected={expected},'
            'lists:foreach(fun({instance,_,Properties})->'
            'Expected=proplists:get_value(atags,proplists:get_value(options,Properties)) end,'
            f'erlang:system_info({{allocator,A}})) end,{allocators}),halt().')

    for flags, mode in (([], None), (["+Muatags", "true"], True),
                        (["+Muatagstrue"], True), (["+Muatags", "false"], False),
                        (["+Muatagsfalse"], False),
                        (["+Muatagstrue", "+Muatags", "false"], False)):
        run([erl, "+S1", *flags, "-noshell", "-eval", expression(mode)])
    # The ordinary launcher decides ordering; the host consumes its final argv.
    run([erl, "+S1", "+Muatags", "false", "-noshell", "-eval", expression(True)],
        {"ERL_AFLAGS": "+Muatagstrue", "ERL_FLAGS": "+Muatagsfalse",
         "ERL_ZFLAGS": "+Muatags true"})
    for mode in (True, False):
        marker = work / f"allocator-restart-{mode}"
        check = expression(mode).removesuffix("halt().")
        restart = (f'case file:read_file({term(marker)}) of '
                   f'{{error,enoent}}->ok=file:write_file({term(marker)},<<"restart">>),init:restart();'
                   '{ok,<<"restart">>}->halt() end.')
        run([erl, "+S1", "+Muatags", str(mode).lower(), "-noshell", "-eval", check + restart])
        if not marker.exists():
            raise RuntimeError("Allocator restart check did not execute")
    marker = work / "invalid-allocator-started"
    for flags in (["+Muatags", "invalid"], ["+Muatags"]):
        output = run([erl, "+S1", "-noshell", "-eval",
                      f'ok=file:write_file({term(marker)},<<"started">>),halt().', *flags],
                     expected=1)
        if marker.exists() or not output.strip():
            raise RuntimeError("Invalid allocator option reached application startup")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--cmake", required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--api-probe", type=Path, required=True)
    args = parser.parse_args()
    build = args.build.resolve()
    work = work_root(build, "commands") / str(time.time_ns())
    work.mkdir(parents=True)
    with scratch(work), owned_runtime_scope(build, work):
        prefix = work / "relocated OTP 日本"
        original = work / "original"
        subprocess.run([args.cmake, "--install", str(build), "--prefix", str(original)],
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(("ERL_", "ERLC_", "ESCRIPT_", "LD_", "DYLD_"))
               and k not in {"BINDIR", "ROOTDIR", "EMU", "PROGNAME"}}
        env.update(HOME=str(work), PATH=str(prefix / "bin") + ":/usr/bin:/bin")
        erl = str(prefix / "bin/erl")

        def run(command, extra_env=None, expected=0):
            process = subprocess.Popen(command, cwd=work, env=dict(env, **(extra_env or {})),
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, start_new_session=True)
            try:
                output, _ = process.communicate(timeout=60)
            except subprocess.TimeoutExpired:
                stop(process)
                raise RuntimeError(f"Command timed out: {command}")
            except BaseException:
                stop(process)
                raise
            with (work / "commands.log").open("a") as log:
                log.write(json.dumps(command) + "\n" + output + "\n")
            if process.returncode != expected:
                raise RuntimeError(f"Command returned {process.returncode}: {command}\n{output}")
            return output

        root_discovery(original, original, work, run)
        original.rename(prefix)
        root_discovery(prefix, original, work, run)
        chain = isolated_chain(prefix, work, run, build=build, source=args.source)
        kernel_poll_options(run, erl, work)
        allocator_options(run, erl, work)
        info = json.loads(run([str(args.api_probe.resolve())]))
        total = info["configured"] or 1
        active = (min(info["available"], info["quota"]) if info["available"] and info["quota"]
                  else info["available"] or info["online"] or total)
        expression = (f'{total}=erlang:system_info(schedulers),'
                      f'{active}=erlang:system_info(schedulers_online),'
                      f'{total}=erlang:system_info(dirty_cpu_schedulers),'
                      '10=erlang:system_info(dirty_io_schedulers),'
                      '3=erlang:system_info(thread_pool_size),'
                      '131072=erlang:system_info(port_limit),8192=erlang:system_info(ets_limit),'
                      '{fullsweep_after,17}=erlang:system_info(fullsweep_after),halt().')
        run([erl, "-noshell", "-eval", expression],
            {"ERL_THREAD_POOL_SIZE": "3", "ERL_FULLSWEEP_AFTER": "17",
             "ERL_MAX_PORTS": "131072", "ERL_MAX_ETS_TABLES": "8192"})
        # Darwin filesystem names remain UTF-8 in the C locale, as verified
        # against the pinned same-platform original.
        for locale, encoding in (("C.UTF-8", "utf8"), ("C", "utf8" if sys.platform == 'darwin' else "latin1")):
            run([erl, "+S1", "-noshell", "-eval", f'{encoding}=file:native_name_encoding(),halt().'],
                {"LC_ALL": locale})
        child = subprocess.Popen([erl, "+S1", "-noshell", "-eval",
                                  'io:format("SIGNAL_READY~n"),receive after infinity -> ok end.'],
                                 cwd=work, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 start_new_session=True)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(child.stdout, selectors.EVENT_READ)
                if not selector.select(30) or child.stdout.readline() != b"SIGNAL_READY\n":
                    raise RuntimeError("OTP signal probe did not become ready")
            child.send_signal(signal.SIGTERM)
            stdout, stderr = child.communicate(timeout=30)
            if child.returncode:
                raise RuntimeError(f"SIGTERM did not reach OTP shutdown: {stdout!r} {stderr!r}")
        finally:
            stop(child)

        if "emulator version 17.0" not in run([erl, "-version"]):
            raise RuntimeError("Missing OTP emulator version")
        nested = work / "nested args"
        nested.write_text('+K nonsense -order "nested value"\n')
        arguments = work / "top args"
        arguments.write_text(f'# retained launcher parses comments and nested files\n-args_file "{nested}"\n')
        expression = ('{ok,[["before value"],["command value"],["nested value"],'
                      '["middle value"],["after value"]]}=init:get_argument(order),'
                      '1=erlang:system_info(schedulers),'
                      'error=init:get_argument(\'K\'),'
                      '["+literal","space arg","+K","true","+Kfalse"]='
                      'init:get_plain_arguments(),halt().')
        run([erl, "-noshell", "-order", "command value", "-args_file", str(arguments),
             "-eval", expression, "-extra", "+literal", "space arg", "+K", "true", "+Kfalse"],
            {"ERL_OTP29_FLAGS": '+Ktrue', "ERL_AFLAGS": '+S1 +K false -order "before value"',
             "ERL_FLAGS": '+Knonsense -order "middle value"',
             "ERL_ZFLAGS": '+K true -order "after value"'})
        detached = work / "detached marker"
        run([erl, "+S1", "-detached", "-eval", f'ok=file:write_file({term(detached)},<<"ready">>),halt().'])
        deadline = time.monotonic() + 15
        while not detached.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        if not detached.exists() or detached.read_bytes() != b"ready":
            raise RuntimeError("Detached startup did not execute")

        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        env["ERL_EPMD_PORT"] = str(port)
        epmd = str(prefix / "bin/epmd")
        epmd_log = (work / "epmd.log").open("w")
        daemon = subprocess.Popen([epmd, "-port", str(port), "-address", "127.0.0.1"],
                                  cwd=work, env=env, stdout=epmd_log, stderr=subprocess.STDOUT,
                                  start_new_session=True)
        node = None
        try:
            deadline = time.monotonic() + 10
            while True:
                if daemon.poll() is not None:
                    raise RuntimeError(f"Private EPMD exited: {work / 'epmd.log'}")
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                        break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise RuntimeError("Private EPMD did not listen")
                    time.sleep(0.02)
            ready = work / "node name"
            name = "otp_candidate_" + str(os.getpid())
            cookie = "otp_command_acceptance"
            node_log = (work / "node.log").open("w")
            node = subprocess.Popen([erl, "+S1", "-sname", name + "@localhost", "-setcookie", cookie,
                                     "-start_epmd", "false", "-noshell", "-eval",
                                     f'ok=file:write_file({term(ready)},atom_to_binary(node())),receive after 60000 -> halt(2) end.'],
                                    cwd=work, env=env, stdout=node_log, stderr=subprocess.STDOUT,
                                    start_new_session=True)
            deadline = time.monotonic() + 15
            while not ready.exists():
                if node.poll() is not None or time.monotonic() >= deadline:
                    node_log.flush()
                    raise RuntimeError(f"Named node did not start: {(work / 'node.log').read_text()}")
                time.sleep(0.02)
            if name not in run([epmd, "-names"]):
                raise RuntimeError("Node is absent from private EPMD")
            if run([str(prefix / "bin/erl_call"), "-sname", name + "@localhost", "-c", cookie,
                    "-a", "erlang length [[a,b,c]]"]).strip() != "3":
                raise RuntimeError("EI distributed call failed")
            remote = ready.read_text()
            run([erl, "+S1", "-sname", name + "_peer@localhost", "-setcookie", cookie,
                 "-noshell", "-eval", f'N=list_to_atom({term(remote)}),pong=net_adm:ping(N),'
                 f'{term(prefix)}=rpc:call(N,code,root_dir,[]),ok=rpc:call(N,init,stop,[]),halt().'])
            node.wait(timeout=15)
            if node.returncode:
                raise RuntimeError(f"Named node exit: {node.returncode}")
            suites, logs = work / "ct-command-suites", work / "ct-command-logs"
            suites.mkdir()
            logs.mkdir()
            source_hashes = {}
            for relative in ("lib/stdlib/test/base64_SUITE.erl", "lib/common_test/test_server/ts_install_cth.erl"):
                original = args.source.resolve() / relative
                copied = suites / original.name
                shutil.copyfile(original, copied)
                assert original.read_bytes() == copied.read_bytes()
                source_hashes[relative] = hashlib.sha256(copied.read_bytes()).hexdigest()
            run([str(prefix / "bin/erlc"), "-o", str(suites),
                 *[str(p) for p in sorted(suites.glob("*.erl"))]])
            run([str(prefix / "bin/ct_run"), "-sname", name + "_ct@localhost",
                 "-dir", str(suites), "-suite", "base64_SUITE", "-no_auto_compile",
                 "-logdir", str(logs), "-erl_args", "+S1", "-noinput", "-pa", str(suites),
                 "-start_epmd", "false"])
            suite_logs = list(logs.rglob("suite.log"))
            if len(suite_logs) != 1:
                raise RuntimeError("Expected one native ct_run suite result")
            totals = dict(re.findall(r"^=(failed|successful|user_skipped|auto_skipped)\s+(\d+)$",
                                     suite_logs[0].read_text(), re.MULTILINE))
            if totals != {"failed": "0", "successful": "19", "user_skipped": "0", "auto_skipped": "0"}:
                raise RuntimeError(f"Native ct_run result: {totals}")
            record = {"sdk": json.loads((build / "sdk-selection.json").read_text()),
                      "ct_run": totals, "suite_input_sha256": source_hashes,
                      "start_chain": chain,
                      "checks": ["start-root-discovery", "start-chain", "kernel-poll-options", "allocator-options", "version", "environment-order", "nested-args-file", "literal-extra",
                                 "detached", "epmd-registration", "ei-rpc", "two-node-rpc", "native-ct-run"],
                      "failed": 0, "skipped": 0, "node": remote, "epmd_port": port}
            (work / "result.json").write_text(json.dumps(record, indent=2) + "\n")
            print("Environment/argument-file policy, detached startup, EPMD, EI call, two-node RPC and native ct_run passed.")
            print(f"Evidence: {work}")
        finally:
            if node is not None:
                stop(node)
                node_log.close()
            stop(daemon)
            epmd_log.close()
            if sys.platform == 'darwin':
                # The peer deliberately exercises automatic EPMD startup.
                # EPMD is a persistent daemon, so the fixture owns its shutdown
                # as well as the explicitly started foreground instance.
                automatic = owned_processes(work / 'host-observer', prefix)
                if any(Path(item['executable']).name != 'epmd' for item in automatic):
                    raise RuntimeError(f'Unexpected command processes remained: {automatic}')
                stop_owned_processes(work / 'host-observer', prefix)
                result = work / 'result.json'
                if result.exists():
                    record = json.loads(result.read_text())
                    record['automatic_epmd_cleanup'] = automatic
                    result.write_text(json.dumps(record, indent=2) + '\n')


if __name__ == "__main__":
    main()
