#!/usr/bin/env python3
"""Exercise the real CMake graph only in disposable workspace/tmp source/builds."""
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
import tempfile
import time


OUTPUT_SUFFIXES = {
    ".beam", ".app", ".appup", ".erl", ".hrl", ".o", ".so", ".dylib",
    ".a", ".jar", ".class", ".stamp", ".boot", ".script", ".rel", ".bin",
    ".c", ".h", ".term", ".asn1db",
}
PROBE = "otp_build_graph_probe"


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def cache_values(path):
    result = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"([^/#][^:]*):[^=]+=(.*)$", line)
        if match:
            result[match[1]] = match[2]
    return result


def source_identity(source):
    value = hashlib.sha256()
    for path in sorted(source.rglob("*"), key=lambda item: os.fsencode(item.relative_to(source))):
        # Product guides and development records do not affect this build check.
        if path.relative_to(source).parts[0] == "docs":
            continue
        if path.is_symlink():
            record = [path.relative_to(source).as_posix(), "symlink", os.readlink(path)]
        elif path.is_file():
            record = [path.relative_to(source).as_posix(), "file", path.stat().st_mode & 0o777, digest(path)]
        else:
            continue
        value.update(json.dumps(record, ensure_ascii=True).encode() + b"\n")
    return value.hexdigest()


def snapshot(build):
    result = {}
    for path in build.rglob("*"):
        if path.is_file() and (path.suffix in OUTPUT_SUFFIXES or path.name == "build.term"):
            stat = path.stat()
            result[path.relative_to(build).as_posix()] = {
                "mtime_ns": stat.st_mtime_ns, "size": stat.st_size, "sha256": digest(path),
            }
    return result


def differences(before, after):
    return sorted(name for name in before.keys() | after.keys()
                  if before.get(name) != after.get(name))


