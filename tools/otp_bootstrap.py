#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify and stage explicit OTP-owned compiler/bootstrap inputs."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import shutil


CORE = {"erts_code_purger", "erlang", "erts_internal",
        "erts_literal_area_collector", "erts_trace_cleaner",
        "erts_dirty_process_signal_handler", "atomics", "counters",
        "persistent_term"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(value):
    path = PurePosixPath(value)
    if (not value or not path.parts or path.is_absolute() or PureWindowsPath(value).drive or
            "\\" in value or ".." in path.parts or str(path) != value):
        raise ValueError(f"Invalid bootstrap-relative path: {value!r}")
    return Path(*path.parts)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate bootstrap manifest key: {key}")
        result[key] = value
    return result


def manifest(source):
    directory = source / "bootstrap"
    data = json.loads((directory / "manifest.json").read_text(),
                      object_pairs_hook=unique_object)
    if data["format"] != 1 or data["options"] != ["deterministic", "debug_info"]:
        raise ValueError("Unsupported OTP bootstrap manifest format or options")
    names = [Path(entry["path"]).stem for entry in data["modules"]]
    if len(names) != len(set(names)) or CORE.intersection(names):
        raise ValueError("Duplicate bootstrap modules or VM-owned core bytecode")
    preloads = data["preloads"]
    if len(preloads) != 13 or len(set(preloads)) != 13 or not set(preloads) <= set(names):
        raise ValueError("Expected thirteen distinct OTP-owned preloads")
    module_files = {entry["path"] for entry in data["modules"]}
    if module_files != {p for p in data["files"] if p.endswith(".beam")}:
        raise ValueError("Bootstrap module and artifact inventories differ")
    for group in (data["files"], data["sources"], data["generated"]):
        for path in group:
            relative(path)
    for entry in data["modules"]:
        if entry["source"]["scope"] not in {"source", "generated"}:
            raise ValueError("Unknown bootstrap source scope")
        path = entry["source"]["path"]
        inventory = data["sources"] if entry["source"]["scope"] == "source" else data["generated"]
        if path not in inventory:
            raise ValueError(f"Unattested bootstrap module source: {path}")
    for entry in data["resources"]:
        relative(entry["path"])
        if entry["source"] not in data["sources"]:
            raise ValueError(f"Unattested bootstrap resource: {entry['source']}")
    return directory, data


def verify_files(root, files):
    for name, expected in files.items():
        path = root / relative(name)
        if not path.is_file() or digest(path) != expected:
            raise ValueError(f"Missing or changed bootstrap input: {path}")


def verify_seeds(directory, data):
    seeds = directory / "seeds"
    actual = {p.relative_to(seeds).as_posix() for p in seeds.rglob("*") if p.is_file()}
    if actual != set(data["files"]):
        raise ValueError(f"Bootstrap seed inventory differs: missing={sorted(set(data['files'])-actual)}, extra={sorted(actual-set(data['files']))}")
    verify_files(seeds, data["files"])


def verify_sources(source, data):
    verify_files(source, data["sources"])
    for app in ("kernel", "stdlib", "compiler"):
        prefix = f"lib/{app}/src/"
        actual = {p.relative_to(source).as_posix() for p in (source / prefix).glob("*.erl")}
        expected = {entry["source"]["path"] for entry in data["modules"]
                    if entry["source"]["scope"] == "source" and
                    entry["source"]["path"].startswith(prefix)}
        if actual != expected:
            raise ValueError(f"{app} bootstrap source inventory differs")


def stage(source, directory, data, output, seeds):
    if seeds:
        for name in data["files"]:
            destination = output / relative(name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(directory / "seeds" / name, destination)
    for entry in data["resources"]:
        destination = output / relative(entry["path"])
        destination.parent.mkdir(parents=True, exist_ok=True)
        contents = (source / entry["source"]).read_bytes()
        if "version" in entry:
            contents = contents.replace(b"%VSN%", entry["version"].encode())
        destination.write_bytes(contents)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("verify", "stage", "resources", "reproduced", "candidate"))
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--generated", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--seeds-only", action="store_true")
    args = parser.parse_args()
    if args.seeds_only and args.action != "verify":
        parser.error("--seeds-only applies only to seed inventory verification")
    source = args.source.resolve()
    directory, data = manifest(source)
    verify_seeds(directory, data)
    if args.action in {"stage", "resources"}:
        if args.output is None:
            parser.error("staging requires --output")
        stage(source, directory, data, args.output, args.action == "stage")
    elif args.action == "candidate":
        if args.output is None or args.generated is None:
            parser.error("candidate attestation requires --output and --generated")
        if args.output.resolve() == source or args.output.resolve().is_relative_to(directory):
            raise ValueError("Candidate refresh must not write into the source seed inventory")
        data["files"] = {name: digest(args.output / name) for name in data["files"]}
        data["sources"] = {name: digest(source / name) for name in data["sources"]}
        data["generated"] = {name: digest(args.generated / name) for name in data["generated"]}
        (args.output / "candidate-manifest.json").write_text(json.dumps(data, indent=2) + "\n")
    elif not args.seeds_only:
        verify_sources(source, data)
        if args.generated is not None:
            verify_files(args.generated, data["generated"])
        if args.action == "reproduced":
            if args.output is None or args.generated is None:
                parser.error("reproduction requires --output and --generated")
            actual = {p.relative_to(args.output).as_posix() for p in args.output.rglob("*.beam")}
            expected = {name for name in data["files"] if name.endswith(".beam")}
            if actual != expected:
                raise ValueError("Source-built bootstrap module inventory differs")
            verify_files(args.output, data["files"])
    print(f"OTP bootstrap {args.action}: {len(data['modules'])} declared modules verified")


if __name__ == "__main__":
    main()
