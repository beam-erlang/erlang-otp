# Observer and Reltool assembly

Observer 2.19 and Reltool 1.1 complete the 35-application source-build inventory
for OTP 29.0. Their assembly uses retained upstream implementations and the
existing installed static BEAM SDK. GUI modules are compiled and installed;
wx-dependent acceptance remains deferred.

Observer selects the 44 modules declared by its upstream Makefile. The
documentation-only `multitrace` example is excluded from ordinary assembly and
installation. Compilation uses wx and the ET header. The installation includes
application metadata, sources, public/internal headers, `erlang_observer.png`
and executable `priv/bin/etop` and `priv/bin/cdv` scripts.

Reltool selects nine modules, including its GUI modules, and preserves the
upstream `app_vsn` attribute through `sys_pre_attributes`. It installs application
metadata, sources and internal headers. It adds no command or example files to
the ordinary release tree.

The private build-driver seed changes for the Observer include path and Reltool
metadata. Both flavor candidates must agree, and the complete 277-module seed
inventory must reproduce before normal application compilation. No preload,
native composition or public SDK API changes belong to this increment.

## Example contracts

The independent [Observer example](../../dev-playground/erlang-otp/observer/README.md)
uses text Etop to observe a known worker, change configuration and save a report.
It then records and formats a deterministic TTB call/return trace and repeats
both tool lifetimes. Timing and memory values are observations, not fixed
expected numbers. `observer:start().` remains documented GUI usage with deferred
acceptance.

The independent [Reltool example](../../dev-playground/erlang-otp/reltool/README.md)
analyses its own application with the public server APIs and generates a target
using the standard embedded profile. It boots a configured Unicode greeting,
then repeats after relocation and filesystem isolation. The generated target is
used unchanged; runtime and helper origins must belong to that target.

The [Rebar3 example](../../dev-playground/erlang-otp/rebar3/README.md) additionally
exercises ordinary EDoc and default cold/warm Dialyzer analysis. Runtime-specific
PLTs retain the default base applications and must use files from the explicitly
selected installation. Existing build, tests, development shell and standard
Relx release checks remain required.

## Independent product acceptance

`check_upstream.py` copies and hashes unchanged upstream sources and fixtures,
compiles them using the selected installation, and runs these selections:

| Suite | Selection | Coverage outside this selection |
| --- | --- | --- |
| `observer_SUITE` | `app_file`, `appup_file` | wx GUI cases deferred |
| `etop_SUITE` | Four cases in `normal` | Two terminal/tmux cases unselected |
| `ttb_SUITE` | Complete suite, 49 cases | Broader tracing interoperability unproven |
| `crashdump_viewer_SUITE` | Six backend cases | GUI `start_stop` deferred; old-release peers depend on available fixtures |
| `reltool_app_SUITE` | Complete suite, six cases | GUI suite deferred |
| `reltool_server_SUITE` | Complete suite, 49 cases | GUI suite deferred |

Reltool fixture compilation follows the original Makefile's explicit targets;
other fixture applications retain their original uncompiled contents. New suite
skips remain nonpassing coverage gates. Tests do not modify upstream assertions.

## Validation status

The 2026-10-20 checkpoint stopped at the public startup boundary described below.
Both fresh candidate flavors build and install all 35 applications, with 44
Observer and nine Reltool modules. Each installation has 3,680 entries and 1,355
BEAM files, including installed examples and ERTS inspection files. These are
inventory counts, not compatibility percentages. The complete bootstrap
reproduces 277 modules and its boot resource on both flavors; only the private
build-driver seed changed.

The fresh original-build interpreter reference was produced sequentially from
the exact pinned source tree using the artifact repository recipe, with all
applications enabled and upstream `release` plus `Install -minimal` finalization.
Its complete 3,680-entry installation matches the interpreter candidate's paths,
types, permissions and literal symlink targets. The first comparison found only
Observer's `priv` directory mode (0755 versus upstream 0775); the installation
recipe now reproduces 0775. No installed inventory exclusions were used.

| Gate | Interpreter checkpoint | JIT checkpoint |
| --- | --- | --- |
| Fresh build, installation and bootstrap reproduction | Passed | Passed |
| Complete installation-tree comparison and inspection-file lifetimes | Passed | Incomplete: reference build interrupted at the stop condition |
| Observer playground monitoring/tracing | Candidate and reference passed, two lifetimes each | Untested |
| Reltool playground target and isolated relocation | Candidate and reference passed; identical 344-entry structures | Untested |
| Seven Rebar3 stages | Fresh candidate passed all seven; verified upstream baseline passed across the initial run and corrected Dialyzer rerun | Untested |
| Independent standard-release startup/restart/native/helper fixture | Passed | Not rerun at this checkpoint |
| Retained installed/relocated/isolated product selection | 14 passed; two retained ET failures | 14 passed; two retained ET failures |
| Observer metadata, Etop normal group, Reltool application suite | 2, 4 and 6 cases passed, respectively | Untested |
| Complete ordinary playground matrix in place and from isolated source copies | Not run | Not run |

