# Erlangsters - Erlang/OTP

Erlangsters - Erlang/OTP is an experimental distribution of Erlang/OTP, built
from OTP 29.0 sources around the shared virtual machine provided by
[Erlangsters - BEAM/Erlang](https://github.com/beam-erlang/beam-erlang).

This repository owns OTP applications, commands, startup policy, native services
and installation. It builds against an explicitly selected installed BEAM/Erlang
SDK, using `libbeam` as its sole VM implementation. The resulting installation
statically links the VM into `erts-<version>/bin/beam.smp`, embeds its thirteen
OTP preloads and built-in native implementations, and runs independently of the
build SDK. It installs no shared VM library or extra runtime directory. Exact
installed-tree and release validation is tracked separately from full OTP
compatibility in the [static runtime record](../dev-documents/static-sdk-otp-runtime.md).

## Status

The VM and distribution ownership migration is complete. Both Linux interpreter
and JIT configurations build, with recorded acceptance for commands, native
extensions, relocation, isolation and restart. Full OTP 29.0 compatibility
remains unfinished.

Native Windows 11 AMD64 development uses Visual Studio 2022 MSVC, CMake and
Ninja, with separate EMU/JIT builds and all 35 applications. See the
[Windows build/use guide](docs/build.md#native-windows-development) and
[development checkpoint](../dev-documents/windows-development-baseline.md) for
executed smoke/GUI checks and known limitations. Full Windows qualification
and the historical Linux wx deferral are separate from this development scope.

Both flavors now assemble all 35 applications, including Observer and Reltool.
Matching-flavor installation-tree equality, complete installed-content review and
all eight playground examples pass on both flavors against candidate and upstream.
The public allocator-tagging control and unchanged Observer crash-dump cases pass.
See [assembly fidelity](docs/assembly-fidelity.md) for the final validation and
stable-installation refresh, and [the application record](docs/observer-reltool.md)
for selected upstream coverage and the historical startup failure.
ET product validation passes; socket-sendfile has retained upstream-reproduced
failures, and several suite coverage gates remain
nonpassing because of skipped cases. wx is built, but its compatibility and
GUI-dependent acceptance are explicitly deferred. The earlier recorded full checkpoint
has 101 CTest entries per flavor: 79 passes, seven deferred wx entries and
15 nonpassing entries. These counts do not represent complete OTP coverage.

The source baseline is recorded in [UPSTREAM_COMMIT](UPSTREAM_COMMIT).
The [build guide](docs/build.md) and application records below describe the
scope and limitations of the existing evidence.

The adopted [release policy](../dev-documents/distribution-release-strategy.md)
keeps OTP's upstream version with an Erlangsters distribution revision, while
BEAM uses its upstream ERTS base with its own revision. Exact SDK selection remains
required. The [sync strategy](../dev-documents/Upstream-Sync-Process.md) defines
product maintenance branches by generation: OTP `maint-29` corresponds to BEAM
`maint-17`. These are branch roles, not a claim that those branches or stable
releases have been established. BEAM's current source identity is
`17.0-r1-preview.1`; use the exact qualified SDK selection for an OTP build.

## Building

The commands below target Linux; the build guide also describes native Windows
and macOS configurations. Install CMake 3.25 or newer, Ninja, C and C++
compilers, Perl, Python 3.9 or newer, Flex 2.6 or newer, pkg-config and a JDK.
Native dependencies include OpenSSL, zlib 1.2.8 or newer with
`inflateGetDictionary`, curses/terminfo and ODBC development files. The wx build
also requires wxWidgets 3.2 or newer with WebView, GLib, OpenGL and GLU development
files; disabling wx tests does not remove these build dependencies.

Obtain a matching installed BEAM/Erlang SDK before configuring. Set
`BEAM_SDK_ROOT` explicitly to its absolute installation prefix. Select
`OTP_BEAM_SDK_VERSION` and `OTP_BEAM_SDK_BUILD_ID` from the verified candidate
record independently of that prefix; OTP and ERTS retain their upstream versions. OTP supplies its
own compiler bootstrap and verifies it against retained sources; an existing
Erlang installation or the BEAM command is not required.

From the repository root, build and install the interpreter flavor:

```sh
cmake --preset linux-emu \
  -DBEAM_SDK_ROOT=/absolute/path/to/installed/emu-sdk \
  -DOTP_BEAM_SDK_VERSION="$EXPECTED_BEAM_VERSION" \
  -DOTP_BEAM_SDK_BUILD_ID="$EXPECTED_BEAM_BUILD_ID"
cmake --build --preset linux-emu
cmake --install build/linux-emu
```

The JIT flavor uses its matching SDK and separate output directories:

```sh
cmake --preset linux-jit \
  -DBEAM_SDK_ROOT=/absolute/path/to/installed/jit-sdk \
  -DOTP_BEAM_SDK_VERSION="$EXPECTED_BEAM_VERSION" \
  -DOTP_BEAM_SDK_BUILD_ID="$EXPECTED_BEAM_BUILD_ID"
cmake --build --preset linux-jit
cmake --install build/linux-jit
```

Presets use `build/<preset>/` and install into `install/<preset>/`; both are
gitignored. Configuration checks the selected SDK's version, flavor and required
capabilities. See the [build guide](docs/build.md) for dependency selection,
installation overrides and bootstrap details.

## Using Erlang/OTP

After installation, start the shell from the repository root:

```sh
install/linux-emu/bin/erl
```

Enter `q().` to exit. The installation supplies the familiar `erl`, `erlc`,
`escript` and `ct_run` commands. To compile and run the existing
[compiler example](tools/fixtures/otp_compiler_probe.erl):

```sh
mkdir -p build/example
install/linux-emu/bin/erlc -o build/example tools/fixtures/otp_compiler_probe.erl
install/linux-emu/bin/erl -noshell -pa build/example \
  -eval 'io:format("~p~n", [otp_compiler_probe:run()]), halt().'
```

This prints `42`. Replace `linux-emu` with `linux-jit` to use the JIT installation.
Command and emulator-option coverage remains incomplete; see the
[command record](docs/commands.md) for the tested behavior.

## Testing

Run the registered acceptance suite for each built flavor:

```sh
ctest --preset linux-emu
ctest --preset linux-jit
```

Complete runs currently return a nonzero status because of the known failures
and strict coverage gates described above. Disabled wx entries are deferrals,
not passes. Selected unchanged upstream suites run through this distribution's
own Common Test application; see [upstream testing](docs/upstream-testing.md).

Full acceptance requires `bwrap`, permission to create private namespaces,
POSIX terminals and loopback networking. Interoperability checks also require
explicitly selected [vsftpd](docs/file-transfer.md),
[OpenLDAP](docs/eldap.md) and [PostgreSQL 18 with psqlODBC](docs/odbc.md)
dependencies. Their records describe the required CMake settings and isolated
test environments. Deferred graphical checks additionally require Xvfb.

## Documentation

- [Build and SDK integration](docs/build.md)
- [Application assembly inventory](docs/application-coverage.md)
- [Commands and local distribution](docs/commands.md)
- [Native extensions](docs/native-extensions.md)
- [Upstream testing and evidence](docs/upstream-testing.md)

These documents include historical checkpoints; each result applies to its
recorded inputs and scope. Retained upstream documentation describes the
original OTP distribution. Use this repository's CMake instructions to build
this experimental distribution.

## License and credits

The project primarily uses the [Apache License 2.0](LICENSE.txt). Bundled
sources retain their own license and copyright notices; additional license
texts are in [LICENSES/](LICENSES/). See the [upstream acknowledgments](AUTHORS)
and [runtime credits](erts/AUTHORS).

> %CopyrightBegin%
>
> SPDX-License-Identifier: Apache-2.0
>
> Copyright Ericsson AB 2010-2025. All Rights Reserved.
>
> Licensed under the Apache License, Version 2.0 (the "License");
> you may not use this file except in compliance with the License.
> You may obtain a copy of the License at
>
>     http://www.apache.org/licenses/LICENSE-2.0
>
> Unless required by applicable law or agreed to in writing, software
> distributed under the License is distributed on an "AS IS" BASIS,
> WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
> See the License for the specific language governing permissions and
> limitations under the License.
>
> %CopyrightEnd%
