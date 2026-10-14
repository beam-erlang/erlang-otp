# Building OTP against an installed SDK

OTP uses the installed `BEAM::RuntimeStatic`, `BEAM::NIF` and `BEAM::Driver`
targets. Product and private bootstrap hosts embed the same thirteen OTP-owned
startup modules using the retained upstream `make_preload` chunk selection and
explicitly select their linked native implementations through
public composition. BEAM embeds the remaining nine core modules. The selected
Embedding hosts include `<beam/beam.h>`; native support uses `<beam/native.h>`.
Boundary audits verify the consumed public header closure and its SDK hashes.
The SDK build identity is checked before composition; private VM headers, sibling
build inputs and an external compiler/runtime fallback are forbidden.

```sh
cmake --preset linux-emu -DBEAM_SDK_ROOT="$BEAM_PREFIX" \
  -DOTP_BEAM_SDK_VERSION="$EXPECTED_BEAM_VERSION" \
  -DOTP_BEAM_SDK_BUILD_ID="$EXPECTED_BEAM_BUILD_ID" \
  -DOTP_REFERENCE_PREFIX="$REFERENCE_OTP_PREFIX" \
  -DOTP_REFERENCE_PROVENANCE="$REFERENCE_PROVENANCE" \
  -DOTP_REBAR3_FILE="$REBAR3_FILE"
cmake --build --preset linux-emu
ctest --preset linux-emu
cmake --install build/linux-emu
```

Set the expected full BEAM version and build identity from the verified candidate
record, independently of the prefix under test. A preview suffix is significant.
These values do not change OTP_VERSION or ERTS reporting. Numeric CMake package
discovery alone does not establish preview compatibility.

The adopted [release policy](../../dev-documents/distribution-release-strategy.md)
identifies BEAM by its upstream ERTS base plus a distribution revision, such as
`17.0-r1-preview.1`. The expected SDK value is the complete producer-recorded
identity, including revision and preview designation. A matching ERTS base or maintenance-branch
number alone cannot replace exact SDK version, build identity and capability
checks. OTP's upstream application/runtime versions remain separately owned.

Use `linux-jit` with its matching SDK for JIT. Presets have no default SDK path.
The reference prefix and external provenance select a verified original-build
OTP 29.0 installation of the same flavor and features. The release check requires
the explicitly selected, checksum-pinned Rebar3 3.27.0 archive (Relx 4.10.0).
Missing reference/tool inputs fail their acceptance gates; they are not fetched
or replaced automatically. `otp-installed-tree` owns the full structural and
inspection-bytecode comparison; `otp-standard-release` owns independent isolated
release startup, restart, native and helper checks.
Build prerequisites are CMake 3.25, Ninja, C/C++ compilers, Perl, Python, Flex,
pkg-config, a JDK, OpenSSL, zlib, curses/terminfo, ODBC and wxWidgets/WebView/GLib/
OpenGL/GLU development files. `FLEX_EXECUTABLE` selects a nonstandard Flex.
Filesystem-isolated acceptance requires bubblewrap and namespace permission.
The wx build remains enabled; its graphical compatibility acceptance is deferred.
The build inventory includes all 35 applications, including Observer and Reltool.
Both flavors pass matching-reference tree comparison, complete installed-content
review, [selected headless acceptance](observer-reltool.md), allocator/crash-dump
checks and the complete playground matrix. See [assembly fidelity](assembly-fidelity.md)
for source identities, validation and the stable-installation refresh. Full OTP
compatibility remains unfinished; wx acceptance and release upgrades remain deferred.

## Native Windows development

Windows 11 AMD64 uses Visual Studio 2022 MSVC, CMake, Ninja, Python 3.12,
Perl, native WinFlex 2.6.4 and Java 17. Start an **x64 Native Tools Command
Prompt for VS 2022**, then run PowerShell from that environment. Neither WSL
nor MSYS2 compilers are used in these MSVC configurations. Both compile all 35 applications.
The Windows build uses wxMSW, Windows SDK ODBC and retained static zlib sources.

Reusable dependencies belong under the workspace `dependencies/windows-amd64-msvc/`
directory. Build OpenSSL 3.6.3 from its verified source archive in an MSVC environment:

```powershell
# From the extracted OpenSSL source directory; use absolute dependency paths.
perl Configure VC-WIN64A shared no-asm no-tests "--prefix=$OpenSSLPrefix" "--openssldir=$OpenSSLPrefix/ssl"
nmake
nmake install_sw
```

Build wxWidgets 3.2.10 as shared Release wxMSW. The tested configuration disables
Edge WebView integration, which would require a separate WebView2 SDK acquisition:

