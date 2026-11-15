# Building the core distribution

The product builds all 35 retained applications, including Dialyzer, Diameter,
EDoc, ELDAP, Jinterface, Megaco, ODBC, Reltool and TFTP. The [architecture guide](architecture.md) lists them.

Build on native Linux x86-64/AArch64, Apple Silicon macOS, or Windows x64 with CMake 3.25+, Ninja,
C/C++ compilers, Perl, OpenSSL, an explicitly selected wxWidgets
configuration, a JDK, an ODBC development installation and Flex. Select the JDK
prefix with `JAVA_HOME` and the absolute Flex executable with `FLEX_EXECUTABLE`.
Select ODBC with `ODBC_CONFIG`, or an explicit `ODBC_INCLUDE_DIR` and
`ODBC_LIBRARY` pair. Current qualification targets macOS 26+ arm64, Release `emu`;
Linux and `jit` configurations are retained but are not qualified by that run.
Install a matching BEAM/Erlang SDK first. Its `BEAM` package must be version
`17.0` exactly for this OTP `29.0` release, matching the ERTS version in this
checkout's release table. Other SDK release versions are rejected. Select the
desired `emu` or `jit` flavor and matching OS/architecture. Runtime preloads are
owned by BEAM/Erlang; bootstrap staging and installation copy their inspection
bytecode and matching sources from the SDK. No OTP-local preload tree is needed.
The upstream synchronization SHA remains
provenance and is not required to equal the SDK's SHA during ordinary product
configuration. Pinned upstream qualification has separate exact-identity
requirements. CMake rejects missing or incompatible SDKs rather than discovering
an external Erlang runtime.

The selected prefix must provide the manifest-based process-runtime SDK and
`BEAM::Runtime`; the former `BEAM::RuntimeStatic` target is not accepted. OTP
reads the manifest's relative package directory and disables default package
search paths. Its public selectors remain `BEAM_SDK_ROOT` and
`OTP_BEAM_FLAVOR`, with EMU as the default flavor. OTP forwards that flavor to
the SDK before finding the package; an explicitly conflicting
`BEAM_RUNTIME_FLAVOR` is rejected. `CMAKE_BUILD_TYPE` defaults to `Release` and
accepts `Release` or `Debug` in a single-config build.

An individual SDK installation supplies one runtime choice. A combined SDK can
supply all four choices from one prefix. OTP uses the SDK's exported selected
archive and helper paths, so no archive filename is assumed. For example, the
same combined SDK can configure both `macos-arm64-emu` and
`macos-arm64-jit-debug`; each build links only its selected VM.

Python 3.9+ is required for the project-owned filesystem and process integration
checks. The original OTP test controller runs in Erlang. Test registration is
enabled by default. Configure with
`-DBUILD_TESTING=OFF` when only building and installing the product without a
Python dependency.

Keep the selected SDK stable between configuring and building OTP. After
rebuilding, reinstalling or replacing it, rerun the configure step before
building OTP, including when the SDK prefix and release version are unchanged.
Ordinary builds do not rehash the SDK on every invocation.

For native Linux x86_64:

```sh
export BEAM_SDK_ROOT=/absolute/path/to/installed/beam-sdk
export OPENSSL_ROOT_DIR=/usr
export OTP_WX_CONFIG=/absolute/path/to/wx-config
export JAVA_HOME=/absolute/path/to/jdk
export ODBC_CONFIG=/absolute/path/to/odbc_config
export FLEX_EXECUTABLE=/absolute/path/to/flex
cmake --preset linux-x86_64-emu
cmake --build --preset linux-x86_64-emu --parallel 4
ctest --preset linux-x86_64-emu
cmake --install build/linux-x86_64-emu
install/linux-x86_64-emu/bin/erl -noshell -eval 'io:format("~s~n", [erlang:system_info(version)]), halt().'
```

When the selected ODBC installation has no config program, configure with both
absolute native paths instead. For a selected Ubuntu amd64 unixODBC installation:

