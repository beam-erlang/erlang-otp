# Dialyzer and Typer assembly

Dialyzer 6.0 is built from its 29 retained Erlang modules. CMake supplies the
upstream `v6.0` version define to `dialyzer_cl_parse`, `dialyzer_plt`,
`dialyzer_cplt`, `dialyzer_iplt` and `typer`. Application and upgrade resources,
module sources and `dialyzer.hrl` install under `lib/dialyzer-6.0`. The existing
source-built compiler and Syntax Tools provide the required Erlang dependencies.
No additional generator or VM service is needed.

The unchanged native `dialyzer.c` and `typer.c` command front ends install under
both `bin` and `erts-17.0/bin`. They use retained standalone command support and
system libraries, with no VM-private imports or second runtime. They discover
the candidate `erl` beside themselves and preserve upstream argument handling,
exit status and the `no_dot_erlang` boot profile. PLTs are built by the candidate
from the selected inputs; no externally generated PLT is bundled.

## Product acceptance

Relocated and isolated product checks exercise both commands, version output,
classic PLT creation, a failing-call diagnostic and exit status 2, and Typer's
inferred integer signature. The Erlang product probe also builds and inspects a
PLT and verifies failing-call/no-return warnings on each of three boots.
Filesystem isolation excludes the original SDK and source/build trees.

Final evidence covers **119 passed, zero failed and zero skipped cases per
flavor** across the following complete unchanged suites. Both relocated and
isolated product checks pass. JIT's initial ten-check selection passed in one
run. The interpreter's initial selection passed nine checks and failed the
PLT-merge check; its focused retry passed after the CPU allocation correction
recorded below. These are combined results, not a claim that the original
interpreter matrix was entirely green.

The unchanged upstream harness selects these complete suites:

| Suite | Cases |
| --- | ---: |
| `dialyzer_utils_SUITE` | 3 |
| `dialyzer_SUITE` | 9 |
| `dialyzer_cl_SUITE` | 3 |
| `cplt_SUITE` | 41 |
| `iplt_SUITE` | 36 |
| `typer_SUITE` | 4 |
| `abstract_SUITE` | 1 |
| `incremental_SUITE` | 22 |

Each suite and its helpers/data are copied and hashed before compilation through
installed `erlc`. The retained `dialyzer_common` creates the full test PLTs from
candidate ERTS, Kernel and STDLIB artifacts. Isolated execution uses private
HOME, cookies and EPMD; candidate peer nodes verify their installation root and
loaded `libbeam` origin. Explicit suite changes to HOME and configuration remain
intact. Two-hour suite budgets accommodate upstream PLT work without changing
its case timetraps. The harness normally selects two schedulers. The heavy
`dialyzer_cl_SUITE` selects up to eight available CPUs, with `--schedulers`
available for an explicit selection; candidate and default peer launches use
the same count. The suite retains its three-minute case timetrap. Source assertions and fixtures remain unchanged.

`erl_types_SUITE` property dependencies and the generated regression suites are
not covered by this selection. Their preparation and execution remain required
follow-up work, along with broader command and product compatibility. Assembly
and bounded suite results do not establish full Dialyzer or OTP certification.

## Source and artifact checkpoint

The source revisions are OTP `72a1beb074a9fb8481d652418db80255c2962008`
and BEAM `795e3ac7fa39433cce26bc979bd8889da324d52a`, with the recorded
uncommitted implementation work. SDK identities and runtime hashes remain those
in [Diameter evidence](diameter.md). No VM, SDK, retained application source,
upstream assertion, test fixture or bootstrap changes are required.

The installation contains 27 application entries and 839 BEAM files. All 810
preceding files remain byte-for-byte unchanged; all 839 execution-chunk sets
match between interpreter and JIT builds. Ordinary compiler metadata retains
its actual source/build paths. Native front ends depend only on system `libc`
and `libm`; source compilation, command execution and PLT analysis use the
selected `libbeam` throughout.

The first interpreter `dialyzer_cl_SUITE` run used the harness's two-scheduler
limit and reported two passes and one failure. The failing merge case reached
its unchanged 180-second timetrap; cleanup then killed its analysis processes.
With eight schedulers, the complete suite passed all three cases without skips;
the merge case took 174.4 seconds. JIT also passes the eight-scheduler
selection (99.85 seconds for the complete three-case check). This changes the test's CPU allocation, not
its deadline, assertions or product behavior. Initial failure evidence remains
in the full matrix log; focused retries use `tmp/otp-dialyzer-merge-*.log`.

The unchanged shared SDK's runtime, playground and GLM acceptance is carried
forward from the Diameter checkpoint, not represented as newly executed work.
At this checkpoint, generated Dialyzer regression suites, property coverage and
the other eight applications remained outstanding; migration stage 4 and
[compatibility gates 2–5](../../dev-documents/otp-compatibility.md#completion-gates)
remained incomplete.

## Reproduction

Build against the explicitly selected installed SDK, then run for each flavor:

```sh
ctest --test-dir build/linux-emu -R '^(initial-product|isolated-product|upstream-(dialyzer_utils|dialyzer|dialyzer_cl|cplt|iplt|typer|abstract|incremental)_SUITE)$' --output-on-failure
ctest --test-dir build/linux-jit -R '^(initial-product|isolated-product|upstream-(dialyzer_utils|dialyzer|dialyzer_cl|cplt|iplt|typer|abstract|incremental)_SUITE)$' --output-on-failure
```

Per-run `checks/upstream/<suite>-*/result.json` records exact inputs, source
hashes, SDK identity, case counts and skip reasons. Product checks exercise the
relocated commands and then remove their temporary installation. Workspace
scratch logs use `tmp/otp-dialyzer-{build,check}-{emu,jit}.log`. The aggregate artifact and
selected-run record is `tmp/otp-dialyzer-artifacts.json`.
