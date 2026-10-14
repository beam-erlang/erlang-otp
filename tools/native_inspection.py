# SPDX-License-Identifier: Apache-2.0
"""Private product-test inspection of native artifacts and compiler system inputs."""
from functools import lru_cache
from pathlib import Path
import shlex
import subprocess
import sys


def symbols(nm, path, defined):
    if sys.platform == 'darwin':
        command = [nm, '-gU' if defined else '-gu', str(path)]
    else:
        command = [nm, *([] if Path(path).suffix in ('.a', '.o') else ['-D']),
                   '-g', '--defined-only' if defined else '--undefined-only', str(path)]
    output = subprocess.check_output(command, text=True)
    names = {line.split()[-1].split('@', 1)[0] for line in output.splitlines()
             if line.split() and not line.endswith(':')}
    return {name.removeprefix('_') for name in names} if sys.platform == 'darwin' else names


def dynamic(path, readelf='readelf'):
    return subprocess.check_output(['/usr/bin/otool', '-L', str(path)] if sys.platform == 'darwin'
                                   else [readelf, '-d', str(path)], text=True)


@lru_cache(maxsize=8)
def compiler_system_roots(compiler):
    roots = [Path('/usr')]
    if sys.platform == 'darwin':
        resource = subprocess.check_output([compiler, '-print-resource-dir'], text=True).strip()
        if not Path(resource).is_absolute() or not Path(resource).is_dir():
            raise RuntimeError('Compiler did not identify its resource directory')
        roots.append(Path(resource).resolve())
        result = subprocess.run([compiler, '-###', '-E', '-x', 'c', '/dev/null'],
                                capture_output=True, text=True, timeout=10, check=True)
        sysroots = []
        for line in result.stderr.splitlines():
            parts = shlex.split(line)
            if '-isysroot' in parts:
                sysroots.append(Path(parts[parts.index('-isysroot') + 1]).resolve(strict=True))
        if len(set(sysroots)) != 1:
            raise RuntimeError('Compiler did not identify exactly one default Apple SDK')
        roots.extend(sysroots)
    return tuple(roots)