```sh
cmake --preset linux-x86_64-emu -DODBC_CONFIG= \
  -DODBC_INCLUDE_DIR=/usr/include \
  -DODBC_LIBRARY=/usr/lib/x86_64-linux-gnu/libodbc.so
```

A nonempty `ODBC_CONFIG` selects the config-program route and takes precedence
over direct paths. Without it, both direct paths are required and their headers
and `SQLAllocHandle` link capability are checked. Invalid selections fail rather
than discovering another installation. Windows continues using its selected SDK.

On native Linux AArch64, use `linux-aarch64-emu` and its matching build/install
directories. Use the preset matching the native host architecture. Configuration
always checks the actual C and C++ compiler targets against the native host and
selected SDK, including when configuring without a preset. Presets provide
standard settings and output paths; compatibility checks do not depend on them.

For macOS, select an installed OpenSSL prefix and an absolute wx configuration
script, then use `macos-arm64-emu`. For the currently selected caches:

```sh
export OPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3
export OTP_WX_CONFIG=/opt/homebrew/opt/wxwidgets@3.2/bin/wx-config-3.2
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ODBC_CONFIG=/opt/homebrew/bin/odbc_config
export FLEX_EXECUTABLE=/usr/bin/flex
```

macOS presets select Apple Clang, arm64 and deployment target `26.0`. The
selected wx/OpenSSL libraries require macOS 26; this product floor is separate
from the runtime SDK's 15.0 floor. A deployment target is not evidence that an
older OS was tested. Both platforms retain corresponding `*-jit` presets.
No package manager is invoked by the build.

Each EMU/JIT native preset has a corresponding `-debug` preset with separate
standard build and install directories. For a combined SDK on macOS, after
selecting the dependencies above:

```sh
export BEAM_SDK_ROOT=/absolute/path/to/combined/beam-sdk
cmake --preset macos-arm64-jit-debug
cmake --build --preset macos-arm64-jit-debug --parallel 3
ctest --preset macos-arm64-jit-debug
cmake --install build/macos-arm64-jit-debug
```

Alternatively, select the matching individual JIT Debug SDK prefix for that
preset. `linux-x86_64-{emu,jit}-debug` and
`linux-aarch64-{emu,jit}-debug` provide the corresponding Linux choices.
Linux amd64 follows the original component-specific compiler settings rather
than applying one optimization level to every native target. Debug also adds
the original Erlang `debug` definition to Diameter, ET, Megaco, Mnesia and ODBC.
Native definitions use the public headers and each component's original recipe;
they do not require private VM headers. Runtime probes require `{debug,true,true}` for
`{build_type,debug_compiled,lock_checking}` in Debug and `{opt,false,false}`
in Release. Every configuration keeps the ordinary OTP commands. Linux Debug
publishes `beam.debug.smp`, with relative `beam.smp` and selected-flavor aliases
to that same executable. These support ordinary startup and explicit Debug/flavor
selection in a prefix containing one selected VM. Ordinary-name aliases,
including an explicit `-emu_type opt` lookup, still select that prefix's Debug VM.
Crypto uses its original `.debug` native names; Runtime Tools also keeps ordinary
aliases for its unchanged Erlang loaders. Debug's relative child-helper alias is
staged before bootstrap and installed through the SDK's deployment helper.

wx uses its checked-in generated Erlang/C++ inventory; ordinary builds do not
run Doxygen or regenerate wrappers. Its two NIF modules use the installed public
SDK and retain upstream Objective-C/main-thread initialization. The build's
`wx-selection.json` records the selected configuration, flags, native dependency
hashes and deployment-floor evidence. Retained wx sources and resources can be
edited without updating frozen per-source hashes. wx/OpenSSL and the ODBC manager
remain external native dependencies of the installed product; Jinterface consumers
need Java. None supplies an alternative Erlang runtime.

The normal presets use `build/<preset-name>` and `install/<preset-name>`, such as
`build/macos-arm64-emu` and `install/macos-arm64-emu`. The installation prefix is
the OTP root:
`bin/erl`, `erts-<version>/bin/beam.smp`, `lib/<app>-<version>/`, `releases/`
and `usr/include/`. Override the prefix through CMake when needed. `DESTDIR`
stages that prefix using upstream install-time finalization:

