# OTP assembly fidelity

The target is the finalized original OTP 29.0 installation at
`550d7b7898706c7822362c42e7b93120c1d1f29a`, with equivalent application/native
features and matching interpreter or JIT flavor. Tree equality and content
review are separate gates; neither establishes full runtime compatibility.

## Installation-mode correction (2026-10-27)

The owning ASN.1, Crypto, Megaco, Runtime Tools and wx declarations now set
explicit `0755` permissions for `LIBRARY` artifacts as well as `RUNTIME`.
All eleven libraries retain their existing upstream paths. This corrects the
mode gap described below without chmod workarounds or changed reference rules.

Fresh interpreter and JIT producers each pass complete 3,680-entry equality for
ordinary and DESTDIR installations: paths, entry types, modes and literal link
targets. The staged products also pass three inspection lifetimes after
relocation; candidate/reference/staged native capabilities match. Exactly four
launcher files differ between ordinary and staged copies only by their logical
installation prefix; no physical DESTDIR is embedded.

Each flavor separately passes 18 focused checks covering bootstrap reproduction,
public boundaries, installed/relocated/isolated product lifetimes, commands,
development fixtures and standard release creation. The
[increment evidence](evidence/otp-completion-20261027/installation.json.gz)
retains exact artifacts, SDK selections, commands, raw results and cleanup.
These runs use the explicitly selected immutable `29.0` SDKs. They do not qualify
the newer preview SDK source. The current content review remains pending a
matching-JDK fresh product comparison; it detected JDK 17 versus reference JDK 25
JInterface inputs. Structural equality is separate from that review and from
broader compatibility qualification.

## Historical fresh-build mode gap (2026-10-26)

The [command-validation evidence](command-kernel-poll-validation.json) records a
fresh JIT installation with the same 3,680 entries as its verified original
reference, but eleven shared libraries have mode `0644` instead of upstream's
`0755`. The affected libraries belong to ASN.1, Crypto, Megaco, Runtime Tools and
wx. The structural gate remains failed; its subsequent native-capability
comparison is untested in this run.

An exact committed-tree export of pre-fix OTP
`5c9858415b3101e7a42e15ee35f17f4e91e21d0b`, configured against the same installed
SDK with CMake 4.2.3, generates identical native-library install rules. Executing
those rules on private copies of the unchanged library build products reproduces
all eleven mode differences. The baseline host lacks the `+K` correction, and
the five owning CMake source files match the candidate byte for byte. This
establishes an existing installation-mode gap independently of the command fix.

The generated `LIBRARY` install rules omit explicit permissions; the source
declarations place permissions after the separate `RUNTIME` destination. This
gap needs a packaging correction. Permission rules, reference expectations and
upstream assertions remain unchanged. Baseline source/build/install payloads
are removed after retaining their hashes, commands and mode observations.
Earlier passing assembly results below apply to their recorded inputs.

## Launcher generation

`Install.src` receives its installation-stage tokens while retaining `%VSN%`
for its later substitution into `start.src`. `erl.src` uses its own token set.
This corrects the unresolved `erts-%VSN%` in both installed `start` copies.
Normal installation and DESTDIR continue through upstream `Install -minimal`.

Command acceptance executes root discovery before and after relocation,
including spaces and Unicode, its original-prefix fallback and `ERL_ROOTDIR`.
It also executes the real `start → run_erl → start_erl → beam.smp` chain at an
ordinary relocated path in a private filesystem/PID namespace, observes the
selected executable and child helper, and requests orderly OTP shutdown.
Upstream's unquoted `start` invocation does not support paths containing spaces;
those paths remain covered by discovery, `erl` and standard-release checks.

## Bootstrap

The private compiler inputs now live directly under `bootstrap/`: `README.md`,
`manifest.json`, `recipe.term`, `boot.script` and `seeds/`. They contain no SDK
implementation and install nothing. Build roots and target names are unchanged.

Both-flavor candidate refresh reproduced all 277 module hashes and the boot
resource hash unchanged. Reviewed manifest changes consist of relocated source
paths and the verifier's changed source hash. Fresh builds and bootstrap
integrity checks pass on both flavors.

Exactly 285 unused imported files were verified against immutable upstream bytes
and modes before retirement. The [retirement inventory](../../dev-documents/otp-bootstrap-retirement.json)
records each path, mode and hash; [source provenance](../../dev-documents/source-map.md)
owns their history.

## Content review

`tools/review_installed_contents.py` compares every changed regular file against
external, matching-flavor installation provenance. It retains raw text
differences, narrowly scoped installation-prefix normalization, BEAM chunk
hashes and native dependency/symbol evidence. Review decisions bind an exact
path to both artifact hashes, its producer/source, rationale and validation.
Absent or stale decisions cannot produce a passing review.

