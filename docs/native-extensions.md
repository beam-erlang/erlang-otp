# Native extension SDK and initial fixture evidence

OTP installs the public NIF and driver header closure from the selected BEAM
SDK under both `usr/include` and `erts-17.0/include`. The CMake build requires
`BEAM::NIF`, `BEAM::Driver` and `beam_install_native_headers`; an older SDK that
lacks these capabilities fails configuration. The SDK owns the generated
integer-size header and the complete dependency inventory. Header hashes are
validated at configuration and installation. No private VM headers or sibling
source paths are used to supply extension compilation inputs.

## Current comparison

The [2026-10-21 ET/sendfile comparison](et-sendfile-comparison.md) corrects the
product-owned ET and restart-taint probes. Complete relocated and isolated
three-boot product checks now pass on both flavors, including the unchanged
native extension fixtures. Primitive-file passes all 41 cases on candidate and
original upstream. Sendfile passes all 14 inet cases; socket retains 12 passes
and two failures on both candidates and both original upstream builds. The
saved-handle leak is reproduced upstream; native correction stops pending an
explicit upstream-bug-fix decision. Runtime and native code remain unchanged.

## Historical ownership-cutover validation

OTP builds and selects its own native primitives, including terminal, Zstandard
and RAM-file support. Static OTP registrations in `libbeam` and OTP-native SDK
artifacts are removed. The current TCP/UDP configuration records 16 entries in
`native-components.json`: nine NIFs including Runtime Tools' `dyntrace`, five
drivers, the shared socket backend and the hostname helper. Every implementation
source comes from this repository. The two private compiler hosts use the public
runtime and 277 source-attested seeds; neither depends on the BEAM command.

Fresh source-retirement builds pass on both Linux flavors. The public native
boundary and activation checks pass; the startup observer passes with 22 sticky
preloads and three restarts in fresh, relocated and isolated installations.
The unchanged extension fixtures described below also pass after relocation and
isolation on both flavors, using the final SDKs. Their five source hashes match
the import, and each evidence record identifies the selected runtime. Native
resolver, TCP/UDP diagnostics and socket/net checks complete in the same runs.
These stages execute before the broad product probe, which still fails at ET's
`file_open`/`enoent` and subsequent event-collection timeout. Passing fixture
stages do not make the full product checks pass.

Both complete final OTP inventories finish all 101 entries: 79 pass, seven wx
entries remain disabled and 15 retain known nonpassing gates. Evidence is under workspace
`tmp/vm-ownership-migration/retirement/`, including
`native-fixture-evidence-audit.json`; individual records remain under each
`retirement-otp-{emu,jit}/checks/` directory. See the
[ownership record](../../dev-documents/otp-ownership-cutover.md) for the current
cross-product checkpoint. Existing socket-sendfile failures, strict skip gaps
and deferred wx coverage remain unresolved.

## Earlier native ownership increments

The following records preserve evidence from the incremental transfers before
the final cutover. Their pending static-registration and bootstrap work is
superseded by the current ownership above; historical test totals describe only
their recorded inputs.