```sh
DESTDIR=/absolute/workspace/tmp/staging cmake --install build/macos-arm64-emu --prefix /opt/otp
```

## Documentation status

The project does not support generating the complete original OTP documentation.
There are no documentation build options or targets. Ordinary installations,
`otp_release` trees and Windows installers omit generated HTML, Markdown, EPUB,
man pages, standalone EDoc chunks and Jinterface Javadoc.

Original documentation content, assets, index/deprecation generators and core
tools/configuration remain at their original source paths. The seven retained
`make/` inputs are `ex_doc.exs`, `ex_doc_vsn`, `ex_doc_link`,
`ex_doc.sha256sum`, `markdown_to_man.escript`, `fixup_doc_links.sh` and
`get_ex_doc_formats_no_epub.sh`. They have no maintained end-to-end invocation,
release assembly or completeness contract. Selecting ExDoc or GNU Make does not
enable a project documentation workflow.

Documentation parity with pinned original OTP remains unmet. This difference in
supported scope is recorded in the [source differences](source-differences.md#generated-documentation-omission).

## Windows

Load the Visual Studio 2022 x64 developer environment with its Windows SDK.
Use `windows-x86_64-emu`, `windows-x86_64-jit`, or the corresponding `-debug`
preset. Select a matching installed BEAM SDK, static OpenSSL and wxWidgets
dependencies, a JDK and Flex explicitly. Windows ODBC uses the Windows SDK.
These presets build the complete retained application set without generated docs.

Additional Windows selectors are:

| Selector | Input |
| --- | --- |
| `OTP_WINDOWS_RUNTIME_DLLS` | Semicolon-separated absolute paths to selected redistributable Release CRT DLLs and required dependency DLLs, including WebView2Loader when enabled |
| `OTP_NSIS_EXECUTABLE` | Absolute path to NSIS 3.02+ `makensis.exe`, used only by `otp_installer` |
| `OTP_VC_REDIST_EXECUTABLE` | Absolute path to the matching Release VC redistributable executable |

The presets read these selectors from environment variables with the same
names. The build acquires no dependencies and installs no system packages.

```powershell
cmake --preset windows-x86_64-emu
cmake --build --preset windows-x86_64-emu --parallel 3
ctest --preset windows-x86_64-emu
cmake --install build/windows-x86_64-emu
cmake --build build/windows-x86_64-emu --target otp_installer
```

`otp_release` assembles the versioned portable tree. `otp_installer` requires
Release and produces
`build/<preset>/packages/otp_win64_<OTP_VERSION>.exe` and its SHA-256 file.
It stages the unchanged upstream NSIS script and generates release definitions
in `CMakeFiles/otp/packaging`, preserving the upstream development, associations,
runtime Start Menu, registry and uninstaller behavior. Its documentation component
and documentation shortcuts are omitted. Creating the installer does not execute
it or register a service.

Native `Install.exe -s` finalizes command copies and boot selection. Installed
launchers discover their own tree without retaining a build `erl.ini` path.
The Windows publisher checks all existing destination leaves before replacing
the first file, rejecting incompatible open handles and directory reparse
points. Stop processes using an installation before refreshing it. Runtime
DLL inputs are hashed in `CMakeFiles/otp/install/windows-runtime-inputs.txt` and
deployed beside both public commands and the ERTS commands. Debug trees omit
Release CRT bundles and never redistribute developer Debug CRT DLLs; tests
select the matching developer runtime explicitly.

## Generated output

The preset binary directory mirrors upstream's build roles:

| Location | Purpose |
| --- | --- |
| `bootstrap/{bin,lib}` | Supplied compiler environment plus declared supplementary build tools |
| `bin/<TARGET>` | SDK-linked VM and native commands/helpers |
| `lib/<app>` | Unversioned application bytecode, resources and generated sources |
| `bin/erl`, `bin/erlc`, other local commands | Run the completed build tree |
| `erts/ebin`, `erts/preloaded/src` | SDK-supplied inspection bytecode and matching sources |
| `erts/start_scripts` | Versioned installation boot/release metadata |
| `CMakeFiles/otp` | CMake-only configuration, helper modules, execution scripts and stamps |
| `release/<TARGET>` | Versioned release assembled only by the explicit `otp_release` target |

`<TARGET>` comes from the installed SDK's `BEAM_SDK_HOST_TRIPLE`; it is the
architecture string used by that VM, rather than one guessed from this host.
SDKs lacking this field must be rebuilt and reinstalled before configuring OTP.
The installed product retains ordinary versioned application/ERTS directories.
The configure-time `sdk-selection.txt` receipt also records selected build type,
production source/toolchain and build identities, manifest/package hashes, and
the actual runtime archive, child-helper, and preload asset paths. Its archive
hash is the selected artifact's hash, including for combined SDKs. These are
diagnostic inputs; the installed product does not need this receipt or the SDK.

Application-owned CMake declarations select sources/resources and emit ordered
`erlc` invocations. Secondary and tertiary bootstrap stages add required tools
while the supplied compiler remains selected throughout. There is no separate
source-built compiler foundation. CMake executes compilation and staging jobs
with literal argument vectors and a controlled runtime environment, invokes
upstream generators directly, and uses a focused Erlang validator for
application metadata and build records. Generated command scripts live under
`CMakeFiles/otp/commands`.
Unchanged builds need no compiler/generator jobs, and declared missing outputs
are regenerated by their owners. Product code never depends on the private
development-documents repository.

Generated Stdlib Erlang sources use `lib/stdlib/src`, with Unicode
inputs in the sibling `lib/stdlib/uc_spec` directory. This source shape
lets upstream documentation tools identify the owning application. Compilation
runs from each source directory with a basename input, retaining upstream stack
filenames and ordinary product compiler metadata.

Run the completed build through `build/<preset-name>/bin/erl`. Assemble a
standalone release with `cmake --build build/<preset-name> --target otp_release`;
this uses the same atomic installation and finalization logic as a normal
installation and does not compile another copy of the applications.

Keep reusable dependency inputs outside build trees. Reserve repository `build/`
and `install/` trees for maintained standard preset outputs; refresh affected,
available native outputs after source changes and report any that remain stale
or unvalidated. Put task-specific configurations and all temporary build,
installation and validation trees in workspace `tmp/`, even when using a
standard preset as a base. Check available disk space before parallel builds.
Installation/test payloads can be substantial; normal test runners remove their
own private copies. They preserve the selected SDK and development builds.

## Full original OTP testing inputs

Product build coverage is 35 applications. The separate pinned test profile
selects those applications, emulator/system coverage, EPMD and yielding-C in 39
components. Reports establish the tests actually exercised; the expanded
selection does not extend earlier acceptance results.

The [original OTP test guide](otp-tests.md) describes exact-pin preparation,
original native preparation through the installed public SDK, private services
and explicit configuration gates. Enable the full CTest profile with
`OTP_ENABLE_TEST_SUITES=ON` in a task-specific build under workspace `tmp/`.
Select the original source inputs with `OTP_TEST_REFERENCE_GIT` and
`OTP_TEST_CONFIGURED_SOURCE`. The runner consumes an installed candidate and
separately supplied prerequisites. It performs no dependency acquisition or
system package installation.

## CI inputs

The manual `Installed SDK` workflow accepts an immutable SDK archive URL and
SHA-256, explicit provisioned native runner labels, a native preset, an OpenSSL
prefix and a wx selector. It installs no system packages. The archive contains
the installed prefix directly, including `manifest.json` and the package in
its declared directory. Individual and combined SDK archives use the same
workflow input. Each
run verifies the archive, checks that the runner matches the preset, configures
against that SDK, builds and executes CTest. Run each preset separately;
registering a Release or Debug choice is not evidence that it passed. The manual
preset choices retain the same native platforms; no automatic matrix or package
installation is added.
