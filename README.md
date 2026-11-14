# Erlang/OTP

Erlang/OTP distributes the Erlang language tools, libraries and application
framework as an independent product built on the installed BEAM/Erlang runtime
SDK. It supplies the ordinary OTP commands and application layout while using
the shared VM through public installed interfaces.

The current distribution builds 35 retained applications. These include the
Compiler, Crypto and SSL, Mnesia, SSH, Common Test, Dialyzer, Jinterface, Megaco,
ODBC, wx, Observer and Debugger. OTP owns its commands, applications, ordinary
native extensions, boot files and installation. BEAM/Erlang supplies the VM,
canonical BIFs, preloaded modules and matching runtime interfaces. The
[architecture guide](docs/architecture.md) describes this boundary and lists the
complete application inventory.

## Building the distribution with CMake

### Native targets

Choose a preset from [CMakePresets.json](CMakePresets.json) matching your host:

| Host | Interpreter preset | JIT preset |
| --- | --- | --- |
| Linux x86_64 | `linux-x86_64-emu` | `linux-x86_64-jit` |
| Linux AArch64 | `linux-aarch64-emu` | `linux-aarch64-jit` |
| macOS 26+ on Apple Silicon | `macos-arm64-emu` | `macos-arm64-jit` |
| Windows x64 with MSVC | `windows-x86_64-emu` | `windows-x86_64-jit` |

These presets use Ninja and select Release. Each has a corresponding `-debug`
preset, such as `macos-arm64-jit-debug`. The build accepts single-config Release
or Debug configurations. Cross compilation is outside the supported product
build. Windows uses the Visual Studio 2022 x64 developer environment and the
Windows SDK.

macOS presets use Apple Clang and a deployment target of `26.0`. This product
floor includes its selected native dependencies and is separate from the
BEAM/Erlang SDK's lower deployment floor. Available presets describe build
configurations; acceptance coverage is described below.

### Prerequisites and SDK selection

The build needs CMake 3.25+, Ninja, C11/C++17 compilers, Perl, OpenSSL, wxWidgets,
a JDK, an ODBC development installation and Flex. Linux wx builds also need
OpenGL/GLU development libraries. Python 3.9+ is required for tests, which are
enabled by default. A product-only build can use `-DBUILD_TESTING=OFF` to omit
test registration and the Python requirement.

