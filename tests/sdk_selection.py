#!/usr/bin/env python3
"""Check installed SDK configuration and exact release selection."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def cmake_quote(value):
    return "[==[" + str(value) + "]==]"


def sdk_variant(sdk, destination, **metadata):
    """Copy a contained SDK fixture and edit only independent metadata.

    Archives are immutable hardlinks where available; package code and
    manifests are real copies. No fixture refers outside its installed prefix.
    """
    def copy_file(source, target):
        if Path(source).suffix == ".a":
            try:
                os.link(source, target)
                return target
            except OSError:
                pass
        return shutil.copy2(source, target)

    shutil.copytree(sdk, destination, symlinks=True, copy_function=copy_file)
    path = destination / "manifest.json"
    value = json.loads(path.read_text(encoding="utf-8"))
    for field, replacement in metadata.items():
        field = field.lower()
        if replacement is None:
            value.pop(field, None)
        else:
            value[field] = replacement
    path.write_text(json.dumps(value, indent=2) + "\n")
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "cmake", "sdk", "flavor"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--build-type", choices=("Release", "Debug"), default="Release")
    args = parser.parse_args()
    source, sdk = Path(args.source).resolve(), Path(args.sdk).resolve()
    manifest = json.loads((sdk / "manifest.json").read_text(encoding="utf-8"))
    scratch = source.parent / "tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="otp-sdk-selection-", dir=scratch) as temporary:
        root = Path(temporary)
        project = root / "source"
        project.mkdir()
        release = (source / "OTP_VERSION").read_text(encoding="utf-8").strip()
        (project / "CMakeLists.txt").write_text("\n".join([
            "cmake_minimum_required(VERSION 3.25)",
            'if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")',
            '    set(CMAKE_OSX_DEPLOYMENT_TARGET "26.0" CACHE STRING "Minimum macOS version")',
            "endif()",
            f"project(sdk_selection VERSION {release} LANGUAGES C CXX)",
            "set(PROJECT_SOURCE_DIR " + cmake_quote(source) + ")",
            "include(" + cmake_quote(source / "cmake/OTPVersions.cmake") + ")",
            "otp_application_version(erts OTP_ERTS_VERSION)",
            # Selection must not require OTP-local preload sources.
            "set(PROJECT_SOURCE_DIR " + cmake_quote(project) + ")",
            "include(" + cmake_quote(source / "cmake/SDKDependency.cmake") + ")",
            'file(WRITE "${PROJECT_BINARY_DIR}/selected-target.txt" "${OTP_TARGET}")',
            "",
        ]))

        def configure(name, selected, flavor, diagnostics=(), arguments=(), build_type=None):
            build_type = build_type or args.build_type
            build = root / name
            result = subprocess.run([args.cmake, "-S", str(project), "-B", str(build), "-G", "Ninja",
                f"-DBEAM_SDK_ROOT={selected}", f"-DOTP_BEAM_FLAVOR={flavor}",
                f"-DCMAKE_BUILD_TYPE={build_type}", *arguments],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=40)
            if diagnostics:
                if result.returncode == 0:
                    raise RuntimeError(f"{name} SDK selection unexpectedly configured")
                output = " ".join(result.stdout.split())
                if any(diagnostic not in output for diagnostic in diagnostics):
                    raise RuntimeError(f"{name} failed without its expected SDK diagnostic:\n{result.stdout}")
                print(f"{name}: correctly rejected")
                return
            if result.returncode:
                raise RuntimeError(f"{name} SDK selection failed:\n{result.stdout}")
            receipt = dict(line.split("=", 1) for line in
                           (build / "sdk-selection.txt").read_text(encoding="utf-8").splitlines())
            if Path(receipt["prefix"]) != selected.resolve():
                raise RuntimeError(f"{name} selected an SDK outside the requested prefix")
            if (build / "selected-target.txt").read_text(encoding="utf-8") != receipt["host_triple"]:
                raise RuntimeError(f"{name} output target differs from the SDK runtime triple")
            selected_manifest = json.loads((selected / "manifest.json").read_text(encoding="utf-8"))
            matches = [v for v in selected_manifest["variants"]
                       if (v["flavor"], v["build_type"]) == (flavor, build_type)]
            if len(matches) != 1:
                raise RuntimeError(f"{name} did not select one exact runtime configuration")
            variant = matches[0]
            for field in ("flavor", "build_type", "build_id"):
                if receipt[field] != variant[field]:
                    raise RuntimeError(f"{name} receipt differs from selected {field}")
            for field in ("source_id", "toolchain_id"):
                if receipt[field] != selected_manifest[field]:
                    raise RuntimeError(f"{name} receipt differs from SDK {field}")
            for field, relative, hash_field in (
                    ("runtime_archive", variant["archive"], "runtime_sha256"),
                    ("child_setup", variant["child_setup"], "child_setup_sha256")):
                artifact = selected / relative
                if Path(receipt[field]).resolve() != artifact.resolve():
                    raise RuntimeError(f"{name} selected the wrong {field}")
                if receipt[hash_field] != hashlib.sha256(artifact.read_bytes()).hexdigest():
                    raise RuntimeError(f"{name} has an incorrect {hash_field}")
            print(f"{name}: correctly accepted")
            return receipt

        compatible = configure("compatible", sdk, args.flavor)
        expected_version = compatible["version"]
        for variant in manifest["variants"]:
            configure(f"available-{variant['flavor']}-{variant['build_type']}", sdk,
                      variant["flavor"], build_type=variant["build_type"])
        wrong = "jit" if args.flavor == "emu" else "emu"
        configure("missing", root / "absent-sdk", args.flavor,
                  ["Set BEAM_SDK_ROOT to an absolute installed BEAM SDK prefix"])
        selected = sdk_variant(sdk, root / "sdk-single-choice")
        single = json.loads((selected / "manifest.json").read_text(encoding="utf-8"))
        single["variants"] = [v for v in single["variants"]
                              if (v["flavor"], v["build_type"]) == (args.flavor, args.build_type)]
        (selected / "manifest.json").write_text(json.dumps(single))
        configure("missing-flavor", selected, wrong, ["unavailable"])
        other_type = "Debug" if args.build_type == "Release" else "Release"
        configure("missing-build-type", selected, args.flavor, ["unavailable"], build_type=other_type)
        configure("conflicting-flavor", sdk, args.flavor, ["conflict"],
                  arguments=[f"-DBEAM_RUNTIME_FLAVOR={wrong}"])
        for unsupported in ("RelWithDebInfo", "OFF", "NO", "0"):
            configure("unsupported-build-type-" + unsupported, sdk, args.flavor, ["Release", "Debug"],
                      arguments=["-DCMAKE_BUILD_TYPE=" + unsupported])
        if any((v["flavor"], v["build_type"]) == ("emu", "Release") for v in manifest["variants"]):
            configure("default-selection", sdk, "emu", build_type="Release",
                      arguments=["-UOTP_BEAM_FLAVOR", "-UCMAKE_BUILD_TYPE"])

        receipt = configure("target-override", sdk, args.flavor,
                            arguments=["-DOTP_TARGET=unselected-host-triple"])
        if receipt["host_triple"] != compatible["host_triple"]:
            raise RuntimeError("SDK runtime triple was not preserved in selection receipt")
        selected = sdk_variant(sdk, root / "sdk-missing-host-triple", HOST_TRIPLE=None)
        configure("missing-host-triple", selected, args.flavor, ["BEAM_SDK_HOST_TRIPLE"])
        configure("missing-host-triple-override", selected, args.flavor, ["BEAM_SDK_HOST_TRIPLE"],
                  arguments=["-DBEAM_SDK_HOST_TRIPLE=unselected-runtime-triple"])
        for index, triple in enumerate((123, "", ".", "..", "../escape", "/absolute", "bad/target",
                                       "bad\\target", "bad target", "bad;target")):
            selected = sdk_variant(sdk, root / f"sdk-unsafe-host-triple-{index}", HOST_TRIPLE=triple)
            diagnostic = ("BEAM_SDK_HOST_TRIPLE" if not triple else
                          "BEAM_SDK_HOST_TRIPLE must be a safe single directory component")
            configure(f"unsafe-host-triple-{index}", selected, args.flavor, [diagnostic])

        for version in ("0.1.0", "16.0", "17.0.0", "17.0.1", "18.0"):
            selected = sdk_variant(sdk, root / ("sdk-" + version), VERSION=version)
            version_file = selected / manifest["package_dir"] / "BEAMConfigVersion.cmake"
            version_file.write_text(version_file.read_text(encoding="utf-8").replace(
                '"' + expected_version + '"', '"' + version + '"'))
            configure("wrong-version-" + version, selected, args.flavor,
                      ["Could not find a configuration file", "requested version", expected_version])

        selected = sdk_variant(sdk, root / "sdk-wrong-metadata", VERSION="17.0.1")
        configure("wrong-metadata", selected, args.flavor, ["Selected SDK version", "required BEAM version"])
        selected = sdk_variant(sdk, root / "sdk-wrong-erts", ERTS_VERSION="17.0.1")
        configure("wrong-erts", selected, args.flavor, ["Selected SDK ERTS version does not match OTP sources"])
        upstream = "0" * 40 if compatible["upstream"] != "0" * 40 else "1" * 40
        selected = sdk_variant(sdk, root / "sdk-different-upstream", UPSTREAM_COMMIT=upstream)
        receipt = configure("different-upstream", selected, args.flavor)
        if receipt["upstream"] != upstream:
            raise RuntimeError("SDK provenance was not preserved in selection receipt")
        selected = sdk_variant(sdk, root / "sdk-malformed")
        (selected / "manifest.json").write_text("{invalid JSON")
        configure("malformed-manifest", selected, args.flavor, ["manifest"])
        selected = sdk_variant(sdk, root / "sdk-invalid-schema", SCHEMA="1")
        configure("invalid-schema", selected, args.flavor, ["manifest schema"])
        for field in ("source_id", "toolchain_id", "build_id"):
            for index, value in enumerate((None, "", "invalid", 123)):
                selected = sdk_variant(sdk, root / f"sdk-invalid-{field}-{index}")
                path = selected / "manifest.json"
                malformed = json.loads(path.read_text(encoding="utf-8"))
                record = malformed if field != "build_id" else malformed["variants"][0]
                if value is None:
                    record.pop(field)
                else:
                    record[field] = value
                path.write_text(json.dumps(malformed))
                configure(f"invalid-{field}-{index}", selected, args.flavor, [field, "identity"])
        for name, variants in (("missing", None), ("object", {}), ("empty", []),
                               ("duplicate", manifest["variants"] + [manifest["variants"][0]])):
            selected = sdk_variant(sdk, root / f"sdk-invalid-variants-{name}", VARIANTS=variants)
            configure("invalid-variants-" + name, selected, args.flavor, ["manifest", "configuration"])
        selected = sdk_variant(sdk, root / "sdk-escaping-package", PACKAGE_DIR="../outside")
        configure("escaping-package", selected, args.flavor, ["package"])


if __name__ == "__main__":
    main()
