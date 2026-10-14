#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Create a hash-bound review of every changed installed regular file.

Tree equality remains an independent gate. Review decisions name exact files and
both current hashes; neither file classes nor filename patterns waive review.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zipfile
import sys
import shutil

from installation_inventory import inventory, read_record

DISPOSITIONS = {"reviewed metadata difference", "reviewed implementation adaptation",
                "corrected defect", "reference-build failure", "unresolved"}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def beam_chunks(data):
    if data[:4] != b"FOR1" or data[8:12] != b"BEAM":
        return None
    offset, chunks = 12, {}
    while offset < len(data):
        name = data[offset:offset + 4].decode("ascii")
        size, = struct.unpack(">I", data[offset + 4:offset + 8])
        chunk = data[offset + 8:offset + 8 + size]
        if len(chunk) != size or name in chunks:
            raise ValueError("Malformed or duplicate BEAM chunk")
        chunks[name] = {"size": size, "sha256": digest(chunk)}
        offset += 8 + ((size + 3) & ~3)
    if offset != len(data):
        raise ValueError("Malformed BEAM padding")
    return chunks


def native_report(path):
    if sys.platform == 'darwin':
        commands = {'dependencies': ['/usr/bin/otool', '-L'],
                    'load_commands': ['/usr/bin/otool', '-l'],
                    'symbols': ['/usr/bin/nm', '-g']}
    else:
        commands = {option: [shutil.which('readelf'), option, '--wide']
                    for option in ('--dynamic', '--symbols')}
    return {name: subprocess.check_output([*command, str(path)], text=True, timeout=30)
            for name, command in commands.items()}


def archive_report(path):
    return {name: subprocess.run(command + [str(path)],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            check=True, timeout=30).stdout
            for name, command in (("members", ["ar", "t"]),
                                  ("symbols", [shutil.which("nm"), "-gU"] if sys.platform == "darwin" else [shutil.which("nm"), "-g", "--defined-only"]))}


def zip_report(path):
    with zipfile.ZipFile(path) as archive:
        return [{"path": item.filename, "mode": item.external_attr,
                 "timestamp": item.date_time, "sha256": digest(archive.read(item))}
                for item in archive.infolist()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for side in ("candidate", "reference"):
        parser.add_argument("--" + side, type=Path, required=True,
                            help="External installation provenance")
    parser.add_argument("--decisions", type=Path,
                        help="Object keyed by exact relative paths, with both hashes")
    parser.add_argument("--candidate-beams", type=Path)
    parser.add_argument("--reference-beams", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    records = [read_record(getattr(args, side)) for side in ("candidate", "reference")]
    candidate, reference = records
    if (candidate["runtime"], reference["runtime"]) != ("candidate", "reference"):
        parser.error("Select candidate and original-build reference provenance")
    if candidate["flavor"] != reference["flavor"]:
        parser.error("Compare matching flavors")
    prefixes = [Path(record["prefix"]) for record in records]
    for record, prefix in zip(records, prefixes):
        if args.output.resolve().is_relative_to(prefix.resolve()):
            parser.error("Content evidence belongs outside the installation")
        if inventory(prefix) != record["entries"]:
            parser.error(f"Installation changed since capture: {prefix}")
    decisions = json.loads(args.decisions.read_text()) if args.decisions else {}
    if bool(args.candidate_beams) != bool(args.reference_beams):
        parser.error("Supply both BEAM inspection records")
    inspections = ([json.loads(path.read_text()) for path in
                    (args.candidate_beams, args.reference_beams)]
                   if args.candidate_beams else None)
    changed, used = [], set()
    for name in sorted(candidate["entries"].keys() & reference["entries"].keys()):
        entries = [record["entries"][name] for record in records]
        if any(entry["kind"] != "file" for entry in entries):
            continue
        hashes = [entry["sha256"] for entry in entries]
        if hashes[0] == hashes[1]:
            continue
        paths = [prefix / name for prefix in prefixes]
        data = [path.read_bytes() for path in paths]
        item = {"path": name, "candidate_sha256": hashes[0], "reference_sha256": hashes[1],
                "producer_source": None, "reason": None, "validation": [],
                "disposition": "unresolved"}
        chunks = [beam_chunks(value) for value in data]
        if any(chunk is not None for chunk in chunks):
            item["beam_chunks"] = dict(zip(("candidate", "reference"), chunks))
            if inspections:
                if any(record[name]["sha256"] != expected
                       for record, expected in zip(inspections, hashes)):
                    parser.error(f"Stale BEAM inspection: {name}")
                item["beam_inspection"] = dict(zip(("candidate", "reference"),
                                                   (record[name] for record in inspections)))
            if all(chunk is not None for chunk in chunks):
                item["changed_chunks"] = [key for key in sorted(chunks[0].keys() | chunks[1].keys())
                                          if chunks[0].get(key) != chunks[1].get(key)]
        elif all(value.startswith(b"\x7fELF") or value[:4] in (
                b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xce",
                b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca") for value in data):
            item["native"] = dict(zip(("candidate", "reference"),
                                     (native_report(path) for path in paths)))
        elif all(value.startswith(b"!<arch>\n") for value in data):
            item["archive"] = dict(zip(("candidate", "reference"),
                                      (archive_report(path) for path in paths)))
        elif all(zipfile.is_zipfile(path) for path in paths):
            item["zip"] = dict(zip(("candidate", "reference"),
                                  (zip_report(path) for path in paths)))
        else:
            try:
                try:
                    texts = [value.decode("utf-8") for value in data]
                except UnicodeDecodeError:
                    if paths[0].suffix not in (".c", ".erl", ".h", ".mk"):
                        raise
                    # A one-to-one byte representation for retained generated
                    # C containing non-UTF-8 lexer input.
                    texts = [value.decode("latin-1") for value in data]
                    item["raw_diff_encoding"] = "latin-1"
                item["raw_diff"] = "".join(difflib.unified_diff(
                    texts[1].splitlines(True), texts[0].splitlines(True),
                    fromfile="reference/" + name, tofile="candidate/" + name))
                normalized = [text.replace(str(prefix), "${INSTALL_PREFIX}")
                              for text, prefix in zip(texts, prefixes)]
                item["installation_prefix_normalized_equal"] = normalized[0] == normalized[1]
            except UnicodeDecodeError:
                item["binary_sizes"] = list(map(len, data))
        if name in decisions:
            decision = decisions[name]
            for key in ("candidate_sha256", "reference_sha256"):
                if decision.get(key) != item[key]:
                    parser.error(f"Stale content decision: {name}: {key}")
            if decision.get("disposition") not in DISPOSITIONS:
                parser.error(f"Unknown content disposition: {name}")
            for key in ("producer_source", "reason", "validation"):
                if not decision.get(key):
                    parser.error(f"Missing {key} in content decision: {name}")
            item.update({key: decision[key] for key in
                         ("producer_source", "reason", "validation", "disposition")})
            used.add(name)
        changed.append(item)
    if used != decisions.keys():
        parser.error(f"Unused decisions: {sorted(decisions.keys() - used)}")
    unresolved = sum(item["disposition"] == "unresolved" for item in changed)
    report = {"format": 1, "flavor": candidate["flavor"],
              "candidate_provenance_sha256": digest(args.candidate.read_bytes()),
              "reference_provenance_sha256": digest(args.reference.read_bytes()),
              "changed_regular_files": len(changed), "unresolved": unresolved,
              "complete": unresolved == 0, "files": changed}
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Content review: {len(changed)} changed regular files; {unresolved} unresolved")
    if unresolved:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
