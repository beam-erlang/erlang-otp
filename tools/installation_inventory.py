#!/usr/bin/env python3
"""External installation provenance and exact upstream tree comparison."""
import argparse
import hashlib
import json
from pathlib import Path
import stat

UPSTREAM_COMMIT = "550d7b7898706c7822362c42e7b93120c1d1f29a"


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def inventory(prefix):
    result = {".": {"kind": "directory", "mode": format(stat.S_IMODE(prefix.stat().st_mode), "04o")}}
    for path in sorted(prefix.rglob("*")):
        mode = path.lstat().st_mode
        record = {"mode": format(stat.S_IMODE(mode), "04o")}
        if stat.S_ISLNK(mode):
            record.update(kind="symlink", target=str(path.readlink()))
        elif stat.S_ISREG(mode):
            record.update(kind="file", sha256=digest(path))
        elif stat.S_ISDIR(mode):
            record.update(kind="directory")
        else:
            raise ValueError(f"Unsupported installation entry: {path}")
        result[path.relative_to(prefix).as_posix()] = record
    return result


def read_record(path):
    record = json.loads(path.read_text())
    if record.get("format") != 1 or record.get("upstream_commit") != UPSTREAM_COMMIT:
        raise ValueError(f"Unsupported installation provenance: {path}")
    if record.get("runtime") not in ("candidate", "reference") or record.get("flavor") not in ("emu", "jit"):
        raise ValueError(f"Invalid runtime or flavor: {path}")
    return record


def verify_installation(prefix, provenance):
    """Verify all selected bytes and tree entries before running installed tests."""
    record = read_record(provenance)
    if inventory(prefix.resolve(strict=True)) != record["entries"]:
        raise ValueError("Installation no longer matches its attested bytes and tree")
    return record


def shape(record):
    return {key: value for key, value in record.items() if key != "sha256"}


def compare(candidate, reference):
    if candidate["runtime"] != "candidate" or reference["runtime"] != "reference":
        raise ValueError("Comparison requires candidate and original-build reference provenance")
    if candidate["flavor"] != reference["flavor"]:
        raise ValueError("Runtime flavors differ")
    actual, expected = candidate["entries"], reference["entries"]
    changes = []
    for name in sorted(actual.keys() | expected.keys()):
        if name not in actual:
            changes.append({"path": name, "difference": "missing", "expected": expected[name]})
        elif name not in expected:
            changes.append({"path": name, "difference": "extra", "actual": actual[name]})
        else:
            left, right = shape(actual[name]), shape(expected[name])
            if left != right:
                changes.append({"path": name, "difference": "shape", "actual": left, "expected": right})
    return changes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    capture = commands.add_parser("capture")
    capture.add_argument("--prefix", type=Path, required=True)
    capture.add_argument("--runtime", choices=("candidate", "reference"), required=True)
    capture.add_argument("--flavor", choices=("emu", "jit"), required=True)
    capture.add_argument("--evidence", type=Path, required=True,
                         help="Source/build attestation; candidate evidence includes selected SDK hashes")
    capture.add_argument("--output", type=Path, required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("--prefix", type=Path, required=True)
    verify.add_argument("--provenance", type=Path, required=True)
    comparison = commands.add_parser("compare")
    comparison.add_argument("--candidate", type=Path, required=True)
    comparison.add_argument("--reference", type=Path, required=True)
    comparison.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "capture":
        prefix = args.prefix.resolve(strict=True)
        if args.output.resolve().is_relative_to(prefix):
            parser.error("Provenance must be outside the installed tree")
        evidence = json.loads(args.evidence.read_text())
        if evidence.get("upstream_commit") != UPSTREAM_COMMIT:
            parser.error("Build evidence does not attest the pinned upstream source")
        record = {"format": 1, "runtime": args.runtime, "flavor": args.flavor,
                  "upstream_commit": UPSTREAM_COMMIT, "prefix": str(prefix),
                  "build": evidence, "entries": inventory(prefix)}
        args.output.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
        print(f"Captured {len(record['entries'])} {args.runtime}/{args.flavor} entries")
    elif args.command == "verify":
        record = verify_installation(args.prefix, args.provenance)
        print(f"Verified {len(record['entries'])} installation entries")
    else:
        candidate, reference = read_record(args.candidate), read_record(args.reference)
        differences = compare(candidate, reference)
        args.output.write_text(json.dumps({"candidate_entries": len(candidate["entries"]),
                                          "reference_entries": len(reference["entries"]),
                                          "differences": differences}, indent=2) + "\n")
        print(f"Installation comparison: {len(differences)} differences")
        if differences:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