OTP's dynamic primitives now build locally. `prim_buffer`, `prim_file`,
`erl_tracer` and `zlib` build from retained OTP sources
through `BEAM::NIF`, with standard C synchronization and product-local helpers.
Compression links system zlib; it requires the SDK's private compression symbols
to remain hidden. Runtime Tools also builds its two drivers and dynamic-tracing
NIF locally, using the SDK's public backend capability query.
OTP also builds its TCP/UDP protocol drivers locally with `BEAM::Driver`,
the public packet interface and native diagnostics. SCTP is configured only
when its headers and required libsctp dependency are available. No private
VM headers or loader functions supply these targets. Distributed commands and
all 14 inet-sendfile cases pass on both flavors. `otp-native-public-boundary` checks the
eleven extensions and shared socket backend on the current TCP/UDP configuration: actual source/header
inputs, declared NIF/driver imports, entry points, SDK stamps and compression
linkage. `native-components.json` records their source and installation paths.
The OTP-owned `inet_gethost` executable is recorded in the same inventory and
audited for product-local configuration and system interfaces only. Its build
does not use VM headers or link `libbeam`. Product acceptance checks native
forward/reverse lookup, debug controls, helper soft restart and port origin
after relocation and filesystem isolation; these checks pass on both flavors,
as do TCP/UDP diagnostics matching the actual caller PID. Complete product
checks still fail at ET, so no new full restart result is claimed.
The socket/net increment builds six backend translation units through public
NIF/driver/native interfaces. Only its two NIF initialization functions are
exported; the two ordinary stamped NIF entries resolve the shared backend through
`$ORIGIN`. Fresh both-flavor product builds and expanded boundary/DEBUG checks
pass. No previously enabled socket capability disappears in the platform-probe
comparison. Socket/net operations, resolver/interface calls and both NIF/backend
mapping origins pass after relocation and isolation. Both focused nine-test runs
pass six checks; the two product checks retain the ET failure and socket-sendfile
retains twelve passes/two failures, matching the earlier baseline. Commands and
all fourteen inet-sendfile cases pass. Complete native-pass acceptance remains
pending; no new full product-restart result is claimed. SDK acquisition no longer imports
OTP dynamic-native implementations.
The unchanged complete `zlib_SUITE` supplies stream, dictionary, ownership,
checksum and compression behavior coverage. Validation of this migration is
recorded separately from the historical fixture checkpoint below.

The file NIF uses OTP-owned platform probes, C11 atomics and the public
`beam_native_fail` entry for unrecoverable internal errors. Both Linux flavors
compile and pass the native boundary check, including both file translation
units; DEBUG syntax checks also pass. File-suite results follow; complete
product/restart acceptance still has the recorded ET failure.

The installed upstream harness also includes the unchanged 41-case
`prim_file_SUITE` and 14-case `sendfile_SUITE`, with explicit `inet` and `socket`
backend runs after relocation. Both flavors pass all 41 primitive-file and 14 inet-sendfile cases. Socket
sendfile has 12 passed and 2 failed cases on both flavors; the preserved JIT
product from before file transfer reproduces the same close/descriptor failures.
Those failures remain unresolved, and do not count as passing coverage. The primitive
suite includes a 4 GiB write with unchanged upstream resource checks; a skipped
case remains a nonpassing strict coverage gate.

The shared runtime, public headers, core inspection artifacts and generic child
helper remain SDK inputs. Static OTP native bindings and the compiler bootstrap
still require ownership migration without importing VM-private headers or symbols. The
[runtime strategy](../../dev-documents/runtime-evolution-strategy.md) supersedes
the earlier permanent BEAM ownership decision. The public native extension
headers and shared VM mechanisms remain SDK-owned; the evidence below records
the implemented boundary at each checkpoint.

Ordinary OTP extensions use the standard `erl_nif.h` or `erl_driver.h`
interfaces and resolve their public symbols in the running `libbeam`. The OTP
host explicitly admits NIF and driver loading through public composition. This
does not introduce a second VM or a private native-provider interface.

## Reproducible checks

Configure and build with the explicit SDK selection described in the
[build guide](build.md), then run:

```sh
ctest --preset linux-emu -R '^(initial-product|isolated-product)$' --output-on-failure
ctest --preset linux-jit -R '^(initial-product|isolated-product)$' --output-on-failure
```

Each check freshly installs and relocates the OTP product through a path with
spaces. It copies these retained upstream inputs byte-for-byte into its work
directory before compilation:

- `erts/emulator/test/nif_SUITE_data/nif_mod.1.c`, `nif_mod.c`, `nif_mod.h` and
  `nif_mod.erl`.
- `erts/emulator/test/dirty_nif_SUITE_data/echo_drv.c`.

The NIF compiles against the installed common include directory; the driver
compiles against the versioned ERTS include directory. Installed `erlc` compiles
the unchanged Erlang NIF module, using installed Common Test headers. Installed
`erl` loads and calls the NIF, then loads the driver, checks binary output and
term-call round trips, closes its port and unloads it. No copied source header
or SDK path is present in either native compile command.

`isolated-product` repeats compilation and execution with only operating-system
directories, the relocated product and copied fixture work directory visible.
The original SDK, repository and build paths are explicitly checked absent.
The native fixture stages pass on both flavors in both modes; the broader
product checks retain the ET failure described above. This is focused fixture acceptance, **not** an
execution of the full `nif_SUITE` or `dirty_nif_SUITE`. No upstream suite, fixture
or assertion has been modified. All five inputs match the original import.

