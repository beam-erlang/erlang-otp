#!/usr/bin/env python3
"""Check native compiler/SDK compatibility without selecting a preset."""
import argparse
from pathlib import Path
import platform
import subprocess
import tempfile

from sdk_selection import cmake_quote, sdk_variant


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "cmake", "sdk", "flavor", "cc", "cxx"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--build-type", choices=("Release", "Debug"), default="Release")
    args = parser.parse_args()
    source = Path(args.source).resolve()
    sdk = Path(args.sdk).resolve()
    scratch = source.parent / "tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="otp-native-architecture-", dir=scratch) as temporary:
        root = Path(temporary)
        project = root / "source"
        project.mkdir()
        release = (source / "OTP_VERSION").read_text(encoding="utf-8").strip()
        (project / "CMakeLists.txt").write_text("\n".join([
            "cmake_minimum_required(VERSION 3.25)",
            'if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")',
            '    set(CMAKE_OSX_DEPLOYMENT_TARGET "26.0" CACHE STRING "Minimum macOS version")',
            "endif()",
            f"project(native_architecture VERSION {release} LANGUAGES C CXX)",
            # These fixture-only overrides simulate an incompatible host or
            # cross toolchain after CMake has identified the real compilers.
            "if(TEST_HOST_PROCESSOR)",
            '    set(CMAKE_HOST_SYSTEM_PROCESSOR "${TEST_HOST_PROCESSOR}")',
            "endif()",
            "if(TEST_CROSSCOMPILING)",
            "    set(CMAKE_CROSSCOMPILING TRUE)",
            "endif()",
            "set(PROJECT_SOURCE_DIR " + cmake_quote(source) + ")",
            "include(" + cmake_quote(source / "cmake/OTPVersions.cmake") + ")",
            "otp_application_version(erts OTP_ERTS_VERSION)",
            "include(" + cmake_quote(source / "cmake/SDKDependency.cmake") + ")",
            "",
        ]))

        def configure(name, diagnostics=(), selected=sdk, generator="Ninja", **settings):
            # Reuse the accepted build for flag changes, so failures must come
            # from OTP's validation rather than initial compiler identification.
            build = root / name
            values = {
                "BEAM_SDK_ROOT": selected,
                "OTP_BEAM_FLAVOR": args.flavor,
                "CMAKE_C_COMPILER": args.cc,
                "CMAKE_CXX_COMPILER": args.cxx,
                "CMAKE_BUILD_TYPE": args.build_type,
                "CMAKE_C_FLAGS": "",
                "CMAKE_CXX_FLAGS": "",
                "CMAKE_C_FLAGS_RELEASE": "",
                "CMAKE_CXX_FLAGS_RELEASE": "",
                "CMAKE_C_FLAGS_DEBUG": "",
                "CMAKE_CXX_FLAGS_DEBUG": "",
                "TEST_HOST_PROCESSOR": "",
                "TEST_CROSSCOMPILING": "",
                **settings,
            }
            result = subprocess.run([
                args.cmake, "-S", str(project), "-B", str(build), "-G", generator,
                *(f"-D{key}={value}" for key, value in values.items()),
            ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=45)
            output = " ".join(result.stdout.split())
            if diagnostics:
                if result.returncode == 0:
                    raise RuntimeError(f"{name} unexpectedly configured with {settings}")
                if any(diagnostic not in output for diagnostic in diagnostics):
                    raise RuntimeError(f"{name} failed without its expected diagnostic:\n{result.stdout}")
                print(f"{name}: correctly rejected {settings}")
                return
            if result.returncode:
                raise RuntimeError(f"{name} failed:\n{result.stdout}")
            print(f"{name}: correctly accepted {settings}")
            return dict(line.split("=", 1) for line in
                        (build / "sdk-selection.txt").read_text(encoding="utf-8").splitlines())

        receipt = configure("native")
        sdk_arch = receipt["architecture"]
        opposite_processor = "x86_64" if sdk_arch == "arm" else "arm64"
        opposite_sdk_arch = "x86" if sdk_arch == "arm" else "arm"
        if platform.system() == "Darwin":
            mismatch_flags = "-arch " + opposite_processor
            print("Compiler mismatches use actual alternate macOS architecture flags")
        elif sdk_arch == "x86":
            mismatch_flags = "-m32"
            print("Compiler mismatches use an actual 32-bit x86 target")
        else:
            # Native AArch64 compilers do not all support a second target ABI.
            # Simulate the missing target macros while still running both real
            # compilers and the production compatibility probe.
            mismatch_flags = "-U__aarch64__ -U_M_ARM64"
            print("Compiler mismatches simulate an unsupported target by removing ARM64 macros")

        compiler_diagnostic = ["Selected SDK requires native 64-bit", "C and C++ compiler targets"]
        for flag in ("CMAKE_C_FLAGS", "CMAKE_CXX_FLAGS", "CMAKE_CXX_FLAGS_" + args.build_type.upper()):
            configure("native", compiler_diagnostic, **{flag: mismatch_flags})
            configure("native")

        configure("native", ["Selected SDK requires native", "CMAKE_HOST_SYSTEM_PROCESSOR"],
                  TEST_HOST_PROCESSOR=opposite_processor)
        configure("native", ["The core OTP build requires a native host and target"],
                  TEST_CROSSCOMPILING="TRUE")
        configure("native")

        selected = sdk_variant(sdk, root / "opposite-sdk", ARCHITECTURE=opposite_sdk_arch)
        configure("native", ["SDK architecture", "does not match"], selected=selected)
        configure("native")

        configure("multi", ["single-config"], generator="Ninja Multi-Config",
                  CMAKE_CONFIGURATION_TYPES="Debug;Release")
        configure("custom-multi", ["single-config"], generator="Ninja Multi-Config",
                  CMAKE_CONFIGURATION_TYPES="Debug;ArchitectureCheck")
        configure("unsupported-single", ["Release", "Debug"], CMAKE_BUILD_TYPE="ArchitectureCheck")


if __name__ == "__main__":
    main()
