# Native macOS development acceptance

The required execution gates pass on macOS 26.6.2 ARM64 (25G83), using Apple Clang
21.0.0 and SDK 27.0 with deployment target 15.0. macOS 15 runtime execution remains
untested; external wx/ODBC dependencies also have their own deployment requirements.
This establishes the native development baseline, not full upstream compatibility.
Final payload cleanup is complete and recorded in the workspace acceptance receipt.

## Selected installed products

Both products use BEAM SDK `17.0-r1-preview.1`:

| Flavor | SDK build ID | Installed OTP host SHA-256 |
| --- | --- | --- |
| EMU | `3b6bc1c42976f9c2187e9af73b52fe98f5ba67b542aea4dc711f38ec2de03e2d` | `d85ddb55698dd123d5933037a0c872a8569fd8ca0cee01a77c1c3b8716312c2d` |
| JIT | `64c415417f847f3d6444781b13219e941c193de4a408955862773df491553706` | `22bab9de2d100cf63388c351cc642e4c77184b106ae268e659f5bb763eefe384` |

Usable installations remain under `install/macos-arm64-appleclang-{emu,jit}`.
Their external provenance is under the matching `build/<preset>/installed-provenance.json`,
outside the installed product. It retains the original producer SDK selection and
records the byte-identical SDK relocation into the BEAM repository's normal
installation directory. No private VM headers, sibling build dependency, external
Erlang compiler/runtime, second VM or installed validation manifest is introduced.

Both flavors assemble all 35 current applications and deterministically reproduce
277 bootstrap modules and their boot resources. Matching original releases use
unchanged OTP 29.0 commit `550d7b7898706c7822362c42e7b93120c1d1f29a`,
`make release`, `Install -minimal` and umask 0002. All 11,817 exported blob contents
and Git modes were checked against the pin. Configure qualifies ODBC before the
standard make variable `ODBC_CAN_BUILD_DRIVER=true` is passed explicitly; its
missing propagation is not repaired by editing upstream sources. Dependencies
are selected explicitly, builds are offline and no system packages were installed.

## Results and remaining inventory

Each flavor passes all 20 registered non-upstream product tests other than the
deferred `wx-product`. This includes installed SDK/public boundaries, independent
bootstrap/compiler, full three-boot relocated/isolated product probes, native
activation and helper recovery, preparation/allocation failure, terminal
restoration, boot observation, compatibility transfer, development support,
installation comparison, generated ASN.1 values, command policy and standard
isolated release execution.

The required unchanged upstream selections all pass on each final host: Base64,
math, queue, dirty NIF, zlib, zstd, ET, Reltool application and Reltool server.
Each suite receipt binds its actual host/helper bytes, selected SDK, unchanged
suite/hook/data hashes and exact case results. Assertions and upstream fixture
files remain unchanged. Acquisition recreates the empty Reltool working directory
present in the original export but unrepresentable in Git; it does not replace
fixture contents or suppress the case.

Exact installed-tree comparison passes all 3,680 entries on both flavors, including
paths, types, modes and literal symlink targets. Six independent inspection-file
lifetimes per flavor retain 22 preloads and compare native capabilities with the
original. Darwin BSD `install -d` parent permissions and umask-sensitive epmd links
are reproduced explicitly. The existing Darwin sendfile implementation is enabled
through the correct SDK headers/platform definition; its close logic is unchanged.
The complete sendfile suites remain untested on Darwin, and Linux failures do not
excuse or classify them.

The [machine-readable evidence](evidence/macos-development-20261024.json) classifies
every one of the 112 registered tests per flavor:

| Outcome | Tests per flavor |
| --- | ---: |
| Passing | 29 |
| Deferred wx/GUI | 7 |
| Prerequisite-blocked | 9 |
| Untested beyond the required upstream subset | 67 |
| Failing or skipped in the required selection | 0 |

The unchanged CPU, memory and disk-monitor kill suites remain prerequisite-blocked
on this interactive Mac. They require a disposable macOS worker, not an exclusion
or a reported pass. Four ODBC suites need PostgreSQL/psqlODBC inputs; FTP and ELDAP
need their selected private-server dependencies. The reusable dependency cache was
inspected and contains no suitable server inputs. Their acquisition/isolation
adapters remain Linux-specific. Java 17 is available, but its remaining upstream
test acquisition also needs Darwin adaptation and is explicitly untested. Missing
prerequisites do not remove registered tests.

The four independent installed-OTP-hosted shared-VM suites pass on each final host,
including the retained development installations: `atomics_SUITE`, `counters_SUITE`,
`bs_bincomp_SUITE` and `bs_match_tail_SUITE`. Ordinary BEAM builds retain no OTP
dependency. The complete private playground result belongs to its
[validation record](../../dev-playground/erlang-otp/VALIDATION.md).

## Darwin adapters and corrections

Test-owned libproc/Mach/dyld inspection verifies real executable paths, image
mappings, descriptors, threads and children. Focused checks require their actual
appearance/disappearance and resource restoration; observation errors fail. Kernel
executable-path records cover unlinked images without fabricating empty results.
Native format inspection uses Mach-O/SDK inventories instead of ELF assumptions.

Seatbelt execution denies original source, build and SDK inputs. Generated releases
have separate execution isolation that also denies their project/assembly inputs.
The underlying backend is qualified for open/stat/exec/dlopen denial in descendants;
there is no unsandboxed acceptance retry. Commands close unintended inherited FDs,
and owned process groups/unique executable prefixes are stopped before payload
removal. Automatic EPMD startup remains exercised: its persistent daemon is an
explicit fixture responsibility and is stopped before process restoration is
asserted. No running system service is modified.

Darwin terminal inspection masks only kernel history bits, retaining restoration
of configured terminal modes, control characters and stream flags. A private
session anchor permits observation after VM exit without changing terminal state.
Preparation uses test-only allocation interposition because Darwin rejects the
Linux address-space-limit mechanism; atomic failure/recovery and measured Mach
address-space checks remain enforced. No allocation hook is added to the product.

The OTP host defaults to UTF-8 filenames on Darwin even under the C locale, matching
the pinned original; Linux retains locale selection. Its locale declarations and
native executable discovery also serve the independent bootstrap. Startup quoting
and the optional private FIFO directory are described in the
[command guide](commands.md). These are product-owned policy/build adaptations,
with no VM/C ABI change or modified upstream suite assertions.

Linux integration remains open until exact-source EMU/JIT evidence returns through
the [handoff](../../dev-documents/macos-linux-handoff.md). wx GUI execution, release
upgrades, signing/notarization and publication are outside this baseline.