## Historical initial fixture checkpoint

The first JIT invocation failed because the new orchestration expression called
unqualified `port_call/3`. Qualifying the call as `erlang:port_call/3` corrected
that harness error; both product checks then passed. The remaining eight JIT
checks had already passed. Interpreter acceptance passed all ten checks in one
run. This does not establish full extension ABI or application compatibility.

### Artifact and source provenance

The source HEADs are BEAM `795e3ac7fa39433cce26bc979bd8889da324d52a` and OTP
`72a1beb074a9fb8481d652418db80255c2962008`, with the native SDK export/deployment,
OTP installation, orchestration and documentation changes uncommitted.
Existing command and process-policy changes remain uncommitted as well.
The upstream pin remains `550d7b7898706c7822362c42e7b93120c1d1f29a`.

| Flavor | SDK build identity | `libbeam.so` SHA-256 |
| --- | --- | --- |
| Interpreter | `863297a374d2f1cb162e64bddf5fad669b3c2d64e466e45916ed7caecef6c975` | `bee3e2c1cf71aa9431f0f21e13359c1e905ea0b475f6387c9f8e45c23a10ec27` |
| JIT | `7d73ab684108516f4cff52ec57eb7c43db26dabb6aaed604f7cbd615379e33f0` | `4cd7519017aee182490054930cbde53547d0c72af1da840561c201d7adaa9053` |

`build/<preset>/sdk-selection.json` records required artifact hashes and SDK
selection. Each product check writes its native-input hashes and SDK identity to
`build/<preset>/checks/native-extensions-{relocated,isolated}.json`. The fixture
source paths above and the original import provide durable reproduction inputs;
check work directories are disposable. Workspace scratch logs use
`tmp/otp-native-check-{emu,jit}.log` and `tmp/otp-native-recheck-jit.log`.

Broader NIF/driver suites still need their full native fixture inventories and
harness preparation. Additional command options, complete application assembly,
external-node interoperability and release upgrades remain separate gates.

### Shared SDK regression coverage

Both selected SDKs passed all 26 BEAM distribution CTests, including public
header/driver consumers against fresh and relocated installations, modified
header rejection at configuration and installation, artifact consistency,
bare/returning lifetimes, modern behavior and installed OTP acceptance. No
runtime case was skipped. Disposable full logs are
`tmp/native-sdk-full-{emu,jit}.log`; CTest retains its build-local test logs.

The unchanged playground passed all 23 projects, 124 configurations and 50
relocated bundles across both flavors. Separate GLM consumer checks passed with
fresh packages built using these SDKs; the original GLM test tree was not used.
Archive SHA-256 values are:

- Interpreter: `4c3adeb27715a26af8e17f108758d55445ca600dd0cfb33d018169a9956d0fff`.
- JIT: `c4c35fa42ebe47aea75ce8a2126521674781a24038f65e5a53c4258bac672067`.

Reproduce runtime checks with `ctest --test-dir build/<preset>
--output-on-failure` in BEAM. Run the playground's `tests/standalone.py` with the
explicit matching `--prefix` and `--flavor`, and follow its GLM consumer guide
with a newly built matching archive. Scratch playground logs use
`tmp/native-sdk-playground-{emu,jit}.log`; GLM build/consumer logs are under
`tmp/native-sdk-glm/linux-{emu,jit}/`. No playground source or tracker contents
changed. Whitespace, touched local links, Python syntax and both installed header
copies were checked. All 352 source-built Erlang artifacts remain byte-identical
between flavors. These checks preserve the existing bounded contracts; the
remaining [compatibility gates](../../dev-documents/otp-compatibility.md#completion-gates)
remained open at this checkpoint.

The subsequent [dirty-NIF suite checkpoint](upstream-testing.md#complete-dirty-nif-suite)
runs the entire unchanged 35-case suite successfully on both flavors, including
peer nodes, code purge and halt callbacks. It supersedes the absence of complete
`dirty_nif_SUITE` execution above; the full `nif_SUITE` and other native suites
remain pending.
