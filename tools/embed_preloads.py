#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Adapt upstream make_preload output to public SDK composition descriptors."""
import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--perl", required=True)
    parser.add_argument("--generator", type=Path, required=True)
    parser.add_argument("modules", nargs="+")
    args = parser.parse_args()
    if len(set(args.modules)) != len(args.modules):
        parser.error("Duplicate preload names")
    # Retain upstream chunk selection and ordering. Inspection files stay whole.
    # Its ordinary output contains only C arrays, with no private VM types.
    generated = subprocess.run([args.perl, str(args.generator),
        *[str(args.directory / (name + ".beam")) for name in args.modules]],
        check=True, stdout=subprocess.PIPE, text=True, timeout=60).stdout
    lines = [generated, '#include <beam/beam.h>', "const beam_module_spec otp_preloads[] = {"]
    for name in args.modules:
        lines.append(f'{{"{name}", {{preloaded_{name}, sizeof(preloaded_{name})}}, "preloaded"}},')
    lines.append("};")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