`tools/inspect_installed_beams.escript`, invoked through the selected installed
`escript`, captures module interfaces, attributes, compiler options and abstract
code hashes. Source-path normalization affects only compiler source/include
paths and abstract-code file attributes; raw metadata and hashes remain.
It also records literal tables and a separate comparison that normalizes only
the `file` field in logger location maps. Raw literals remain in the report.

`tools/compare_asn1_generated.escript` compares Public Key's generated function
bodies and exports after removing source annotations and consistently identifying
generated internal ASN.1 helpers by their bodies and dependencies. This accounts
for deterministic generator naming and ordering without treating all generated
code as equivalent. Raw source, interface and executable-chunk differences remain
available in the content report.

Corrections include the pinned SNMP placeholder in `start_all_example.rel`,
upstream wx module ordering and application-version ordering, the standalone
thread library's double-word compare/exchange probe, retained development
templates, the correct internal-library README, and supported upstream native
link hardening flags. SDK-owned native headers continue to come from the
selected SDK, matching the linked runtime.

The review also restores upstream compiler inlining (with its `core_parse`
exception), Mnesia/ODBC application attributes, Crypto's version define and EPMD's
distribution-version defines. These product compilation profiles run through the
private OTP host and leave the independently attested bootstrap bytes unchanged.
JInterface comparison selects the same JDK as the reference and uses upstream's
archive member layout. EI now uses probed atomic socket operations, upstream's
default connection-error masking and its architecture-specific unaligned access
setting. Its installed threaded and single-threaded consumers check connection
failure as well as ETF encoding. The retained `erts_alc_test` implementation is
included in the SDK's native export inventory and exercised through an installed
native test client.

The earlier SNMP converter correction remains intentional: the reference's
conversion fails with the host Perl and leaves an empty file. Candidate output
must remain functional; the reference failure is not repaired in place.

## Validation status

The allocator and unchanged crash-dump gates pass on both flavors; see
[Observer/Reltool](observer-reltool.md). Full SDK acceptance returns success on
both flavors, with the existing thread-name capability skip.

The fresh original JIT reference completes the sequential artifact-repository
recipe and finalization, with 3,680 installation entries. All 11,816 original
source files retain their pinned bytes after the build. The verified interpreter
reference is retained.

Both candidates match all 3,680 reference entries by relative path, type, mode
and literal symlink target. Each flavor has 1,470 changed regular files; every
change has an artifact-bound review disposition, with no unresolved entries.
The [durable evidence](evidence/otp-fidelity-20261020/README.md) retains the
per-file reviews, source inventories, SDK identities, artifact hashes, commands
and results. Stale review decisions are rejected.

The final validation results are:

| Gate | Interpreter | JIT |
| --- | --- | --- |
| Full BEAM acceptance | 34 passed; existing thread-name capability skip | 34 passed; same skip |
| Affected package acceptance | 4 passed | 4 passed |
| Selected OTP integration | 22 passed; 2 existing ET failures | 22 passed; same failures |
| Complete playground matrix | 70 configurations passed | 70 configurations passed |
| Installation structure | 3,680 entries; no differences | 3,680 entries; no differences |
| Installed-content review | 1,470 differences reviewed; none unresolved | 1,470 differences reviewed; none unresolved |

The OTP selections include unchanged Observer metadata, Etop text, complete TTB,
six crash-dump backend cases, and complete Reltool application/server suites.
All selected cases pass without skips. Their detailed selections and source
hashes are retained in the evidence; unselected upstream coverage is not implied.
The two failures are the recorded `initial-product` and `isolated-product` ET
event-file failures (`enoent`/`no_collector`).

All eight ordinary OTP examples pass against candidate and reference in place
and from isolated copies. Every Rebar3 run passes its seven stages, including
EDoc and cold/warm default Dialyzer. Unchanged Relx releases and Reltool targets
run in isolation and match the reference's 252-entry and 344-entry structures.
Normal and DESTDIR finalization pass, including prefix-normalized launcher bytes.

The stable side-by-side installations were refreshed from these validated builds.
SDK contents match the validation inputs exactly; only four OTP launcher files
change through final-prefix substitution. Stable trees and their content reviews
were checked again. Previous installations remain in workspace
`tmp/otp-fidelity-20261020/stable-backups/`. External provenance lives under
`erlang-otp/install/provenance/`. Shell selectors remain unchanged; fresh-shell
selection and simultaneous modern/shared and OTP/static runtime origins pass.

These results close this assembly-fidelity and allocator-tagging increment.
They do not establish full OTP compatibility. Existing ET/socket failures and
other coverage gaps remain recorded; wx acceptance and release upgrades remain
deferred.