```powershell
cmake -S $WxSources -B $WxBuild -G Ninja -DCMAKE_BUILD_TYPE=Release `
  "-DCMAKE_INSTALL_PREFIX=$WxPrefix" -DwxBUILD_SHARED=ON `
  -DwxBUILD_SAMPLES=OFF -DwxBUILD_TESTS=OFF -DwxBUILD_DEMOS=OFF -DwxUSE_WEBVIEW_EDGE=OFF
cmake --build $WxBuild --parallel 8
cmake --install $WxBuild
```

Select the matching **installed** BEAM static SDK and its independently recorded
version/build identity. Run from this repository, with the dependency prefixes set:

```powershell
$Preset = 'windows-amd64-msvc-emu' # use windows-amd64-msvc-jit with its matching SDK
cmake --preset $Preset "-DBEAM_SDK_ROOT=$BeamPrefix" `
  "-DOTP_BEAM_SDK_VERSION=$ExpectedBeamVersion" `
  "-DOTP_BEAM_SDK_BUILD_ID=$ExpectedBeamBuildId" `
  "-DOPENSSL_ROOT_DIR=$OpenSSLPrefix" `
  "-DwxWidgets_DIR=$WxPrefix/lib/cmake/wxWidgets-3.2" `
  "-DFLEX_EXECUTABLE=$WinFlex" "-DOTP_SED_EXECUTABLE=$Sed" `
  "-DJava_JAVA_EXECUTABLE=$Jdk/bin/java.exe" `
  "-DJava_JAVAC_EXECUTABLE=$Jdk/bin/javac.exe" `
  "-DJava_JAR_EXECUTABLE=$Jdk/bin/jar.exe"
cmake --build --preset $Preset --parallel 8
ctest --test-dir "build/$Preset" -R '^otp-windows-development$' --output-on-failure
cmake --install "build/$Preset"
```

`Sed` selects an existing sed executable, for example Git for Windows' `usr/bin/sed.exe`;
it is a generator tool, not a compiler. Quote whole `-D` arguments containing paths.
Presets read SDK identity variables from the environment when explicit arguments
are omitted; preserve those values on subsequent preset configurations. Alternatively,
use `cmake -S . -B build/<preset>` to update an existing cache.

From ordinary PowerShell, add the installed `bin` directory to `PATH`:

```powershell
$env:PATH = "$OtpPrefix/bin;$env:PATH"
erl -noshell -eval 'io:format("~p~n", [erlang:system_info(otp_release)]), halt().'
erlc hello.erl
escript hello.escript
erl
```

Native commands discover the installation through their own executable location.
`beam.smp.exe` embeds the selected VM and OTP preloads; there is no runtime dependency
on the SDK installation. OpenSSL, its provider modules and wx DLLs are installed
with OTP. Application NIFs/drivers retain their normal `priv` locations. Unicode
paths use UTF-16 at Windows boundaries and UTF-8 inside the product. A native
UTF-8 process manifest also gives library DLL loaders the same path encoding;
see Microsoft's [activeCodePage documentation](https://learn.microsoft.com/en-us/windows/win32/sbscs/application-manifests#activecodepage). Windows installs
native commands and boot resources directly instead of running the Unix `Install`
script; Unix child helpers and `run_erl`/`to_erl` are platform-specific.

`otp-windows-development` installs into a fresh path containing spaces and Unicode,
builds an external NIF with installed headers, compiles Erlang sources, exercises
supervision, registry access, files, both TCP backends, verified-peer TLS, child
programs, escripts and the shell, then relocates the installation and repeats.
It sanitizes runtime search paths and uses an unrelated working directory. It is
a practical development smoke check; it does not establish filesystem isolation,
full upstream equivalence, complete suite coverage or release qualification.
Standalone Unix internal support archives are not built on Windows; ordinary EI
libraries and public NIF/driver development headers are installed. GUI checks require
a desktop and genuine attendance for guarded OpenGL work. See the
[Windows development record](../../dev-documents/windows-development-baseline.md)
for executed checks and remaining limitations.

For the attended desktop checks, compile the owned interactive fixture with the
installed `erlc`, then start one application at a time. Exercise a control and
close the window normally; the fixture reports the monitored application's exit:

```powershell
$GuiWork = 'C:/path/to/workspace/tmp/otp-windows-gui'
New-Item -ItemType Directory -Force $GuiWork
& "$OtpPrefix/bin/erlc.exe" -o $GuiWork tools/fixtures/windows/otp_windows_gui.erl
$env:OTP_GUI_APP = 'observer' # wx, observer, reltool, debugger, et
& "$OtpPrefix/bin/erl.exe" +S 2:2 -noshell -noinput -pa $GuiWork -s otp_windows_gui run
```

