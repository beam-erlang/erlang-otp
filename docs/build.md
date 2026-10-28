# Building OTP against an installed SDK

OTP requires an explicitly selected installed BEAM SDK with `BEAM::RuntimeStatic`,
`BEAM::NIF`, `BEAM::Driver` and verified public artifact/header deployment. Product
and private compiler hosts use the same OTP-owned native/preload inventory.
[Architecture](architecture.md) defines the boundary; no private VM header,
sibling build or external compiler/runtime fallback is permitted.

## Linux build and acceptance inputs

Use CMake 3.25 or newer, Ninja, C/C++ compilers, Perl, Python 3.9 or newer,
Flex 2.6 or newer, pkg-config and a JDK. Native dependencies include OpenSSL,
zlib 1.2.8 or newer with `inflateGetDictionary`, curses/terminfo, ODBC development
files and wxWidgets 3.2 or newer with WebView/GLib/OpenGL/GLU dependencies.
`FLEX_EXECUTABLE` and normal CMake dependency settings select nonstandard inputs.
The application inventory includes all 35 OTP 29.0 applications. Disabling wx
tests does not remove GUI build dependencies or the compatibility requirement.

Set expected SDK identity independently of the prefix under test. Use the full
producer-recorded version, including distribution revision/preview suffix,
plus exact build identity and matching flavor. Numeric CMake discovery or a
common ERTS base cannot replace these checks. SDK values do not change OTP's
own version table/reporting.

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

Repeat with `linux-jit` and its matching SDK/reference. Presets use ignored
`build/<preset>` and `install/<preset>` directories and have no default SDK path.
They read SDK identity variables from the environment when explicit arguments
are absent; preserve those values when reconfiguring or update an existing cache
with `cmake -S . -B build/<preset>`.

The reference must be an attested original-build OTP 29.0 installation with the
same flavor/features. `OTP_REBAR3_FILE` selects the checksum-pinned Rebar3 archive
used by `tools/check_release.py`. Missing inputs fail the corresponding gate;
builds/tests do not fetch or substitute them. Filesystem isolation requires
bubblewrap with private namespaces on Linux. Service checks select vsftpd,
OpenLDAP and PostgreSQL/psqlODBC through explicit settings in
[test preparation](test-preparation.md#external-services).

`OTP_ENABLE_WX_TESTS=ON` runs the graphical tests; the default disabled entries
remain untested. Read [compatibility](compatibility.md) before interpreting a
complete or focused CTest result. Build success, smoke checks and recorded run
output establish different claims from full product qualification.

## Native Windows development

Windows 11 AMD64 uses Visual Studio 2022 MSVC, CMake, Ninja, Python 3.12,
Perl, native WinFlex 2.6.4 and Java 17. Start an **x64 Native Tools Command
Prompt for VS 2022**, then run PowerShell from that environment. Neither WSL
nor MSYS2 compilers are used in these MSVC configurations. Both compile all 35 applications.
The Windows build uses wxMSW, Windows SDK ODBC and retained static zlib sources.

Select verified dependency packages and extracted inputs explicitly; keep reusable
inputs separate from mutable build/test output. Build OpenSSL 3.6.3 from its verified source archive in an MSVC environment:

```powershell
# From the extracted OpenSSL source directory; use absolute dependency paths.
perl Configure VC-WIN64A shared no-asm no-tests "--prefix=$OpenSSLPrefix" "--openssldir=$OpenSSLPrefix/ssl"
nmake
nmake install_sw
```

Build wxWidgets 3.2.10 as shared Release wxMSW. This configuration disables
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
a desktop and genuine attendance for guarded OpenGL work. See
[test preparation](test-preparation.md#graphical-and-native-platform-checks) for
the observation and coverage boundaries.

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
Select installed UCRT64 OpenSSL and shared wxMSW dependencies matched to the
compiler environment. Retained zlib is still compiled separately as a static library.
Use the prepared UTF-8 toolchain copy described in the
[BEAM build guidance](../../beam-erlang/cmake/README.md) for native
compilation in Unicode paths without modifying the original compiler prefix.

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
Both flavors use the same complete application and attested-bootstrap inventories.
The smoke/GUI checks have the same qualification limits as the MSVC configuration.

## macOS development

The `macos-arm64-appleclang-emu` and `macos-arm64-appleclang-jit` presets select
ARM64 Apple Clang and deployment target 15.0. Select the matching installed SDK,
OpenSSL, zlib, unixODBC, wxWidgets/Cocoa, Java, Flex and ordinary build tools:

```sh
cmake --preset macos-arm64-appleclang-emu \
  -DBEAM_SDK_ROOT="$BEAM_PREFIX" \
  -DOTP_BEAM_SDK_VERSION="$EXPECTED_BEAM_VERSION" \
  -DOTP_BEAM_SDK_BUILD_ID="$EXPECTED_BEAM_BUILD_ID"
cmake --build --preset macos-arm64-appleclang-emu
ctest --preset macos-arm64-appleclang-emu
cmake --install build/macos-arm64-appleclang-emu
```

Repeat with the JIT preset and matching SDK. Cocoa initialization and framework
OpenGL replace Linux-specific GUI dependency choices. The host/private compiler
use Darwin executable discovery and UTF-8 filenames even under the C locale.
Platform/deployment presets do not prove execution on the oldest deployment
system. Darwin resource observations, Seatbelt and disposable-worker requirements
are documented in [test preparation](test-preparation.md).

## Bootstrap and application generation

The independent [bootstrap](../bootstrap/README.md) verifies source-attested
seeds and deterministic foundation outputs before ordinary compilation. Every
generator uses OTP's private source-built host. Normal builds do not modify
tracked seeds and do not require the modern BEAM compiler. Refresh candidates
with:

```sh
cmake --build build/linux-emu --target otp_refresh_bootstrap_seeds
```

Review complete candidate inventories, source changes and compiler metadata
before adoption. Unexplained hash/output changes are verification failures.
[Application assembly](application-build.md) owns generator/native/resource
details; [native extensions](native-extensions.md) describes installed headers.

## Installation and external provenance

Unix installation uses retained upstream `Install -minimal` finalization.
Ordinary and DESTDIR installs preserve upstream logical-prefix substitution,
paths, entry types, modes and symlink targets. Windows uses its native command
layout. Static runtime/preloads and linked native implementations reside in the
host; application extensions and standard inspection bytecode retain upstream
paths. No VM library, development archive or validation manifest is added to
an installed OTP prefix.

`build/<preset>/sdk-selection.json` records SDK identity and consumed hashes.
Native/header/object and executable dependency boundaries are audited separately.
Capture complete external provenance for installed candidate/reference selections:

```sh
python3 tools/installation_inventory.py capture --prefix "$OTP_PREFIX" \
  --runtime candidate --flavor emu --evidence "$BUILD_EVIDENCE" --output "$OTP_PROVENANCE"
python3 tools/installation_inventory.py verify --prefix "$OTP_PREFIX" --provenance "$OTP_PROVENANCE"
python3 tools/installation_inventory.py compare --candidate "$OTP_PROVENANCE" \
  --reference "$REFERENCE_PROVENANCE" --output "$TREE_COMPARISON"
```

The source/build attestation identifies the upstream pin, product source inputs,
selected SDK identity, static archive and link-support hashes. Candidate records
use `build.linkage = "static"` and `build.sdk` with `build-id`, `runtime` and
`runtime.static` checksums. Store records outside installed prefixes in ignored
build output or CI artifacts. Provenance is an acceptance input, not a runtime
requirement for ordinary users. [Qualification](local-qualification.md) describes
artifact-bound content review and compatibility reconciliation.