Windows dependency selectors and installer creation are described in the
[Windows build guide](docs/build.md#windows). The Release installer uses the
unchanged original OTP NSIS script and an explicitly selected VC redistributable.
It omits the documentation component. Debug produces a developer tree requiring
the matching Debug CRT.

Install a matching BEAM/Erlang SDK before configuring OTP. This OTP `29.0`
release requires SDK package and ERTS version `17.0` exactly. Select its installed
prefix with `BEAM_SDK_ROOT`; the prefix must provide the manifest-based SDK and
`BEAM::Runtime` interface. Both individual and combined SDK installations use
this selector.

`OTP_BEAM_FLAVOR` selects `emu` or `jit`, and `CMAKE_BUILD_TYPE` selects Release
or Debug. Direct configurations default to interpreter Release; presets select
their choices explicitly. The SDK must contain the requested configuration and
match the platform, architecture and deployment requirements. Missing or
incompatible selections fail during configuration. The build uses the selected
SDK as its sole VM and requires no installed `erl` or `erlc`.

### Configure, build, test and install

From the repository root, select each dependency explicitly. Replace these
placeholder paths with your installed inputs:

```sh
export BEAM_SDK_ROOT=/absolute/path/to/installed/beam-sdk
export OPENSSL_ROOT_DIR=/absolute/path/to/openssl
export OTP_WX_CONFIG=/absolute/path/to/wx-config
export JAVA_HOME=/absolute/path/to/jdk
export ODBC_CONFIG=/absolute/path/to/odbc_config
export FLEX_EXECUTABLE=/absolute/path/to/flex

cmake --preset macos-arm64-emu
cmake --build --preset macos-arm64-emu --parallel 3
ctest --preset macos-arm64-emu
cmake --install build/macos-arm64-emu
```

Use your native preset and matching build-directory suffix throughout. List
presets available on your host with `cmake --list-presets=all`. For JIT Debug,
for example, select a matching SDK configuration and use
`macos-arm64-jit-debug` in all four commands.

ODBC installations without a config program can instead use explicit
`ODBC_INCLUDE_DIR` and `ODBC_LIBRARY` paths; see the [build guide](docs/build.md).

Standard output lives in `build/<preset-name>` and `install/<preset-name>`.
Keep separate outputs for each flavor and build type. Use workspace `../tmp/`
for experimental configurations, temporary installations and validation
payloads. The [build guide](docs/build.md) covers dependency selection,
platform requirements and generated outputs in detail.

Keep the selected SDK unchanged between configuration and build. After
rebuilding, reinstalling or replacing it, rerun CMake before building OTP, even
if its prefix and release version are unchanged. The build directory's
`sdk-selection.txt` records the configure-time source, toolchain and build
identities and selected artifact paths and hashes.

Debug selects the Debug VM and native compiler settings while preserving
ordinary OTP command names and Erlang compilation policy. It enables the VM's
Debug and lock checks; it does not add private VM macros to native extensions.

## Using the distribution

Run the installed Erlang shell with:

```sh
install/macos-arm64-emu/bin/erl
```

Or evaluate an expression and exit:

```sh
install/macos-arm64-emu/bin/erl -noshell \
  -eval 'io:format("OTP ~s / ERTS ~s~n", [erlang:system_info(otp_release), erlang:system_info(version)]), halt().'
```

Adjust the preset suffix for your installation. The completed build tree is also
runnable through `build/<preset-name>/bin/erl`.

To try the installed compiler, create `../tmp/otp-hello/` and save this module
as `../tmp/otp-hello/hello.erl`:

```erlang
-module(hello).
-export([world/0]).

world() ->
    io:format("Hello from Erlang/OTP~n").
```

Compile and run it from the repository root:

```sh
otp_bin="$PWD/install/macos-arm64-emu/bin"
"$otp_bin/erlc" -o ../tmp/otp-hello ../tmp/otp-hello/hello.erl
"$otp_bin/erl" -noshell -pa "$PWD/../tmp/otp-hello" -s hello world -s init stop
```

Retained original OTP guides cover [getting started with Erlang](system/doc/getting_started/getting_started.md)
and [OTP design principles](system/doc/design_principles/design_principles.md).
Use this repository's [build guide](docs/build.md) for its CMake distribution
workflow.

Generating the complete original OTP documentation is unsupported. Installations,
release trees and Windows installers omit the generated documentation corpus.
Original content and core generators remain in the source tree, but there is no
maintained documentation build workflow. Documentation parity with original OTP
has not been achieved; see the [build guide](docs/build.md#documentation-status).

### Installation and deployment

The install prefix is the OTP root:

| Path | Contents |
| --- | --- |
| `bin/` | OTP commands, including `erl`, `erlc`, `escript`, `ct_run` and `dialyzer` |
| `erts-17.0/bin/` | SDK-linked `beam.smp`, matching child helper and runtime-facing commands |
| `lib/<app>-<version>/` | Versioned applications, bytecode, sources, headers and native resources |
| `lib/erts-17.0/` | SDK-supplied preload inspection bytecode and matching sources |
| `releases/` | Boot files and release metadata |
| `usr/include/` | Installed public native headers |

The installed product runs without its producer source/build trees or SDK
prefix. Selected OpenSSL, wxWidgets and ODBC native libraries remain external
runtime dependencies; Jinterface consumers need Java. NIFs and drivers use the
installed public interfaces without linking a second VM.

Installation supports prefix overrides and `DESTDIR` staging, for example:

```sh
DESTDIR="$PWD/../tmp/otp-staging" \
  cmake --install build/macos-arm64-emu --prefix /opt/otp
```

The explicit `otp_release` target assembles a versioned release under
`<build-dir>/release/<BEAM_SDK_HOST_TRIPLE>` using the same installation and
finalization logic:

```sh
cmake --build --preset macos-arm64-emu --target otp_release
```

Release assembly uses the existing application outputs. It does not compile
another copy of the distribution.

## Testing the runtime with CTest

Run `ctest --preset <preset-name>` after building and installing. One public
test preset corresponds to each build configuration. The default checks cover:

- Build-tree launchers, bootstrap/compiler selection and application inventories.
- Private installed and `DESTDIR` products, relocation to paths with spaces and
  Unicode, and execution with producer source/build/SDK access denied.
- Commands, compiler and source usability, native extensions, Crypto, TCP,
  supervision, restart, peers and bounded application functionality.
- SDK selection, native architecture checks, atomic installation and test-harness
  integrity.
- A bounded selection of unchanged original OTP Compiler, time, timer and
  `erl_call` cases.

Tests verify the inventory of all 35 applications, with functional coverage
limited to the exercised cases. They require loopback networking; permission
or isolation setup failures remain failures. Logs live under
`<build-dir>/tests/logs/` and CTest's `Testing/Temporary/`. Disposable test
payloads use workspace `tmp/`. See the [testing guide](docs/testing.md) for the
CTest owners, prerequisites and precise coverage.

Broad acceptance has separate opt-in gates:

| Configure option | Entry points | Scope |
| --- | --- | --- |
| `OTP_ENABLE_TEST_SUITES=ON` | Per-application CTests and `otp-tests` target | All 35 applications, ordered emulator/system corpora, EPMD and yielding-C, followed by reconciliation |
| `OTP_ENABLE_ERTS_TESTS=ON` | `otp-erts-prepare` and `otp-erts-check` targets | Independent retained emulator, system, EPMD and yielding-C corpus |
| `OTP_ENABLE_INDIVIDUAL_SUITES=ON` | `otp-suite-<domain>-<suite>` CTests | Independently selected diagnostics; cannot satisfy full acceptance |

These options default to `OFF` and require explicit installed-candidate,
reference-source and prerequisite inputs. Configure them in separate workspace `tmp/`
build/install directories, following the [original OTP acceptance guide](docs/otp-tests.md).

The shared testing path uses original OTP Make, Erlang test-server helpers and
Common Test on Linux, macOS and Windows. Native execution evidence must be
obtained separately for every supported host and runtime configuration.
A successful build or default CTest run does not establish full OTP
compatibility. The acceptance guide records outstanding prerequisites and
coverage gaps.

## Source map

| Path | Responsibility |
| --- | --- |
| `erts/` | OTP process entry, launchers, helpers and retained runtime-facing components |
| `lib/` | The 35 applications and their source-local CMake declarations |
| `bootstrap/` | Retained compiler/build inputs |
| `cmake/` | SDK selection, bootstrap, generators, application assembly and installation |
| `tests/` | Product checks and separate original OTP acceptance support |
| `docs/` | Distribution architecture, build and testing guides |
| `system/doc/` | Retained Erlang language and OTP design documentation |

Retained original OTP sources keep their original paths. Generated sources,
application trees and bootstrap stages belong in the build directory. Product
integration uses installed public SDK interfaces rather than sibling VM source
or build trees.

When reporting a problem, include the source revision, preset, selected SDK
identities, dependency selectors and failing command with its logs.

## Version and provenance

[OTP_VERSION](OTP_VERSION) owns the product version, currently `29.0`.
[otp_versions.table](otp_versions.table) records its ERTS requirement, which
selects BEAM/Erlang SDK `17.0` exactly. OTP and ERTS/SDK release versions are
separate identities.

[UPSTREAM_COMMIT](UPSTREAM_COMMIT) records the original OTP synchronization point,
not an exact modified-source identity or a runtime compatibility guarantee.
Ordinary SDK selection does not require equal original OTP pins. Pinned original
OTP acceptance has its own exact source and SDK identity requirements.

## License

This distribution is derived from Erlang/OTP and retains original OTP copyright and
license notices. See [LICENSE.txt](LICENSE.txt) for the Apache License 2.0 and
[LICENSES/](LICENSES/) for additional component licenses.

<!--
%CopyrightBegin%

SPDX-License-Identifier: Apache-2.0

Copyright Ericsson AB 2010-2025. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

%CopyrightEnd%
-->