class GraphChecks:
    def __init__(self, args, work, source, build):
        self.args, self.work, self.source, self.build = args, work, source, build
        self.steps = []
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("ERL_", "ERLC_", "LD_", "DYLD_"))
                    and key not in {"ROOTDIR", "BINDIR", "EMU", "PROGNAME"}}
        self.env.update(BEAM_SDK_ROOT=str(args.sdk), OPENSSL_ROOT_DIR=str(args.openssl),
                        OTP_WX_CONFIG=str(args.wx_config), JAVA_HOME=str(args.java_home),
                        ODBC_CONFIG=str(args.odbc_config), FLEX_EXECUTABLE=str(args.flex))

    def run(self, label, command, *, env=None):
        print(label, flush=True)
        log = self.work / (f"{len(self.steps) + 1:02d}-" + label + ".log")
        row = {"step": label, "command": [str(item) for item in command], "log": str(log)}
        self.steps.append(row)
        started = time.monotonic()
        with log.open("w") as stream:
            process = subprocess.Popen(command, cwd=self.source, env=self.env if env is None else env,
                                       stdout=stream, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                status = process.wait(timeout=self.args.timeout)
            except BaseException:
                with contextlib.suppress(ProcessLookupError):
                    os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    with contextlib.suppress(ProcessLookupError):
                        os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise
        row.update(exit_code=status, elapsed_seconds=round(time.monotonic() - started, 3))
        output = log.read_text(errors="replace", encoding="utf-8")
        row["output_tail"] = output[-4000:]
        if status:
            raise RuntimeError(f"{label} failed ({status}); {log}\n{output[-12000:]}")
        return output

    def build_all(self, label):
        return self.run(label, [self.args.cmake, "--build", str(self.build),
                                "--parallel", str(self.args.parallel)])

    def configure(self):
        command = [self.args.cmake, "--preset", self.args.preset,
                   "-S", str(self.source), "-B", str(self.build),
                   "-DCMAKE_INSTALL_PREFIX=" + str(self.work / "configured-install"),
                   "-DBEAM_SDK_ROOT=" + str(self.args.sdk),
                   "-DOPENSSL_ROOT_DIR=" + str(self.args.openssl),
                   "-DOTP_WX_CONFIG=" + str(self.args.wx_config),
                   "-DJAVA_HOME=" + str(self.args.java_home),
                   "-DODBC_CONFIG=" + str(self.args.odbc_config),
                   "-DFLEX_EXECUTABLE=" + str(self.args.flex),
                   *self.args.configure_arg]
        self.run("clean-configure", command)

    def verify_inputs(self):
        cache = cache_values(self.build / "CMakeCache.txt")
        expected = {
            "CMAKE_HOME_DIRECTORY": self.source, "BEAM_SDK_ROOT": self.args.sdk,
            "OPENSSL_ROOT_DIR": self.args.openssl, "OTP_WX_CONFIG": self.args.wx_config,
            "JAVA_HOME": self.args.java_home, "ODBC_CONFIG": self.args.odbc_config,
            "FLEX_EXECUTABLE": self.args.flex,
        }
        for key, path in expected.items():
            if Path(cache.get(key, "")).resolve() != path.resolve():
                raise RuntimeError(f"scratch cache {key} differs from explicit input {path}")
        if cache.get("CMAKE_GENERATOR") != "Ninja":
            raise RuntimeError("this graph check requires the supported Ninja generator")
        records = list((self.build / "lib").glob("*/ebin/build.term"))
        if len(records) != self.args.expected_apps:
            raise RuntimeError(f"expected {self.args.expected_apps} application records, found {len(records)}")
        self.cache = {key: cache.get(key) for key in [*expected, "CMAKE_BUILD_TYPE",
                     "CMAKE_C_COMPILER", "CMAKE_CXX_COMPILER", "CMAKE_OSX_DEPLOYMENT_TARGET",
                     "OTP_BEAM_FLAVOR"]}
        self.receipts = {name: (self.build / name).read_text(encoding="utf-8")
                         for name in ("sdk-selection.txt", "wx-selection.json")}
        for relative in ("bootstrap/seed", "bootstrap/source", "bootstrap-tools", "bootstrap-driver", "otp"):
            if (self.build / relative).exists():
                raise RuntimeError(f"obsolete build layout remains: {relative}")
        expected_compiler = json.dumps(str(self.build / "bootstrap/lib/compiler/ebin/compile.beam"))
        record_paths = "[" + ",".join(json.dumps(str(path)) for path in records) + "]"
        expression = (f"Expected={expected_compiler},Expected=code:which(compile),"
                      f"lists:foreach(fun(P)->{{ok,[R]}}=file:consult(P),"
                      f"Expected=maps:get(compiler,R) end,{record_paths}),"
                      'io:put_chars("bootstrap-compiler-origin-ok\\n"),halt(0).')
        output = self.run("compiler-origin", [str(self.build / "bootstrap/bin/erl"),
                          "+S", "2:2", "+SDcpu", "1", "+SDio", "1",
                          "-noshell", "-noinput", "-eval", expression])
        if "bootstrap-compiler-origin-ok" not in output:
            raise RuntimeError("bootstrap compiler origin was not established")

    def no_op(self):
        before = snapshot(self.build)
        output = self.build_all("no-op")
        changed = differences(before, snapshot(self.build))
        actions = [line for line in output.splitlines()
                   if re.match(r"^\[\d+/\d+\]", line)
                   and "Re-checking globbed directories" not in line]
        if changed or actions:
            raise RuntimeError(f"unchanged build executed work: {actions}; changed outputs: {changed[:30]}")

    def leaf_edit(self):
        before = snapshot(self.build)
        os.utime(self.source / "lib/tftp/src/tftp.erl", None)
        self.build_all("touch-tftp")
        after = snapshot(self.build)
        changed = differences(before, after)
        allowed_stamps = {"CMakeFiles/otp/stamps/otp_app_tftp.stamp",
                          "CMakeFiles/otp/stamps/otp_product_boot.stamp",
                          "CMakeFiles/otp/stamps/otp_local_boot.stamp",
                          "CMakeFiles/otp/stamps/otp_release_index.stamp",
                          "CMakeFiles/otp/stamps/otp_local_setup.stamp"}
        unexpected = [name for name in changed
                      if name not in allowed_stamps
                      and not name.startswith(("lib/tftp/", "bin/", "erts/start_scripts/"))]
        if unexpected or "CMakeFiles/otp/stamps/otp_app_tftp.stamp" not in changed:
            raise RuntimeError(f"leaf edit rebuilt unrelated outputs or missed TFTP: {unexpected[:30]}")
        self.steps[-1]["changed_outputs"] = changed

    def compiler_edit(self):
        before = snapshot(self.build)
        os.utime(self.source / "lib/compiler/src/compile.erl", None)
        self.build_all("touch-product-compiler")
        changed = differences(before, snapshot(self.build))
        allowed_stamps = {"CMakeFiles/otp/stamps/otp_app_compiler.stamp",
                          "CMakeFiles/otp/stamps/otp_product_boot.stamp",
                          "CMakeFiles/otp/stamps/otp_local_boot.stamp",
                          "CMakeFiles/otp/stamps/otp_release_index.stamp",
                          "CMakeFiles/otp/stamps/otp_local_setup.stamp"}
        unexpected = [name for name in changed if name not in allowed_stamps
                      and not name.startswith(("lib/compiler/", "bin/", "erts/start_scripts/"))]
        if unexpected or "CMakeFiles/otp/stamps/otp_app_compiler.stamp" not in changed:
            raise RuntimeError(f"product compiler edit changed the build compiler or unrelated applications: {unexpected[:30]}")
        self.steps[-1]["changed_outputs"] = changed

    def poisoned_environment(self):
        poison = self.work / "unselected-erl"
        poison.mkdir()
        for name in ("erl", "erlc", "beam", "beam.smp"):
            executable = poison / name
            executable.write_text("#!/bin/sh\necho ambient-runtime-executed >&2\nexit 99\n")
            executable.chmod(0o755)
        env = dict(self.env)
        env.update(PATH=str(poison) + os.pathsep + env.get("PATH", ""),
                   ERL_AFLAGS="-this_must_not_be_used", ERL_FLAGS="-this_must_not_be_used",
                   ERL_COMPILER_OPTIONS="[this_must_not_be_used]", ERL_LIBS=str(poison),
                   ERLC_EMULATOR=str(poison / "erl"), ERLC_USE_SERVER="yes",
                   ROOTDIR=str(poison), BINDIR=str(poison), EMU="unselected-beam", PROGNAME="unselected-erl")
        os.utime(self.source / "lib/tftp/src/tftp.erl", None)
        output = self.run("poisoned-environment", [self.args.cmake, "--build", str(self.build),
                          "--parallel", str(self.args.parallel)], env=env)
        if "ambient-runtime-executed" in output:
            raise RuntimeError("build executed an ambient runtime")

    def missing_output(self, label, path):
        if path.is_symlink() or not path.resolve().is_relative_to(self.build.resolve()):
            raise RuntimeError(f"recovery output must be a private build file: {path}")
        if not path.is_file():
            raise RuntimeError(f"recovery precondition missing: {path}")
        expected = digest(path)
        path.unlink()
        self.build_all(label)
        if not path.is_file() or digest(path) != expected:
            raise RuntimeError(f"build did not restore identical output: {path}")

    def install(self, label):
        prefix = self.work / label
        self.run(label, [self.args.cmake, "--install", str(self.build), "--prefix", str(prefix)])
        return prefix

    def module_selection(self):
        cmake = self.source / "lib/tftp/CMakeLists.txt"
        resource = self.source / "lib/tftp/src/tftp.app.src"
        module = self.source / f"lib/tftp/src/{PROBE}.erl"
        original_cmake, original_resource = cmake.read_text(encoding="utf-8"), resource.read_text(encoding="utf-8")
        if module.exists() or PROBE in original_cmake or PROBE in original_resource:
            raise RuntimeError("scratch source already contains graph probe")
        updated_cmake, count = re.subn(r"(?m)^(set\(_sources\s*)$",
            lambda match: match[0] + f'\n    "${{CMAKE_CURRENT_SOURCE_DIR}}/src/{PROBE}.erl"',
            original_cmake, count=1)
        if count != 1:
            raise RuntimeError("cannot find the explicit TFTP source declaration")
        updated_resource, count = re.subn(r"(\{modules,\s*\[)",
            lambda match: match[0] + PROBE + ",", original_resource, count=1)
        if count != 1:
            raise RuntimeError("cannot find the TFTP application module declaration")
        app_roots = [self.build / "lib/tftp"]
        if len(app_roots) != 1:
            raise RuntimeError("scratch TFTP output missing/ambiguous")
        staged = app_roots[0] / f"ebin/{PROBE}.beam"
        versions = (self.build / "CMakeFiles/otp/install/installed_application_versions").read_text(encoding="utf-8").splitlines()
        installed_names = [name for name in versions if name.startswith("tftp-")]
        if len(installed_names) != 1:
            raise RuntimeError("installed TFTP version missing/ambiguous")
        relative = Path("lib") / installed_names[0] / "ebin" / (PROBE + ".beam")
        try:
            module.write_text(f"-module({PROBE}).\n-export([value/0]).\nvalue() -> 42.\n")
            cmake.write_text(updated_cmake)
            resource.write_text(updated_resource)
            self.build_all("add-module")
            if not staged.is_file():
                raise RuntimeError("automatic reconfiguration did not compile the added module")
            installed = self.install("install-added") / relative
            if not installed.is_file() or digest(installed) != digest(staged):
                raise RuntimeError("added module was not installed from its declared output")
        finally:
            cmake.write_text(original_cmake)
            resource.write_text(original_resource)
            module.unlink(missing_ok=True)
        self.build_all("remove-module")
        if staged.exists() or PROBE in (app_roots[0] / "ebin/build.term").read_text(encoding="utf-8"):
            raise RuntimeError("removed explicit module left stale build output/metadata")
        installed = self.install("install-removed") / relative
        if installed.exists():
            raise RuntimeError("removed module remains in a fresh installation")

    def check(self):
        for relative in ("lib/tftp/CMakeLists.txt", "lib/tftp/src/tftp.app.src", "lib/tftp/src/tftp.erl"):
            path = self.source / relative
            if path.is_symlink() or not path.resolve().is_relative_to(self.source):
                raise RuntimeError(f"mutable fixture must be inside the untracked source copy: {path}")
        if not self.args.reuse_build:
            self.configure()
            self.build_all("clean-build")
        self.verify_inputs()
        self.no_op()
        self.leaf_edit()
        self.compiler_edit()
        self.poisoned_environment()
        self.missing_output("recover-parser", self.build / self.args.parser)
        beams = [self.build / "lib/tftp/ebin/tftp_binary.beam"]
        if len(beams) != 1:
            raise RuntimeError("scratch TFTP BEAM missing/ambiguous")
        self.missing_output("recover-beam", beams[0])
        self.module_selection()
        self.no_op()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="read-only original product source")
    parser.add_argument("--preset", required=True)
    for name in ("sdk", "openssl", "wx-config", "java-home", "odbc-config", "flex"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--cmake", default=shutil.which("cmake") or "cmake")
    parser.add_argument("--parallel", type=int, default=4)
    parser.add_argument("--timeout", type=float, default=3600, help="maximum seconds per command")
    parser.add_argument("--expected-apps", type=int, default=35)
    parser.add_argument("--parser", default="lib/edoc/src/edoc_parser.erl")
    parser.add_argument("--configure-arg", action="append", default=[])
    parser.add_argument("--scratch-source", type=Path)
    parser.add_argument("--scratch-build", type=Path)
    parser.add_argument("--reuse-build", action="store_true", help="verify a supplied completed build; do not claim a clean build")
    parser.add_argument("--keep-work", action="store_true")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--min-free-gib", type=float, default=4)
    args = parser.parse_args()
    args.source = args.source.resolve()
    scratch = args.source.parent / "tmp"
    scratch.mkdir(exist_ok=True)
    if bool(args.scratch_source) != bool(args.scratch_build):
        parser.error("--scratch-source and --scratch-build must be supplied together")
    if args.reuse_build and not args.scratch_build:
        parser.error("--reuse-build requires an explicit scratch source/build pair")
    if Path(args.parser).is_absolute() or ".." in Path(args.parser).parts:
        parser.error("--parser must be relative to the scratch build")
    for name in ("sdk", "openssl", "wx_config", "java_home", "odbc_config", "flex"):
        path = getattr(args, name)
        if not path.is_absolute() or not path.exists():
            parser.error(f"{name} must name an existing absolute input")
    if shutil.disk_usage(scratch).free < args.min_free_gib * 1024 ** 3:
        parser.error("insufficient free disk for a disposable product build")
    work = Path(tempfile.mkdtemp(prefix="otp-build-graph-", dir=scratch)).resolve()
    report = (args.report or scratch / (work.name + "-report.json")).resolve()
    if not report.is_relative_to(scratch.resolve()) or report == scratch.resolve():
        parser.error("--report must be a file inside this workspace's tmp/")
    if report.is_relative_to(work) and not args.keep_work:
        parser.error("a report inside the disposable work root requires --keep-work")
    owned_source = args.scratch_source is None
    if owned_source:
        source, build = work / "source with spaces", work / "build with spaces"
    else:
        source, build = args.scratch_source.resolve(), args.scratch_build.resolve()
        for path in (source, build):
            if not path.is_relative_to(scratch.resolve()) or path == scratch.resolve():
                parser.error("supplied source/build must be strictly inside this workspace's tmp/")
        tracked = subprocess.run(["git", "-C", str(source), "rev-parse", "--show-toplevel"],
                                 capture_output=True).returncode == 0
        if source == args.source or tracked or build.is_relative_to(source) or source.is_relative_to(build):
            parser.error("supply an untracked scratch source copy and a separate build directory")
    checks = GraphChecks(args, work, source, build)
    success = False
    result = {"source": str(args.source), "scratch_source": str(source), "scratch_build": str(build),
              "clean_build_requested": not args.reuse_build, "steps": checks.steps}
    def interrupted(signum, _frame):
        raise KeyboardInterrupt(f"interrupted by signal {signum}")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    try:
        if owned_source:
            ignored = shutil.ignore_patterns(".git", "build", "install", "__pycache__")
            def source_ignored(directory, names):
                return set(ignored(directory, names)) | ({"docs"} if Path(directory) == args.source else set())
            shutil.copytree(args.source, source, ignore=source_ignored)
        elif not args.reuse_build and build.exists() and any(build.iterdir()):
            raise RuntimeError("clean-build mode requires an empty supplied build directory")
        revision = subprocess.run(["git", "-C", str(args.source), "rev-parse", "HEAD"],
                                  capture_output=True, text=True)
        patch = subprocess.run(["git", "-C", str(args.source), "diff", "--binary", "HEAD"],
                               capture_output=True)
        result.update(source_revision=revision.stdout.strip(),
                      source_patch_sha256=hashlib.sha256(patch.stdout).hexdigest(),
                      source_tree_sha256=source_identity(source),
                      otp_version=(source / "OTP_VERSION").read_text(encoding="utf-8").strip(),
                      upstream_commit=(source / "UPSTREAM_COMMIT").read_text(encoding="utf-8").strip())
        checks.check()
        if source_identity(source) != result["source_tree_sha256"]:
            raise RuntimeError("graph checks did not restore the scratch source contents")
        result.update(status="passed", cache=checks.cache, receipts=checks.receipts)
        success = True
    except BaseException as error:
        result.update(status="failed", error=str(error))
        raise
    finally:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(result, indent=2) + "\n")
        if success and not args.keep_work:
            shutil.rmtree(work)
        else:
            print("Preserved graph work:", work, flush=True)
        print("Graph report:", report, flush=True)
    print("CMake build graph checks passed", flush=True)


if __name__ == "__main__":
    main()