Rebar3 default analysis checked 226 installed PLT input files and three local
application modules. Cold and warm runs succeeded without warnings and retained
the same PLT hashes. EDoc generated its index, module frame and documented
greeting API page. The existing unmodified Relx workflow also passed on the fresh
candidate; the full fresh-reference release-tree matrix remains incomplete.

TTB's initial suite run returned four passes and 45 failures because the harness
started nodes at `localhost` while its unchanged helper derived cleanup names
from the machine hostname. The harness now uses the ordinary hostname for these
fixtures; that correction is **not yet validated by a rerun**. The Reltool server
suite completed eight cases successfully, then failed `create_target` and
`create_target_unicode` with `failed_to_start_node` / `net_adm`; it was interrupted
during `create_embedded`. Those target-start failures remain unclassified.

The crash-dump suite could not complete setup: all six selected backend cases
were automatically skipped after its allocator-tagging peer failed to start.
This is a failed acceptance gate, not a GUI deferral.

Compact source/SDK identities, executable hashes, commands and outcomes are in
[the checkpoint record](otp-shape-checkpoint.json). Scratch logs and full external
inventories are under workspace `tmp/otp-shape-20261020/`; the actual fresh trees
use its `scratch` link into `/tmp` because workspace disk capacity was limited.
The evidence below does not depend on retaining those disposable trees.

## Historical public startup boundary blocker

The unchanged `crashdump_viewer_SUITE:do_create_dumps/2` starts a current-release
peer with `+Muatags true` to create its instrumented allocator dump. Reproduce the
required startup independently:

```sh
python3 tools/fixtures/otp_allocator_tags_probe.py --prefix "$OTP_PREFIX"
```

The probe runs the selected `erl +S2 +Muatags true -noshell` with a bounded wait
and process-group cleanup. The pinned upstream interpreter exits zero, prints
`ALLOCATOR_TAGS_OK` and produces no stderr. Both fresh candidate flavors exit one
with no stdout and this diagnostic:

```text
erl: emulator option is not implemented: +Muatags
```

`tools/otp_host.c:runtime_arguments` rejects the option. The selected installed
SDK's public `beam_vm_options` exposes no allocator-tagging selection or general
emulator-argument entry. This confirms an OTP startup/public-SDK boundary gap;
it does not demonstrate that the underlying allocator implementation is wrong.

The needed next scope is a reviewed generic SDK startup control for allocator
tagging, its OTP command adaptation, and acceptance of the tagged allocator data
in actual crash dumps and fresh VM lifetimes on both flavors. The application
assembly plan authorizes no such public API change, so implementation stopped.
The reproducer, unchanged suite and required gate remain in place. Resume the
remaining matrix only after the boundary correction and its integration checks.

Existing ET and socket failures remain in the [compatibility record](../../dev-documents/otp-compatibility.md).
The previous 33-application/static-release checkpoint remains historical evidence.
wx acceptance, other GUI paths and release upgrades remain deferred.

## Allocator-tagging correction

The SDK now exposes a typed, per-VM allocator-tagging selection. OTP translates
separate and joined `+Muatags true|false` arguments into that selection; ordinary
launcher/environment ordering remains upstream-owned. This preserves mixed
defaults and does not expose general emulator arguments or per-allocator tuning.

Fresh interpreter and JIT builds pass the original startup requirement and all
six unchanged selected crash-dump backend cases, including creation and parsing
of the instrumented dump. The SDK's installed shared/static lifecycle fixtures
also pass default → enabled → disabled → default selections with invalid-option
recovery and resource teardown. Full BEAM CTest runs return success on both
flavors, retaining the existing thread-name capability skip.

The final selected unchanged upstream coverage passes on both flavors without
skips: Observer metadata (2 cases), Etop's normal text group (4), complete TTB
(49), the selected crash-dump backend cases (6), complete Reltool application
(6) and server (49) suites. TTB now compiles from the suite directory, preserving
upstream `?FILE` behavior; Reltool fixture staging preserves its empty directories.
Neither correction changes upstream sources or assertions.

These results close the recorded allocator startup/crash-dump blocker and the
selected TTB/Reltool failures. Both examples also pass the complete candidate/
reference matrix in place and from isolated copies. Launcher generation,
bootstrap normalization, completed content review and final integration evidence
belong to [assembly fidelity](assembly-fidelity.md). Existing ET/socket failures,
unselected upstream coverage, deferred GUI acceptance and release upgrades remain.