The separate retained `tools/fixtures/otp_wx_probe.erl` exercises OpenGL and three
runtime boots. Run it only with a person present, using a fresh `OTP_WX_STATE`
file path per flavor. Its renderer, frame-buffer operations and normal resource
destruction assertions remain intact.

### Windows UCRT64 GCC

The `windows-amd64-ucrt64-emu` and `windows-amd64-ucrt64-jit` presets consume
the corresponding installed GCC BEAM static SDK. Use native UCRT64 GCC/G++,
CMake, Ninja and windres, with native Python, Perl, WinFlex and Java 17.
The dependency inputs are the installed UCRT64 OpenSSL 3.6.4 and shared wxMSW
3.2.11 packages. Retained zlib is still compiled separately as a static library.
Use the prepared UTF-8 toolchain copy described in the
[BEAM build guide](../../beam-erlang/README.md#windows-ucrt64-gcc) for native
compilation in Unicode paths. Its executable code and dependency package versions
are unchanged; the installed MSYS2 prefix remains intact.

From ordinary PowerShell, using explicit absolute paths and independently recorded
SDK identity values:

```powershell
$Ucrt = $PreparedUcrt
$env:PATH = "$Ucrt/bin;$env:PATH"
$Preset = 'windows-amd64-ucrt64-emu' # or windows-amd64-ucrt64-jit
& "$Ucrt/bin/cmake.exe" --preset $Preset `
  "-DCMAKE_C_COMPILER=$Ucrt/bin/gcc.exe" `
  "-DCMAKE_CXX_COMPILER=$Ucrt/bin/g++.exe" `
  "-DCMAKE_RC_COMPILER=$Ucrt/bin/windres.exe" `
  "-DCMAKE_MAKE_PROGRAM=$Ucrt/bin/ninja.exe" `
  "-DCMAKE_OBJDUMP=$Ucrt/bin/objdump.exe" `
  "-DCMAKE_AR=$Ucrt/bin/ar.exe" "-DCMAKE_RANLIB=$Ucrt/bin/ranlib.exe" `
  "-DCMAKE_LINKER=$Ucrt/bin/ld.exe" "-DCMAKE_NM=$Ucrt/bin/nm.exe" `
  "-DBEAM_SDK_ROOT=$BeamPrefix" `
  "-DOTP_BEAM_SDK_VERSION=$ExpectedBeamVersion" `
  "-DOTP_BEAM_SDK_BUILD_ID=$ExpectedBeamBuildId" `
  "-DOPENSSL_ROOT_DIR=$Ucrt" `
  "-DwxWidgets_DIR=$Ucrt/lib/cmake/wxWidgets-3.2" `
  "-DPython3_EXECUTABLE=$Python" "-DPERL_EXECUTABLE=$Perl" `
  "-DFLEX_EXECUTABLE=$WinFlex" "-DOTP_SED_EXECUTABLE=$Sed" `
  "-DJava_JAVA_EXECUTABLE=$Jdk/bin/java.exe" `
  "-DJava_JAVAC_EXECUTABLE=$Jdk/bin/javac.exe" `
  "-DJava_JAR_EXECUTABLE=$Jdk/bin/jar.exe"
& "$Ucrt/bin/cmake.exe" --build "build/$Preset" --parallel 6
& "$Ucrt/bin/ctest.exe" --test-dir "build/$Preset" -R '^otp-windows-development$' --output-on-failure
& "$Ucrt/bin/cmake.exe" --install "build/$Preset"
```

Use a clean compiler environment; do not inherit Visual Studio `INCLUDE`, `LIB`
or compiler override variables. The configuration rejects an MSYS `/usr` compiler
and a BEAM SDK from another compiler environment. Keep native extensions matched
to the selected SDK. CMake scans actual PE imports with the selected `objdump`,
bundles the native GCC/wx/OpenSSL dependency closure, and rejects an
`msys-2.0.dll` dependency. Installed commands run with only their installed `bin`
and Windows system directories on `PATH`. UCRT64 is needed for subsequent native
compilation, not normal execution.
Both flavors build all 35 applications and reproduce the 277 attested bootstrap
modules. See the [UCRT64 Windows checkpoint](../../dev-documents/windows-ucrt64-development.md)
for installed/relocated acceptance, attended GUI/OpenGL results and concrete limits.

## macOS bring-up checkpoint, 2026-10-24

The experimental `macos-arm64-appleclang-emu` and
`macos-arm64-appleclang-jit` configure/build/test presets select ARM64 Apple Clang
with deployment target 15.0 and the same explicit installed-SDK identity contract.
Their presence does not establish a passing product build or macOS 15 execution.
The product and private bootstrap hosts now discover their executable through
Darwin's native executable-path mechanism. OS Monitor admits the retained Darwin
helper implementations. wx configuration selects Cocoa, Objective-C initialization
and framework OpenGL headers rather than requiring Linux GLib inputs.

Both EMU and JIT configure, build and install the complete current application
inventory on macOS 26.6.2 ARM64 with Apple Clang 21.0.0, SDK 27.0, CMake 4.4.3,
Python 3.12.14, OpenSSL 3.6.3, Java 17, Flex 2.6.4, system zlib, unixODBC 2.3.14
and wxWidgets 3.2.10. Including Darwin's locale declarations fixes bootstrap-host
compilation. All 277 source-attested bootstrap modules and boot resources then
reproduce deterministically before ordinary application compilation.

The normal BEAM distribution supplies the installed SDK, including its bundled
package tool. The current EMU SDK build is
`3b6bc1c42976f9c2187e9af73b52fe98f5ba67b542aea4dc711f38ec2de03e2d`;
the JIT SDK build is
`64c415417f847f3d6444781b13219e941c193de4a408955862773df491553706`.
Darwin product tests use native process/image observations and Seatbelt, with
upstream suite assertions preserved. The complete private consumer inventory
runs on the candidate and matching original releases. See the
[macOS acceptance record](macos-development.md) for final-host results, exact
inputs, remaining coverage and cleanup; a build alone does not close its gates.

The private seed host embeds the thirteen selected seed preloads and executes
only the source-attested bootstrap inventory. All 277 outputs and boot resources
must reproduce before the source-built host compiles applications. Refresh seed
candidates with `cmake --build build/<preset> --target otp_refresh_bootstrap_seeds`;
review source changes and complete candidate inventory before adoption. Normal
builds never modify checked seeds. No deployment copies or broad inventory
exclusions are used. Original imported bootstrap resources remain unchanged.

Installation uses the retained upstream `Install -minimal` finalization workflow.
The executable is `erts-<version>/bin/beam.smp`; the generic child helper is a real
file obtained from the SDK's verified artifact inventory. Built-in NIFs, drivers
and socket implementation are linked into the executable. Application-owned
dynamic extensions remain at their upstream paths. Inspection bytecode under
`lib/erts-<version>/ebin` comes from the same canonical outputs as embedded bytes;
startup never acquires those thirteen modules from inspection files. Standard
sources, development headers/libraries, resources, commands and links follow the
original-build reference. No VM library or validation manifest is installed.

`build/<preset>/sdk-selection.json` records SDK identity and consumed artifact
hashes. Native/host object imports and installed-header dependencies are audited
before linking; executable exports and dynamic dependencies are checked separately.
`otp-development-support` checks installed standalone support libraries and the
native test-table ABI. Independent preparation, observer, native activation and
product fixtures preserve copied inputs, failure/recovery, restart and actual
runtime/helper origins after relocation and filesystem isolation.

`tools/installation_inventory.py` captures external format-1 provenance, verifies
every installed byte and compares every relative path (including the root), entry type, permission and
literal symlink target with the pinned original build. Only file contents are
omitted from structural comparison; no directories are excluded. Generate the
reference using the artifact repository's sequential distribution recipe and
retain source/configuration evidence outside both prefixes:

```sh
python3 tools/installation_inventory.py capture --prefix "$OTP_PREFIX" \
  --runtime candidate --flavor emu --evidence "$BUILD_EVIDENCE" --output "$OTP_PROVENANCE"
python3 tools/installation_inventory.py verify --prefix "$OTP_PREFIX" --provenance "$OTP_PROVENANCE"
python3 tools/installation_inventory.py compare --candidate "$OTP_PROVENANCE" \
  --reference "$REFERENCE_PROVENANCE" --output "$TREE_COMPARISON"
```

Build evidence identifies the pinned commit, source tree, selected SDK identity,
static archive and link-support hashes. Candidate provenance also records
`build.linkage = "static"` and `build.sdk` with `build-id`, `runtime` and
`runtime.static` checksums for the explicit SDK/product pairing. Provenance is an
acceptance input, never an ordinary OTP user requirement.

For long upstream fixture paths, select `OTP_SHORT_TEST_ROOT`. PostgreSQL/ODBC,
OpenLDAP and vsftpd interoperability prerequisites remain explicit; missing inputs
are incomplete gates. The [current implementation record](../../dev-documents/static-sdk-otp-runtime.md)
distinguishes current checks from the historical checkpoints below. Historical
paths, linkage, counts and failures are retained as evidence of those builds.

## Verified dependency checkpoint

The foundation configured, built and passed both CTest cases for each flavor
against the following installed SDK identities. The source revisions observed
at validation were OTP `72a1beb074a9fb8481d652418db80255c2962008` and BEAM
`795e3ac7fa39433cce26bc979bd8889da324d52a`; the OTP build-guide corrections
remained uncommitted.

| Flavor | SDK build identity | Runtime library SHA-256 |
| --- | --- | --- |
| Interpreter | `7703c118012ffaf59f3bb2c3aeb9c701ee5d2c13ad7480bde269a53e16e1d18f` | `f855c0a1f028f40b572136eda9a2ebba39fa36d30597a2aa6dc40d405cfb9cff` |
| JIT | `7ca40e825685124d17478e1595378a36a35ad838e059b66e419da5365865d32b` | `4c79284cd516c1a637961e87def833933b7e1843d6a71cc247341d5ba1b3307d` |

Each probe exercised the nine embedded core modules, checked its executing
flavor, and completed VM/system teardown. Dependency inspection found only
the selected installed `beam.h` and twelve declared public runtime imports.
The probe links directly to `libbeam.so` and libc, with a development RUNPATH
pointing to the selected SDK's `lib` directory. This is an SDK consumer check,
not an independently deployable OTP command.

Four negative configurations per flavor also passed: an omitted SDK prefix,
the opposite requested flavor, an SDK copy without the runtime-artifact API
include, and an SDK copy missing its declared hostname helper. Each failed with
the expected selection/capability diagnostic. The missing-API case deliberately
modified a disposable SDK copy; it was not a test against a historical SDK.

The commands above reproduce the positive checks. CTest stores its execution
record under each build directory; `sdk-selection.json` records the exact
selected artifacts. Disposable copies of these records and the negative-case
commands/results were saved under workspace scratch
`tmp/otp-installed-sdk-foundation/`. This evidence covers the installed dependency
foundation at that checkpoint, before upstream suites were run. Later product
and suite evidence is recorded below.

## Initial installed product checkpoint

The subsequent assembly builds 283 application modules and thirteen external
preloads. An OTP-owned C host selects these preloads, immutable startup context,
process policy and native admission through `beam.h`, then enters `erl_init:start/2`.
It imports neither VM-private symbols nor the transitional `beam_boot_*` adapter.
Nine core modules remain supplied by `libbeam`. Source-built SASL supplies
`systools` for the retained `start_clean`, `no_dot_erlang` and `start_sasl`
release templates. Default `start.boot` uses the clean profile and starts only
kernel and STDLIB; compiler code autoloads. The SASL profile additionally starts
SASL. Clean profiles produce the expected systools `missing_sasl` warning.

Six retained preload wrappers now resolve their native paths from the host's
immutable context. `erl_init` acquires declared inet drivers in the initial
process, retaining ownership across restart. These seven focused product-source
adaptations do not change upstream suite sources or fixtures. Applications are
compiled from retained OTP sources; the SDK contributes only declared runtime
artifacts, including its matching native dependency closure and helpers.

The initial 296 generated BEAM files were byte-identical between flavors. Both
flavors passed five checks against the historical SDK identities above:

- Installed SDK smoke and imported-header/symbol checks.
- Source-built compiler and generated parser execution.
- The production host's public-header and symbol boundary.
- Fresh installation followed by relocation to a path containing spaces,
  source-built application origins, normal installation-root lookup, 22 sticky
  preloads, ordinary driver activation, zlib and zstd, files, external programs,
  hostname lookup, inet/socket networking, and three boots including two restarts.
  `/proc/self/maps` confirms the relocated `libbeam` and excludes the SDK prefix.

CTest `initial-product` installs into temporary storage under the build tree,
relocates it and runs from an unrelated working directory with isolated user
configuration. The original SDK/source trees remain accessible: a stronger
unavailability test is still required for final product acceptance. Local socket
access is required; sandbox denial is not a passing result. Logs are recorded
under each build's `Testing` directory and disposable workspace
`tmp/otp-product-{api,native}-{emu,jit}.log` files.

## Commands and isolated product checkpoint

The current build also installs unchanged upstream C front ends for `erlc`,
`escript` and `erl_call`. `cmake/OTPCommands.cmake` owns ordinary EI and standalone
formatter compilation and platform probes. Both EI libraries and their public
headers install under `usr/` and the versioned Erlang Interface application.
No VM-private dynamic imports supply command support. At this checkpoint,
runtime-coupled native services come from the selected SDK artifact contract;
that build ownership is transitional under the target boundary above.

Implemented `+` options translate into typed public VM values: scheduler/dirty
scheduler counts, async and I/O threads, process/port/atom limits, heap values
and interrupt policy. `+sbt u` selects the public lifecycle's unbound behavior;
other binding selections and unsupported switches fail explicitly. Arguments
after `-extra` remain literal. This is not yet complete upstream command parsing.

Six CTests now pass on each flavor, including unchanged `erlc`/`escript` command
execution, installed threaded/non-threaded EI clients, real terminal shell
bindings and clean/SASL boot profiles. `isolated-product` repeats the product
checks using `bwrap`, with the workspace, original SDK and source/build trees
unavailable. Both the parent VM and its command subprocesses use the relocated
installation. This supersedes the earlier relocation-only limitation.

The [command-hosting record](../../dev-documents/otp-ownership-cutover.md#historical-command-hosting)
records current source revisions, both SDK identities and binary hashes,
full runtime/playground/GLM acceptance, and the exact bounded product evidence.
All upstream suite sources, assertions, fixtures and bootstrap artifacts remain
unchanged. Full environment/argument parsing, private resources and helper layout,
native-extension SDK installation, distributed-node execution, unchanged upstream
suites, complete application assembly and release upgrades remain unfinished.
`erl_call` is built and installed but not yet exercised against a node. This
checkpoint does not establish full OTP compatibility.

## Initial unchanged upstream suites

Common Test and Syntax Tools now build and install from retained sources,
including Common Test's private logging resources and Syntax Tools' transform
bootstrap. The current output contains 339 application modules and thirteen
external preloads, byte-identical between flavors. All nine OTP CTests pass per
flavor, including the complete unchanged Base64, math and queue suites: thirty
cases per flavor, no failures or skips. The [upstream testing record](upstream-testing.md)
describes preparation, source hashes, exact coverage and remaining fixture work.
This supersedes the earlier checkpoint's absence of upstream-suite execution;
it does not close the broader testing or product-compatibility gates.

## Upstream launcher and local distribution

The retained `erl` script and `erlexec` now own environment/argument-file parsing,
detached startup and EPMD launch policy. The public-API host and standard helper
links install under `erts-17.0/bin`; `libbeam.so` remains the sole VM. EPMD and
native `ct_run` are built from unchanged sources. Both flavors pass all ten OTP
CTest checks, with native `ct_run` additionally exercising the unchanged Base64
suite. The [command record](commands.md) covers local named-node/EI/RPC evidence,
source boundaries, invocation details and remaining command/VM-policy gaps.
This supersedes earlier notes about missing environment parsing, helper layout
and unexecuted `erl_call`; full installation and compatibility remain incomplete.

## Native extension headers and fixtures

The installed product now obtains both common and versioned ERTS extension
headers through the public SDK deployment operation. Unchanged upstream NIF
and driver inputs compile and execute after relocation on both flavors,
including with the original SDK/source/build trees unavailable. See the
[native extension record](native-extensions.md) for identities, exact fixture
coverage, corrected harness failure and remaining suite work.

## Crypto application checkpoint

Crypto 5.9 now builds its Erlang/native artifacts against the installed public
NIF SDK and system OpenSSL. Both flavors pass relocated, isolated and restart
checks. The unchanged engine suite reports 28 passed and three upstream skips;
its strict coverage gate remains nonpassing, while the other eleven OTP checks
pass. See the [Crypto record](crypto.md) for exact skip causes, dependency
selection and remaining coverage. The source-built output is now 354 Erlang
artifacts across nine application resources and external preloads.

## ASN.1 assembly checkpoint

ASN.1 5.5 adds its source generators, 22 product modules and a public-SDK NIF.
The product contains ten application resources and 376 BEAM artifacts, identical
between flavors. Both flavors pass the unchanged application and syntax suites
(17 cases), plus relocated/isolated codec checks across restart. Generated
PER/UPER example constants still fail a separate strict gate, alongside the
existing nonpassing Crypto engine coverage gate. See [ASN.1 evidence](asn1.md)
for the source explanation, exact commands and pending coverage.

## Tools and Public Key assembly

Tools 4.2 and Public Key 1.21 now build from retained sources and generated
parser/ASN.1 inputs. Both flavors produce twelve application resources and 434
identical BEAM artifacts. Public Key signing and DER/PEM checks pass across
relocation, filesystem isolation and restart. See [assembly evidence](public-key.md)
for generation, source ownership, installed resources and remaining coverage.

## SSL assembly and upstream value parity

SSL 11.7 adds 78 modules and its retained source headers. The build supplies
Public Key as an explicit source-built code/header dependency, including its
generated public header. Both flavors produce thirteen application resources
and 512 identical BEAM artifacts. See [SSL evidence](ssl.md) for authenticated
TLS 1.2/1.3, both networking backends, restart/isolation and 15 unchanged suite
cases per flavor. The earlier generated-value round-trip gate has been
corrected to [exact pinned-upstream parity](asn1.md#pinned-upstream-comparison);
it now passes without changing upstream code or tests.


Runtime Tools 2.4 adds twelve source-built modules, its public headers/examples,
and the source-owned file-trace driver. The matching SDK supplies VM-configured
dynamic/IP tracing artifacts. Both builds now contain fourteen application
resources and 524 byte-identical BEAM files. The complete application/debugger
suites and relocated/isolated tracing across restart pass on both flavors;
see [native ownership and acceptance](runtime-tools.md). The Crypto engine gate
still has three upstream skips; broader compatibility remains incomplete.

## Database and HTTP assembly

Mnesia and Inets add 94 unchanged source-built modules. Both flavors contain
sixteen application resources and 618 identical BEAM files. Database persistence
and HTTP client/server checks pass after relocation, isolation and restart;
37 unchanged upstream cases pass per flavor. See [database/HTTP evidence](database-http.md)
and the [complete application inventory](application-coverage.md). Nineteen
applications remain unbuilt; broader compatibility and the Crypto engine skip
gap remain open.

## EUnit and XML assembly

EUnit and Xmerl add 48 modules, source-owned transforms/grammars and SAX source
generation. Both flavors contain eighteen applications and 666 identical BEAM
files. All 605 preceding application modules remain unchanged. Relocated and
isolated consumer compilation, XML parsing and restart checks pass. Five
unchanged upstream selections add 162 passing cases per flavor; see
[XML and unit-testing evidence](xml-unit-testing.md). Seventeen applications
remain in the [assembly inventory](application-coverage.md); the Crypto engine
skip gap and broader compatibility remain open.

## File-transfer assembly

FTP and TFTP add fourteen modules, bringing both installations to twenty
applications and 680 identical BEAM files. Actual TFTP transfers pass after
relocation, isolation and restart; unchanged response and TFTP suites add 21
passing cases per flavor. The complete FTP interoperability suite reports 74
passed and ten setup skips per flavor and remains a nonpassing gate. See
[file-transfer evidence](file-transfer.md) for the explicit vsftpd dependency,
namespace isolation and TLS/setup gaps. No retained sources or SDK change.

## SSH assembly

SSH adds 43 source-built modules with explicit behavior ordering and a generated
Public Key header dependency. Both installations now contain twenty-one
applications and 723 identical BEAM files; all 667 preceding application modules
are unchanged. Authentication, command execution and SFTP transfer pass after
relocation, isolation and restart. The complete unchanged basic suite passes
49 cases per flavor without skips; see [SSH evidence](ssh.md). Broader SSH
interoperability and the remaining fourteen applications are still required.

## EDoc and ERTS application resources

EDoc builds its retained parser grammar and 21 modules, with Xmerl as an explicit
dependency. Its private HTML/image/DTD assets and selected EDoc/Syntax Tools
sources are installed for documentation generation. The standard
`lib/erts-17.0/ebin` tree combines thirteen OTP-owned preloads with exact copies
of the nine VM-owned core inputs supplied by `beam_install_core_modules`, plus
`erts.app` generated from its retained template. Host acquisition follows that
same layout. No private SDK source paths or duplicate VM compilation are used.

Both flavors have 22 applications and 753 byte-identical BEAM files. Relocated
and isolated HTML/EEP-48 generation and restart pass; the complete EDoc suite
passes ten cases. EEP-48 reports 40 passes and four explicit unsupported-case
skips, leaving its strict gate incomplete. See [evidence and provenance](edoc.md).

## ELDAP assembly

ELDAP adds its API module and a BER codec generated from the retained schema
with `legacy_erlang_types`. Public/schema inputs and the generated record header
are installed in their upstream application locations. Both products contain
23 applications and 755 byte-identical BEAM files; every preceding bytecode file
is unchanged. Relocated/isolated codec checks and authenticated LDAP operations
with verified TLS pass. The complete unchanged 116-case suite reports 56 passes
and 60 TLS setup skips per flavor, leaving its strict gate incomplete. See
[ELDAP preparation and evidence](eldap.md).

## Diameter and inspection metadata

Diameter adds 47 modules, its source-owned parser and dictionary generation,
installed schemas/headers/examples and `diameterc`. Assembly covers 24
applications and 802 BEAM files. OTP application compilation retains ordinary
compiler-option and source metadata for inspection tools; deterministic
bootstrap tools remain separate. Execution chunks match across flavors, while
application metadata records the actual build paths.

The SDK supplies complete inspection metadata for its nine core modules, with
unchanged embedded execution chunks. OTP combines `prim_eval` assembly with
abstract forms using the retained upstream generator. These build corrections
preserve Xref inputs without copying private VM sources or altering suites.
See [Diameter evidence and provenance](diameter.md) for current acceptance.

## Linux OS Monitor

OS Monitor adds eight modules and two standalone Linux port programs under its
private application directory. They compile from retained C sources using only
OS interfaces and libc, without private VM dependencies. Both products contain
25 applications and 810 BEAM files; preceding application bytecode and SDK
artifacts remain unchanged. Relocated/isolated monitoring, helper shutdown and
restart pass. The four complete Linux suite selections report 22 passes and
one host-load skip per flavor. See [OS Monitor evidence](os-monitor.md).

## Java interoperability library

JInterface adds its source-built JAR, application resources and Java sources.
CMake requires a JDK through its standard Java package discovery. There are now
26 assembled applications, with nine still pending. Both flavors pass relocated
and isolated product checks and 55 unchanged Java suite cases; two cases are
explicit upstream skips. See [JInterface evidence](jinterface.md) for toolchain
selection, isolation, provenance and the remaining strict coverage gap.

## Dialyzer and Typer

Dialyzer adds 29 source-built modules, its source/header resources and the
unchanged native `dialyzer` and `typer` front ends. Version values come from
the retained version table. The selected application count is 27, with eight
remaining; there are 839 installed BEAM files. Existing artifacts and the SDK
remain unchanged. See [Dialyzer assembly](dialyzer.md) for command, PLT and
upstream-suite evidence and remaining coverage.

## SNMP

SNMP adds 90 modules, source-built MIB and ASN.1 generators, 18 compiled standard
MIBs and public headers, and its command/configuration resources. CMake preserves
explicit bootstrap ordering and consumes only installed SDK tooling. See
[SNMP assembly and acceptance](snmp.md) for the converter portability changes,
agent/manager checks and unchanged upstream suite selection.

## Megaco

Megaco adds 65 modules, six ASN.1 codecs, four Yecc parsers and both standard and
reentrant native Flex scanners. The ordinary extensions use `BEAM::Driver`;
protocol policy and generated artifacts belong to OTP. See [Megaco assembly](megaco.md)
for generator flags, installed resources, public-header checks and unchanged
upstream acceptance.

## ODBC

ODBC builds its three product modules and EI-linked port program against the
system driver manager. CMake preserves the native IPv6 capability probe and
standard private-resource layout. Database acceptance requires an explicitly
selected PostgreSQL 18/psqlODBC package root via `OTP_POSTGRES_ROOT`; see
[ODBC assembly](odbc.md) for namespace isolation and unchanged suite selection.

## wx

wx builds 241 retained Erlang bindings and two ordinary native extensions through
`BEAM::NIF`, with explicit GUI and OpenGL dependencies. Both flavor installations
succeed. BEAM's private PCRE visibility correction passes full shared-runtime
and consumer acceptance. Three unchanged wx suites pass (28 cases per flavor);
restart, GTK child-process integration, a Debugger resource and manual OpenGL
coverage remain incomplete. wx work and acceptance are explicitly deferred;
`OTP_ENABLE_WX_TESTS` defaults to `OFF`, retaining disabled checks for later
opt-in. Other applications and their non-GUI behavior remain in scope.
See [wx evidence](wx.md) for the original defect,
corrected SDK identities, upstream-runtime comparisons and independently failing
checks. No upstream wx sources or assertions were changed.

## Debugger

Debugger adds 24 retained modules and its licensed image resource. Standard
product sources also install for Kernel, STDLIB, Compiler and Parsetools, so
Debugger inspection uses the installed application tree. Headless interpretation,
breakpoints and four unchanged suites have dedicated acceptance; graphical
coverage remains deferred with wx. See [Debugger assembly](debugger.md).

## Private startup acquisition

The installed command host and both private bootstrap hosts compile the same
`tools/otp_host_inputs.c`. It acquires the thirteen selected preload files and
encodes native paths, immutable origins and literal startup arguments from the
OTP-owned inventory. It returns owned inputs for generic public composition and
VM initialization, with no VM operations during acquisition. Returned failures
release partial inputs and leave the caller's output unchanged; release is
idempotent. Scheduler and process-policy selection remain in the command host.

Fresh complete interpreter/JIT builds and the transferred
`otp-host-preparation` fixture pass. The fixture covers bounded partial acquisition,
allocation and descriptor failures, retry/cancellation, host-state preservation,
copied bytes and normal/custom boot paths in fresh, relocated and isolated
installations. The first fixture attempt omitted its required `-bindir` input; its corrected
retry passes with the original failure retained in development evidence.
Broader product checks retained the ET failure at that checkpoint; the later
[ET comparison](et-sendfile-comparison.md) corrects the owning probe and passes
complete three-boot product checks on both flavors. This private helper is
not an installed SDK interface. See the
[preparation transfer plan](../../dev-documents/otp-ownership-cutover.md).
