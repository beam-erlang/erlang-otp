# OTP over BEAM/Erlang

The OTP emulator executable is a small process entry point:

```c
#include <beam/beam.h>

int main(int argc, char **argv)
{
    return beam_main(argc, argv);
}
```

`BEAM::Runtime` supplies the VM, its original OTP startup/parser, canonical
BIFs, preloaded modules and built-in native implementations. The call belongs
on the process main thread and transfers process ownership to the emulator.
Normal halt and fatal failures can terminate the process. It does not promise
VM teardown followed by continued C execution.

OTP owns `erl`, `erlc`, `escript`, `epmd`, `inet_gethost`, Erl_Interface,
applications and their ordinary NIFs/drivers, boot files, release metadata and
installation assembly. Native extensions compile through installed public
headers using `BEAM::NIF` or `BEAM::Driver`; they do not link another VM.
`erl_child_setup` and public native headers are deployed from the selected SDK.
The installed OTP tree runs without that SDK prefix at runtime. An explicitly
selected OpenSSL remains the external dependency of Crypto; wxWidgets and its
declared native dependencies support wx's two NIF modules. ODBC consumes the explicitly selected
ODBC manager; Jinterface builds with the explicitly selected JDK and uses Java
when its JAR is consumed. Flex generates Megaco scanner sources during the build.

Runtime Tools has two [documented native source adaptations](source-differences.md)
that remove unnecessary private-header dependencies while preserving its
supported disabled-tracing and socket behavior.

## Deliberately small boundary

OTP `29.0` requires SDK package version `17.0` exactly, matching its release-table
ERTS requirement. The BEAM/Erlang product and SDK package versions follow ERTS;
they are separate from the original OTP OTP release identity. Configuration checks
the exact SDK release, ERTS version, flavor, OS and architecture. The SDK also
exports `BEAM_SDK_HOST_TRIPLE`, the exact architecture string embedded in its VM;
OTP uses it for native build directories and verifies it at build startup. Upstream SHAs
record synchronization provenance; equality is not an ordinary SDK selection
requirement. Pinned original OTP acceptance and private fixtures retain their
separate exact source and SDK identity requirements.

`BEAM_SDK_ROOT` selects an installed prefix, either an individual SDK or a
combined SDK. Its manifest supplies the package location and available runtime
choices. OTP forwards its `OTP_BEAM_FLAVOR` selection before package discovery;
`CMAKE_BUILD_TYPE` selects the matching Release or Debug runtime. Direct
configurations default to EMU Release. Unavailable choices and conflicting
flavor selectors fail rather than substitute another runtime. Native compiler
checks remain active for both build types; multi-config builds are unsupported.

The product deployment target must be at least the SDK floor and every selected
native dependency's floor. The current
macOS product target is 26.0; the VM SDK can retain its 15.0 floor.
BEAM/Erlang alone owns runtime preload sources and retained execution bytecode
under its retained `erts/preloaded/` tree. The VM embeds execution seeds in
the selected static archive; OTP does not compile or replace them or infer the
archive name. The installed SDK supplies
inspection bytecode, including abstract code and documentation metadata, and
matching sources and headers. OTP copies inspection bytecode into binary-tree
`erts/ebin` and matching sources into `erts/preloaded/src`, then installs them under
`lib/erts-<version>/{ebin,src}`. These are distribution artifacts, not a second
source owner. The retained primary bootstrap runs on the SDK VM throughout the
build, so no OTP preload compilation or sibling BEAM source/build access is
needed. Changes to runtime preloads belong in BEAM/Erlang
and require rebuilding and selecting its SDK.
`sdk-selection.txt` in the binary directory records the selected identities and
artifact hashes, including build type, production source/toolchain identities,
and actual selected archive/helper paths; it is development output, not an
installed product dependency.
Keep the selected SDK stable between configuration and build. Reconfigure OTP
after rebuilding, reinstalling or replacing that SDK, even at the same prefix
and release version. The receipt is refreshed during configuration; ordinary
builds do not perform a per-build SDK content check.

Debug uses the SDK's Debug VM and ordinary native CMake Debug compiler settings.
Its native helper is staged before the first bootstrap compiler boot, including
the relative `erl_child_setup.debug -> erl_child_setup` alias. SDK deployment
helpers preserve that alias under the installed ERTS binary directory. Unix keeps
the executable name `beam.smp` and ordinary launchers in every configuration.
The build does not add VM-internal debug definitions to native extensions or
change the existing Erlang bytecode compilation policy.

