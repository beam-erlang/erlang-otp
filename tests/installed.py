#!/usr/bin/env python3
"""Exercise only a private installed OTP product, with bounded process cleanup."""
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
import socket
import subprocess
import sys
import tempfile
import time
from native_process import WINDOWS, ContainedProcess, command as native_command, program, stop_tree


def erl_string(value: str | Path) -> str:
    # Erlang accepts the JSON quoting used here for paths without control chars.
    return json.dumps(str(value), ensure_ascii=False)


class Runner:
    def __init__(self, args, work: Path):
        self.args, self.work = args, work
        self.log: list[str] = []
        self.wrapper: list[str] = []
        self.env = os.environ.copy()
        for key in list(self.env):
            if key.startswith(("ERL_", "LD_", "DYLD_")) or key in {
                "ROOTDIR", "BINDIR", "EMU", "PROGNAME", "EPMD_PORT",
                "BEAM_SDK_ROOT", "CMAKE_PREFIX_PATH", "RELEASE_ROOT", "RELDIR",
                "ERLC_EMULATOR", "ESCRIPT_EMULATOR", "ESCRIPT_NAME", "ERLC_SERVER_ID"}:
                self.env.pop(key, None)
        self.env["ERLC_USE_SERVER"] = "no"
        self.home = work / "home"
        self.home.mkdir()
        cookie = self.home / ".erlang.cookie"
        cookie.write_text("otp_private_test\n")
        cookie.chmod(0o400)
        self.env["HOME"] = str(self.home)
        # Exercise the native ODBC manager without consulting personal/system DSNs.
        for name in ("odbc.ini", "odbcinst.ini"):
            (self.home / name).write_text("")
        self.env["ODBCINI"] = str(self.home / "odbc.ini")
        self.env["ODBCSYSINI"] = str(self.home)
        self.env["ODBCINSTINI"] = "odbcinst.ini"
        self.cwd = work / "unrelated working directory"
        self.cwd.mkdir()
        self.temporary = work / "runtime temporary"
        self.temporary.mkdir()
        self.env["TMPDIR"] = str(self.temporary)
        for label, path in (("OTP source", Path(args.source) / "UPSTREAM_COMMIT"),
                            ("SDK selection", Path(args.build) / "sdk-selection.txt")):
            if path.is_file():
                self.log.append(label + ":\n" + path.read_text(encoding="utf-8"))
        self.sdk_selection = dict(line.split("=", 1) for line in
            (Path(args.build) / "sdk-selection.txt").read_text(encoding="utf-8").splitlines() if "=" in line)
        if self.sdk_selection.get("build_type") != args.build_type:
            raise RuntimeError("requested runtime build type differs from the SDK selection receipt")

    def run(self, command, *, timeout=90, env=None, expected=0, input_text=None):
        command = self.wrapper + native_command(command)
        self.log.append("$ " + repr(command))
        process = ContainedProcess(command, cwd=self.cwd,
            env=self.env if env is None else env,
            stdin=subprocess.PIPE if input_text is not None else subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            encoding="utf-8", errors="replace", start_new_session=True)
        try:
            output, _ = process.communicate(input=input_text, timeout=timeout)
        except BaseException:
            with contextlib.suppress(ProcessLookupError):
                stop_tree(process)
            output, _ = process.communicate()
            self.log.append(output[-200000:])
            raise
        finally:
            process.close_tree()
        self.log.append(output[-200000:])
        if process.returncode != expected:
            raise RuntimeError(f"command exited {process.returncode}, expected {expected}: {command!r}\n{output[-16000:]}")
        return output

    def install(self):
        prefix = self.work / "original installation"
        command = [self.args.cmake, "--install", self.args.build, "--prefix", prefix]
        if self.args.mode == "destdir":
            staging = self.work / "DESTDIR staging"
            env = dict(self.env, DESTDIR=str(staging))
            self.run(command, timeout=120, env=env)
            staged_prefix = staging / (str(prefix)[2:].lstrip("/\\") if WINDOWS else str(prefix).lstrip("/"))
            if not staged_prefix.is_dir() or prefix.exists():
                raise RuntimeError("DESTDIR installation escaped staging")
            staged_prefix.rename(prefix)
        else:
            self.run(command, timeout=120)
        if self.args.mode == "relocated":
            relocated = self.work / "relocated OTP λ with spaces"
            prefix.rename(relocated)
            if prefix.exists():
                raise RuntimeError("original prefix still exists")
            prefix = relocated
        root = prefix
        # Support the conventional Unix prefix as well as an OTP-root prefix.
        if not (root / f"erts-{self.args.erts_version}").is_dir():
            root = prefix / "lib" / "erlang"
        host_name = ('beam.debug.smp.dll' if self.args.build_type == 'Debug' else 'beam.smp.dll') if WINDOWS else 'beam.smp'
        if not (root / f"erts-{self.args.erts_version}" / "bin" / host_name).is_file():
            raise RuntimeError(f"installed emulator missing under {prefix}")
        self.root = root
        self.bin = root / "bin"
        self.ebin = self.work / "fixtures" / "ebin"
        self.ebin.mkdir(parents=True)
        self.native = self.work / "native"
        self.native.mkdir()
        self.env.update({
            "PATH": str(self.bin) + os.pathsep + (self.env['PATH'] if WINDOWS else "/usr/bin:/bin:/usr/sbin:/sbin"),
            "OTP_TEST_ROOT": str(root), "OTP_TEST_WORK": str(self.work),
            "OTP_TEST_NATIVE": str(self.native), "OTP_TEST_FLAVOR": self.args.flavor,
            "OTP_TEST_BUILD_TYPE": self.args.build_type,
            "OTP_TEST_APPS": ",".join(self.args.apps),
            "ERL_CRASH_DUMP": str(self.work / "erl_crash.dump"),
        })
        if self.args.mode == "installed":
            # Executing before reinstall populates macOS's vnode signature
            # cache. Replacing identical bytes in place used to SIGKILL erlc.
            commands = [program(self.bin / "erlc"), program(root / f"erts-{self.args.erts_version}/bin/erlc")]
            before = {}
            for executable in commands:
                self.run([executable, "-help"], expected=1)
                before[executable] = (hashlib.sha256(executable.read_bytes()).hexdigest(),
                                      executable.stat().st_ino)
            self.run(command, timeout=120)
            for executable in commands:
                digest, inode = before[executable]
                if hashlib.sha256(executable.read_bytes()).hexdigest() != digest:
                    raise RuntimeError("identical reinstall changed command content")
                if executable.stat().st_ino == inode:
                    raise RuntimeError("reinstall overwrote the executable inode")
                self.run([executable, "-help"], expected=1)
        self.check_closure()

    def check_closure(self):
        for path in self.root.rglob("*"):
            if path.is_symlink() and not path.resolve().is_relative_to(self.root):
                raise RuntimeError(f"installed symlink escapes OTP: {path}")
        host_name = ('beam.debug.smp.dll' if self.args.build_type == 'Debug' else 'beam.smp.dll') if WINDOWS else 'beam.smp'
        beam = self.root / f"erts-{self.args.erts_version}" / "bin" / host_name
        if self.args.build_type == "Debug" and not WINDOWS:
            alias = beam.parent / "erl_child_setup.debug"
            if not alias.is_symlink() or alias.readlink() != Path("erl_child_setup"):
                raise RuntimeError("installed Debug helper alias must be relative")
        if WINDOWS:
            dumpbin = Path(self.args.cc).parent / 'dumpbin.exe'
            if not dumpbin.is_file():
                raise RuntimeError('selected MSVC dumpbin is required for PE dependency validation')
            dependencies = self.run([dumpbin, '/nologo', '/dependents', beam])
        elif sys.platform == "darwin":
            dependencies = self.run(["/usr/bin/otool", "-L", beam])
        else:
            dependencies = self.run(["/usr/bin/ldd", beam])
        for line in dependencies.splitlines()[1:]:
            if "libbeam" in line or self.args.sdk in line or self.args.build in line:
                raise RuntimeError(f"emulator depends on external SDK/build artifact: {line}")
        for header in ("erl_nif.h", "erl_driver.h"):
            if not (self.root / "usr" / "include" / header).is_file():
                raise RuntimeError(f"missing installed public header {header}")
        self.check_preload_assets()

    def check_preload_assets(self):
        # Establish SDK acquisition before producer isolation. The runtime
        # inspection check below then uses only the private installed copies.
        erts = f"erts-{self.args.erts_version}"

        def inventory(root):
            if not root.is_dir():
                raise RuntimeError(f"missing preload asset directory: {root}")
            result = {}
            for path in root.rglob("*"):
                if path.is_symlink():
                    raise RuntimeError(f"preload asset is a symlink: {path}")
                if path.is_file():
                    result[path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
            if not result:
                raise RuntimeError(f"empty preload asset directory: {root}")
            return result

        for family in ("ebin", "src"):
            field = "preload_ebin" if family == "ebin" else "preload_source"
            expected = inventory(Path(self.sdk_selection[field]))
            if family == "ebin" and sum(name.endswith(".beam") for name in expected) != 22:
                raise RuntimeError("selected SDK does not contain 22 preload inspection modules")
            released = expected
            if family == "src":
                # The original OTP release ships 23 preload sources. These
                # additional SDK build inputs remain in the build-tree mirror.
                sdk_only = {"add_abstract_code", "erts.app.src", "zip_internal.hrl"}
                released = {name: digest for name, digest in expected.items() if name not in sdk_only}
                if len(released) != 23:
                    raise RuntimeError("selected SDK does not supply the original 23 preload release sources")
            built = Path(self.args.build) / "erts" / ("ebin" if family == "ebin" else "preloaded/src")
            for label, directory in (("build tree", built),
                                     ("installed product", self.root / "lib" / erts / family)):
                selected = expected if label == "build tree" else released
                if inventory(directory) != selected:
                    raise RuntimeError(f"{label} preload {family} inventory/content differs from the selected SDK")
            self.log.append(f"SDK preload {family} inventory/content matches build and release selections: "
                            + json.dumps({"build": expected, "release": released}, sort_keys=True))

    def erl(self, expression, *, timeout=90, distributed=False, extra=()):
        command = [self.bin / "erl", "+S", "2:2", "+SDcpu", "1", "+SDio", "1",
                   "-noshell", "-noinput", "-no_dot_erlang", "-pa", self.ebin]
        if distributed:
            command += ["-sname", f"otp_test_{os.getpid()}", "-setcookie", "otp_private_test"]
        command += list(extra)
        command += ["-eval", expression]
        return self.run(command, timeout=timeout)

    def compile(self, sources, output=None):
        self.run([self.bin / "erlc", "+debug_info", "-o", output or self.ebin,
                  *sources], timeout=120)

    def check_installed_sources(self):
        # These inspection outputs never enter the runtime code path. DSS's
        # original release source needs a header generated from its released
        # ASN.1 schema; compile the installed source, not the regenerated .erl.
        output = self.work / "source-check"
        output.mkdir()
        receipt = {"format": 1, "check": "installed-source-compilation",
                   "root": str(self.root), "status": "failed", "sources": [], "tools": {}}
        inputs = {}

        def record(path):
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            inputs[path] = digest
            return {"path": str(path), "sha256": digest}

        def installed(pattern):
            paths = list((self.root / "lib").glob(pattern))
            if len(paths) != 1 or not paths[0].is_file():
                raise RuntimeError(f"installed input missing/ambiguous: {pattern}")
            return paths[0]

        pairs = []
        try:
            receipt["tools"] = {
                "erlc": record(program(self.bin / "erlc")),
                "compiler": record(installed("compiler-*/ebin/compile.beam")),
                "asn1_compiler": record(installed("asn1-*/ebin/asn1ct.beam")),
            }
            for app, module in (("stdlib", "ms_transform"), ("compiler", "beam_opcodes"),
                                ("public_key", "DSS")):
                source = installed(f"{app}-*/src/{module}.erl")
                item = {"module": module, "source": record(source)}
                receipt["sources"].append(item)
                include = []
                if module == "DSS":
                    schema = source.parent.parent / "asn1" / "DSS.asn1"
                    item["schema"] = record(schema)
                    generated = output / "asn1"
                    generated.mkdir()
                    flags = ["-bber", "+der", "+noobj", "+asn1config"]
                    self.run([self.bin / "erlc", *flags, "-o", generated, schema], timeout=120)
                    header = generated / "DSS.hrl"
                    if not header.is_file() or not header.stat().st_size or (generated / "DSS.beam").exists():
                        raise RuntimeError("DSS header generation failed or unexpectedly compiled an object")
                    item["schema_options"] = flags
                    item["generated_header"] = {"path": str(header),
                        "sha256": hashlib.sha256(header.read_bytes()).hexdigest()}
                    include = ["-I", generated]
                self.run([self.bin / "erlc", "+debug_info", *include, "-o", output, source], timeout=120)
                beam = output / (module + ".beam")
                if not beam.is_file():
                    raise RuntimeError(f"installed source did not produce {module}.beam")
                item["beam"] = {"path": str(beam), "sha256": hashlib.sha256(beam.read_bytes()).hexdigest()}
                pairs.append("{" + erl_string(beam) + "," + erl_string(source) + "}")
            expression = ("lists:foreach(fun({Beam,Expected})->"
                "{ok,{_,[{compile_info,Info}]}}=beam_lib:chunks(Beam,[compile_info]),"
                "{source,Source}=lists:keyfind(source,1,Info),"
                "true=(filename:absname(Source)=:=filename:absname(Expected)) end,[" +
                ",".join(pairs) + "]),io:put_chars(\"otp-installed-sources-ok\\n\"),halt(0).")
            self.run([self.bin / "erl", "+S", "2:2", "+SDcpu", "1", "+SDio", "1",
                      "-noshell", "-noinput", "-no_dot_erlang", "-eval", expression])
            receipt["status"] = "passed"
        finally:
            changed = [str(path) for path, digest in inputs.items()
                       if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest]
            receipt["inputs_unchanged"] = not changed
            receipt["changed_inputs"] = changed
            if changed:
                receipt["status"] = "failed"
            self.log.append("Installed source inspection:\n" + json.dumps(receipt, indent=2, sort_keys=True))
            if changed:
                raise RuntimeError(f"installed source inspection changed its inputs: {changed}")
        return receipt

    def prepare_fixtures(self):
        fixtures = Path(self.args.source) / "tests" / "fixtures"
        self.compile(sorted(fixtures.glob("*.erl")))
        # Compile before producer isolation; the unchanged case bodies use only
        # the installed commands/libraries and private distribution settings.
        self.compile([Path(self.args.source) / "lib/erl_interface/test/erl_call_SUITE.erl"])
        cc = [self.args.cc, "-std=c11", "-fPIC", "-I", self.root / "usr" / "include"]
        if WINDOWS:
            runtime = '/MDd' if self.args.build_type == 'Debug' else '/MD'
            for name in ('otp_probe_nif', 'otp_probe_drv'):
                self.run([self.args.cc, '/nologo', '/LD', '/std:c11', runtime, '/D__WIN32__',
                          '/I' + str(self.root / 'usr/include'), fixtures / (name + '.c'),
                          '/Fe:' + str(self.native / (name + '.dll'))])
        if sys.platform == "darwin":
            cc += ["-bundle", "-undefined", "dynamic_lookup"]
        else:
            cc += ["-shared"]
        for name in (() if WINDOWS else ("otp_probe_nif", "otp_probe_drv")):
            # No libbeam, libei or private runtime include/link flags.
            self.run([*cc, fixtures / f"{name}.c", "-o", self.native / f"{name}.so"])
        if self.args.mode != "original-cases":
            self.java_classes = self.work / "java-classes"
            self.java_classes.mkdir()
            jars = list((self.root / "lib").glob("jinterface-*/priv/OtpErlang.jar"))
            if len(jars) != 1:
                raise RuntimeError("installed Jinterface JAR missing/ambiguous")
            self.java_jar = jars[0]
            self.run([self.args.javac, "-cp", self.java_jar, "-d", self.java_classes,
                      fixtures / "JinterfaceSmoke.java"])

    @contextlib.contextmanager
    def epmd(self):
        with socket.socket() as available:
            available.bind(("127.0.0.1", 0))
            port = available.getsockname()[1]
        previous = self.env.get("ERL_EPMD_PORT")
        self.env["ERL_EPMD_PORT"] = str(port)
        output = (self.work / "epmd.log").open("w")
        process = ContainedProcess([*self.wrapper, str(program(self.bin / "epmd")), "-port", str(port)],
            cwd=self.cwd, env=self.env, stdin=subprocess.DEVNULL,
            stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            deadline = time.monotonic() + 10
            while True:
                if process.poll() is not None:
                    raise RuntimeError("private epmd exited before readiness")
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=.2):
                        break
                except OSError:
                    if time.monotonic() > deadline:
                        raise RuntimeError("private epmd did not become ready")
                    time.sleep(.05)
            yield
        finally:
            if process.poll() is None:
                with contextlib.suppress(ProcessLookupError):
                    stop_tree(process, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                with contextlib.suppress(ProcessLookupError):
                        stop_tree(process)
                process.wait()
            output.close()
            self.log.append("Private epmd:\n" + (self.work / "epmd.log").read_text(encoding="utf-8")[-20000:])
            if previous is None:
                self.env.pop("ERL_EPMD_PORT", None)
            else:
                self.env["ERL_EPMD_PORT"] = previous

    def common_test(self, directory, suite, cases=None, *, distributed=False, expected=4):
        logdir = self.work / (suite + " logs")
        logdir.mkdir()
        options = (f"[{{dir,{erl_string(directory)}}},{{suite,{suite}}},"
                   f"{{logdir,{erl_string(logdir)}}},{{auto_compile,false}}")
        if cases:
            options += ",{testcase,[" + ",".join(cases) + "]}"
        options += "]"
        expression = (f"case ct:run_test({options}) of "
            f"{{{expected},0,{{0,0}}}} -> halt(0); "
            "Other -> io:format(\"unexpected CT result: ~p~n\",[Other]),halt(1) end.")
        try:
            self.erl(expression, timeout=240, distributed=distributed,
                     extra=("-pa", str(directory)))
        except BaseException:
            for log in logdir.rglob("suite.log"):
                self.log.append(log.name + ":\n" + log.read_text(errors="replace", encoding="utf-8")[-100000:])
            raise

    def smoke(self):
        output = self.erl("otp_probe:identity(),halt(0).")
        if "otp-identity-ok" not in output:
            raise RuntimeError("identity marker missing")
        self.run([self.bin / "erl", "-version"])
        shell = self.run([self.bin / "erl", "+S", "2:2", "+SDcpu", "1", "+SDio", "1",
                          "-no_dot_erlang"],
                         input_text='io:format("otp-shell-ok~n").\nq().\n')
        if "otp-shell-ok\nok" not in shell:
            raise RuntimeError("interactive shell did not evaluate the piped expression")
        escript = self.work / "literal arguments.escript"
        escript.write_text("#!/usr/bin/env escript\n%%! +S 2:2 +SDcpu 1 +SDio 1\nmain(Args) -> "
            "[\"space argument\",\"--literal\"] = Args, io:put_chars(\"otp-escript-ok\\n\").\n")
        output = self.run([self.bin / "escript", escript, "space argument", "--literal"])
        if "otp-escript-ok" not in output:
            raise RuntimeError("escript did not execute")
        if self.args.mode != "original-cases":
            self.expanded_applications()
        self.check_installed_sources()
        with self.epmd():
            self.erl("ok=erl_call_SUITE:smoke([]),"
                     "ok=erl_call_SUITE:unresolvable_hostname([]),halt(0).",
                     distributed=True)

    def isolate(self):
        if WINDOWS:
            return self.isolate_windows()
        source = Path(self.args.source).resolve()
        beam_source = source.parent / "beam-erlang"
        sdk = Path(self.args.sdk).resolve()
        build = Path(self.args.build).resolve()
        producers = sorted({p for p in (source, beam_source.resolve(), sdk, build) if p.is_dir()},
                           key=lambda p: len(p.parts))
        hidden = []
        for producer in producers:
            if not any(producer.is_relative_to(parent) for parent in hidden):
                hidden.append(producer)
        if any(self.root.is_relative_to(path) for path in hidden):
            raise RuntimeError("private installation must be outside isolated producer paths")
        if sys.platform == "darwin":
            sandbox = Path("/usr/bin/sandbox-exec")
            if not sandbox.is_file():
                raise RuntimeError("isolation blocked: macOS sandbox-exec is unavailable")
            profile = self.work / "installed.sb"
            rules = ["(version 1)", "(allow default)"]
            rules += [f"(deny file-read* (subpath {json.dumps(str(path))}))" for path in hidden]
            profile.write_text("\n".join(rules) + "\n")
            self.wrapper = [str(sandbox), "-f", str(profile)]
        else:
            landlock = Path(self.args.source) / "tests" / "landlock.py"
            if not landlock.is_file():
                raise RuntimeError("isolation helper missing: tests/landlock.py")
            probe = subprocess.run([sys.executable,str(landlock),"--check"],
                cwd=self.cwd, env=self.env, stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
            self.log.append("Landlock availability:\n" + probe.stdout)
            if probe.returncode == 0:
                self.wrapper = [sys.executable,str(landlock),"--work",str(self.work),"--"]
            elif probe.returncode == 77:
                bwrap = shutil.which("bwrap")
                if bwrap is None:
                    raise RuntimeError("isolation blocked: Landlock unavailable and bwrap not installed")
                self.wrapper = [bwrap, "--die-with-parent", "--unshare-user", "--unshare-pid",
                    "--ro-bind", "/", "/", "--dev-bind", "/dev", "/dev", "--proc", "/proc",
                    "--bind", str(self.work), str(self.work)]
                for path in hidden:
                    self.wrapper += ["--tmpfs", str(path)]
                self.wrapper += ["--"]
            else:
                raise RuntimeError(f"Landlock availability probe failed unexpectedly ({probe.returncode}):\n{probe.stdout}")
        archive = Path(self.sdk_selection["runtime_archive"]).resolve()
        if not archive.is_relative_to(sdk):
            raise RuntimeError("selected runtime archive is outside the isolated SDK")
        candidates = [source / "OTP_VERSION", beam_source / "CMakeLists.txt",
                      archive, build / "CMakeCache.txt"]
        for path in candidates:
            if path == beam_source / "CMakeLists.txt" and not path.exists():
                self.log.append(f"BEAM source already absent: {path}")
            elif not path.is_file():
                raise RuntimeError(f"isolation precondition missing producer input: {path}")
        paths = "[" + ",".join(erl_string(p) for p in candidates) + "]"
        self.erl("lists:foreach(fun(P) -> case file:read_file(P) of "
                 "{error,eacces}->ok; {error,eperm}->ok; {error,enoent}->ok; "
                 "_ -> error({producer_visible,P}) end end," + paths + "),halt(0).")

    def isolate_windows(self):
        """Build private producers, then remove them before exercising the product.

        This avoids changing ACLs or renaming another job's source/SDK trees.
        The candidate is compiled from these exact private origins, so their
        removal tests real producer independence rather than PATH ordering.
        """
        if shutil.disk_usage(self.work).free < 4 * 1024**3:
            raise RuntimeError('Windows producer-independence build needs at least 4 GiB free')
        source, sdk, build = (self.work / name for name in ('private-source', 'private-sdk', 'private-build'))
        original_source, original_sdk = Path(self.args.source).resolve(), Path(self.args.sdk).resolve()
        shutil.copytree(original_source, source, ignore=shutil.ignore_patterns('.git', 'build', 'install', '__pycache__'))
        shutil.copytree(original_sdk, sdk)
        cache = {}
        for line in (Path(self.args.build) / 'CMakeCache.txt').read_text(encoding="utf-8").splitlines():
            match = re.match(r'([^/#][^:]*):[^=]+=(.*)$', line)
            if match:cache[match[1]]=match[2]
        configure = [self.args.cmake, '-S', source, '-B', build, '-G', 'Ninja',
                     '-DBEAM_SDK_ROOT=' + str(sdk), '-DBUILD_TESTING=OFF',
                     '-DCMAKE_BUILD_TYPE=' + self.args.build_type,
                     '-DOTP_BEAM_FLAVOR=' + self.args.flavor]
        selectors = ('CMAKE_C_COMPILER', 'CMAKE_CXX_COMPILER', 'CMAKE_MAKE_PROGRAM',
                     'CMAKE_MSVC_RUNTIME_LIBRARY', 'OPENSSL_ROOT_DIR', 'OPENSSL_INCLUDE_DIR',
                     'OPENSSL_CRYPTO_LIBRARY', 'OPENSSL_SSL_LIBRARY', 'OPENSSL_USE_STATIC_LIBS', 'OTP_WX_ROOT', 'OTP_WX_LIB_DIR',
                     'wxWidgets_ROOT_DIR', 'wxWidgets_LIB_DIR', 'wxWidgets_CONFIGURATION',
                     'JAVA_HOME', 'FLEX_EXECUTABLE', 'PERL_EXECUTABLE')
        for key in selectors:
            if cache.get(key) and not cache[key].endswith('-NOTFOUND'):
                configure.append('-D' + key + '=' + cache[key])
        self.run(configure, timeout=180)
        self.run([self.args.cmake, '--build', build, '--parallel', '3'], timeout=1200)
        prefix = self.work / 'producer-independent OTP λ'
        self.run([self.args.cmake, '--install', build, '--prefix', prefix], timeout=180)
        selection = (build / 'sdk-selection.txt').read_text(encoding="utf-8")
        values = dict(line.split('=',1) for line in selection.splitlines() if '=' in line)
        if Path(values['prefix']).resolve() != sdk.resolve():
            raise RuntimeError('private candidate was not compiled from its selected private SDK')
        runtime = Path(values['runtime_archive']).resolve()
        if not runtime.is_relative_to(sdk.resolve()):
            raise RuntimeError('private candidate used an unowned runtime archive')
        originals = (str(original_source), str(original_sdk), str(Path(self.args.build).resolve()))
        if any(value in selection for value in originals):
            raise RuntimeError('private build receipt retains an original producer selection')
        receipt = {'mechanism': 'build from private origins; delete those origins before execution',
                   'sdk_selection': values, 'deleted_producers': [str(path) for path in (source,sdk,build)],
                   'installed_prefix': str(prefix), 'original_producer_paths_selected': False}
        for producer in (source, sdk, build):
            if not producer.resolve().is_relative_to(self.work.resolve()):
                raise RuntimeError('private producer cleanup escapes the test workspace')
            shutil.rmtree(producer)
        self.root, self.bin = prefix, prefix / 'bin'
        self.env['OTP_TEST_ROOT'] = str(prefix)
        # Keep selected compiler-runtime search paths but remove every original
        # or deleted producer directory, including the previous private install.
        forbidden = (original_source, original_sdk, Path(self.args.build).resolve(),
                     self.work / 'original installation', source, sdk, build)
        paths = [str(self.bin)]
        for item in self.env['PATH'].split(os.pathsep):
            if item and not any(Path(item).resolve().is_relative_to(path.resolve()) for path in forbidden):
                paths.append(item)
        self.env['PATH'] = os.pathsep.join(dict.fromkeys(paths))
        probes = [source/'OTP_VERSION', runtime, build/'CMakeCache.txt']
        self.erl('lists:foreach(fun(P)->{error,enoent}=file:read_file(P) end,[' +
                 ','.join(erl_string(path) for path in probes) + ']),halt(0).')
        receipt['deleted_producers_unreadable'] = True
        (self.work / 'isolation-receipt.json').write_text(json.dumps(receipt,indent=2))
        self.log.append('Windows isolation receipt:\n' + json.dumps(receipt,indent=2))
        self.check_closure()

    def expanded_applications(self):
        output = self.erl("otp_product_probe:run(),halt(0).", timeout=180)
        if "otp-product-applications-ok" not in output:
            raise RuntimeError("expanded application checks did not finish")
        dialyzer = list((self.root / "lib").glob("dialyzer-*"))
        if len(dialyzer) != 1:
            raise RuntimeError("installed Dialyzer application missing/ambiguous")
        version = dialyzer[0].name[len("dialyzer-"):]
        for command in ("dialyzer", "typer"):
            output = self.run([self.bin / command, "--version"])
            if version not in output:
                raise RuntimeError(f"installed {command} did not report its selected version")
        edoc = list((self.root / "lib").glob("edoc-*/bin/edoc"))
        if len(edoc) != 1 or not os.access(edoc[0], os.X_OK):
            raise RuntimeError("installed EDoc command missing/ambiguous/not executable")
        self.run([self.bin / "escript", edoc[0]])
        output = self.run([self.args.java, "-cp",
                          str(self.java_classes) + os.pathsep + str(self.java_jar),
                          "JinterfaceSmoke"])
        if "otp-jinterface-ok" not in output:
            raise RuntimeError("installed Jinterface check did not finish")

    def full(self):
        self.smoke()
        # Cover's HTML output consumes a shipped runtime CSS asset, independently
        # of optional Emacs or documentation-generation tools.
        cover_source = self.work / "otp_cover_asset.erl"
        cover_source.write_text("-module(otp_cover_asset).\n-export([run/0]).\nrun() -> ok.\n")
        cover_output = self.work / "coverage report.html"
        self.erl("{ok,_}=cover:start(),{ok,otp_cover_asset}=cover:compile_module(" +
            erl_string(cover_source) + "),ok=otp_cover_asset:run(),{ok,_}=cover:analyse_to_file("
            "otp_cover_asset," + erl_string(cover_output) + ",[html]),"
            "{ok,Html}=file:read_file(" + erl_string(cover_output) + "),"
            "{ok,Css}=file:read_file(filename:join(code:priv_dir(tools),\"styles.css\")),"
            "true=binary:match(Html,Css)=/=nomatch,ok=cover:stop(),halt(0).")
        self.erl("ok=eunit:test(otp_probe_tests,[verbose]),halt(0).")
        self.common_test(self.ebin, "otp_distribution_SUITE")
        output = self.erl("otp_probe:restart().", timeout=60)
        if "otp-restart-ok" not in output:
            raise RuntimeError("init:restart did not rerun startup")
        with self.epmd():
            self.erl("otp_probe:peer(),halt(0).", distributed=True)
        self.erl("otp_probe:release(),halt(0).")
        output = self.erl('io:put_chars("otp-release-boot-ok\\n"),halt(0).',
                          extra=("-boot", str(self.work / "otp_probe")))
        if "otp-release-boot-ok" not in output:
            raise RuntimeError("generated release boot failed")

    def original_cases(self):
        source = Path(self.args.source)
        helper_sources = [source / "lib/common_test/test_server/ts_install_cth.erl",
            source / "lib/compiler/test/test_lib.erl",
            source / "erts/emulator/test/erts_test_utils.erl"]
        self.compile(helper_sources)
        selections = [
            ("lib/compiler/test", "compile_SUITE", ["file_1", "forms_2", "binary", "makedep"]),
            ("erts/emulator/test", "time_SUITE", ["time_warp_modes"]),
            ("lib/stdlib/test", "timer_simple_SUITE", ["send_after1", "send_after_invalid_args", "cancel1"]),
            ("lib/erl_interface/test", "erl_call_SUITE", ["smoke", "unresolvable_hostname"]),
        ]
        digests = {}
        with self.epmd():
            for relative, suite, cases in selections:
                original = source / relative / (suite + ".erl")
                directory = self.work / "original-cases" / suite
                directory.mkdir(parents=True)
                copied = directory / original.name
                shutil.copy2(original, copied)
                digests[str(original)] = hashlib.sha256(original.read_bytes()).hexdigest()
                data = original.with_name(suite + "_data")
                if data.is_dir():
                    shutil.copytree(data, directory / data.name, symlinks=True)
                else:
                    (directory / (suite + "_data")).mkdir()
                self.compile([copied], output=directory)
                self.common_test(directory, suite, cases, distributed=True, expected=len(cases))
                if hashlib.sha256(original.read_bytes()).hexdigest() != digests[str(original)]:
                    raise RuntimeError(f"original suite changed during test: {original}")
        self.log.append("Unchanged original suite SHA-256: " + json.dumps(digests, sort_keys=True))

    def cleanup(self):
        if not hasattr(self,"root"):
            return
        if WINDOWS:
            self.log.append('Cleanup: every native controller and EPMD used a kill-on-close Job Object')
            return
        marker = str(self.root)

        def owned_processes():
            listing = subprocess.run(["/bin/ps","-axo","pid=,command="],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
            if listing.returncode:
                raise RuntimeError("cannot verify private runtime process cleanup")
            found = []
            for line in listing.stdout.splitlines():
                fields = line.strip().split(None,1)
                if len(fields) == 2 and marker in fields[1] and any(
                        name in fields[1] for name in ("beam.smp","beam.debug.smp","epmd","inet_gethost","erl_child_setup")):
                    found.append(int(fields[0]))
            return found

        remaining = owned_processes()
        for sig in (signal.SIGTERM,signal.SIGKILL):
            for pid in remaining:
                with contextlib.suppress(ProcessLookupError):
                    os.kill(pid,sig)
            deadline = time.monotonic()+3
            while remaining and time.monotonic() < deadline:
                time.sleep(.05)
                remaining = owned_processes()
            if not remaining:
                break
        if remaining:
            raise RuntimeError(f"private runtime processes survived cleanup: {remaining}")
        self.log.append("Cleanup: no runtime processes refer to the disposable prefix")


def main():
    def interrupted(signum, _frame):
        raise KeyboardInterrupt(f"interrupted by signal {signum}")

    signal.signal(signal.SIGTERM, interrupted)
    if hasattr(signal, 'SIGHUP'):
        signal.signal(signal.SIGHUP, interrupted)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["installed", "destdir", "relocated", "isolated", "original-cases"], required=True)
    for name in ("source", "build", "cmake", "cc", "erts-version", "flavor", "sdk", "java", "javac"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--build-type", choices=("Release", "Debug"), default="Release")
    parser.add_argument("--apps", nargs="+", required=True)
    args = parser.parse_args()
    scratch = Path(args.source).parent / "tmp"
    scratch.mkdir(exist_ok=True)
    runner = None
    try:
        with tempfile.TemporaryDirectory(prefix=f"otp-{args.mode}-", dir=scratch) as temporary:
            runner = Runner(args, Path(temporary))
            try:
                runner.install()
                runner.prepare_fixtures()
                if args.mode == "isolated":
                    runner.isolate()
                if args.mode == "original-cases":
                    runner.original_cases()
                elif args.mode == "destdir":
                    runner.smoke()
                else:
                    runner.full()
            finally:
                runner.cleanup()
    finally:
        if runner is not None:
            logs = Path(args.build) / "tests" / "logs"
            logs.mkdir(parents=True, exist_ok=True)
            (logs / (args.mode + ".log")).write_text("\n".join(runner.log)[-2000000:])
    print(f"otp-{args.mode}: passed; disposable installation and fixtures removed")


if __name__ == "__main__":
    main()