This arrangement preserves ordinary OTP names and compiler/bytecode behavior.
It adds no configurable native-callable catalog, custom provider ABI, generic
composition API or returning host framework. A broader public embedding API can
be designed separately from this process entry point.

## Application assembly

On Windows, `erts/windows_host.c` supplies the ordinary process VM DLL using
only the installed public `beam_main` entry. `erts/etc/windows_erlexec.c`
adapts that lifecycle to the retained original OTP command parser. The project
modules `cmake/WindowsCommands.cmake` and `WindowsNativeConfig.cmake` own native
targets, resources and platform configuration. This preserves original OTP
`erl.exe`, `erlexec.dll`, native helpers and versioned ERTS layout while the
selected BEAM SDK remains the sole VM. Build `erl.ini` files are local build
inputs; installed launchers discover the neighboring ERTS tree after relocation.

`cmake/OTPDocumentation.cmake` owns native documentation orchestration. Its
shared original OTP ExDoc inputs are retained unchanged under
`cmake/original OTP/documentation`; application and system documentation stay with
their owners. `OTPPackaging.cmake` stages the unchanged original OTP Windows NSIS
script and generates release definitions over the installed product. Neither
feature reads workspace reference trees or runs the original Make build.

The product contains all 35 retained applications: `kernel`, `stdlib`, `compiler`,
`parsetools`, `sasl`, `syntax_tools`, `asn1`, `crypto`, `public_key`, `tools`,
`runtime_tools`, `xmerl`, `eunit`, `common_test`, `erl_interface`, `mnesia`,
`os_mon`, `ssh`, `snmp`, `inets`, `ssl`, `wx`, `et`, `debugger`, `observer`, `ftp`,
`dialyzer`, `diameter`, `edoc`, `eldap`, `jinterface`, `megaco`, `odbc`, `reltool`
and `tftp`.

Each application owns a source-local `CMakeLists.txt` with explicit module and
resource lists, generated inputs, native targets, commands and installation.
Root CMake selects shared platform/SDK policy and composes components. Shared
CMake helpers own bootstrap staging, application dependencies, ordered `erlc`
commands, resource assembly and installation. `cmake/OTPExecution.cmake` preserves
literal command arguments and controls the runtime environment;
`cmake/OTPStaging.cmake` owns declared copies and obsolete-output cleanup.
Retained original OTP generator entry points run directly through the selected
bootstrap commands. `cmake/otp_application_validator.erl` checks application
metadata and BEAM outputs and writes build records. Python is required for tests
and optional acceptance maintenance only.

The build copies the retained fixture into `bootstrap/{bin,lib}` and prepares
freshly built `erl`/`erlc` launchers using native programs under `bin/<TARGET>`.
The supplied compiler remains authoritative for the entire build. Secondary
and tertiary stages add source-built parser, ASN.1, transformation and other
original OTP build tools without replacing the fixture's core applications.
Applications are built once under `lib/<app>`; the final Compiler application
is a product output and never becomes the build compiler. Generated application
sources mirror their source-relative paths in the binary tree. CMake-only
configuration, helpers and stamps use `CMakeFiles/otp`; generated execution
scripts use `CMakeFiles/otp/commands`.

Build-tree `bin/erl` runs the completed unversioned application tree, using local
boot files. Installation and the explicit `otp_release` target use separate boot
files with ordinary versioned application paths. Native compilation, resource
staging, Java compilation and release assembly remain declared build edges.
The build does not invoke a system Erlang or use the modern BEAM command as a
compiler fallback.

The shared Erlang acceptance controller lives in `tests/otp/support/`,
alongside the owning `tests/otp/` operational inventory. It invokes
original Make, test-server and Common Test helpers against an installed
candidate and explicit inputs, independently of product assembly. Every
platform uses this path; native platform acceptance is recorded separately.

Upstream synchronization provenance remains recorded in `UPSTREAM_COMMIT` and
selection receipts. Ordinary configuration accepts editable wx sources and
release resources without matching a frozen source hash or manifest pin.
Explicit native dependency selection and capability/deployment checks remain.

The separate [original OTP acceptance gate](otp-tests.md) selects the pinned
35-application corpus, emulator/system corpora and two supplements, in 39
components; that selection does not establish
coverage or extend earlier acceptance results. Full release-upgrade behavior and
cross compilation also remain outside demonstrated coverage. The
[testing guide](testing.md) distinguishes bounded distribution checks from
acceptance.
