# Linux amd64 Stage 4: granular execution and evidence

Stage 4 is complete on 2026-11-16. This milestone establishes the shared test
controller, CTest interfaces and bounded Linux Emu Release evidence. It does
not establish complete application/runtime acceptance or the four-configuration
Linux matrix. Work stops here for review before Stage 5.

The [tests audit](tests-audit-2026-11-16.md) remains a separate follow-up record.
Its broader cleanup recommendations were not implemented as part of closing
this milestone. This record is documentation, never an execution dependency.

## Delivered interface and boundaries

- One shared Erlang path serves Linux, macOS and Windows. Retired Python full
  runners, fixture translators, platform fallback routes and pilot entry points
  are removed. Original application and ERTS test files remain unchanged.
- Names use `tests/otp`, `OTPTests.cmake`, `OTP_TEST_*`, `otp-tests`, `otp-app-*`,
  `otp-erts-*` and `otp-suite-*`. No compatibility aliases were introduced.
- The 16 public test presets each correspond to one build configuration and
  inherit one hidden distribution policy. Full and individual-suite selections
  use CTest labels/names; they do not add public preset families.
- Registration contains 35 applications, four ERTS components and 972 Linux
  individual-suite entries. The full selection has 39 unique components plus
  session setup and reconciliation, with no individual-suite duplication.
- Original Make, `ts:install`, `ts:compile_datadirs` and Common Test own their
  preparation/specification/compilation/lifecycle semantics. Full emulator and
  system execution retain their original ordering and cleanup boundaries.
- Individual suite/group/case selections retain their distinct diagnostic
  scope. Empty, unknown and excluded selections cannot pass. Dynamic selection
  hooks that cannot be validated by the current individual-suite preflight
  remain an explicit limitation; the full specification path uses native CT.
- Under the agreed Linux scope, `mtx_SUITE`, `ethread_SUITE` and
  `erl_print_SUITE` remain intentionally unexecuted. No private VM interfaces,
  SDK fixtures or sibling VM source dependencies were added.

The user's `tests/otp/build_tree.py` relocation is wired into CMake and its
shared process-helper import. The new `tests/README.md` was preserved. Stale
workflow/documentation callers were migrated. The manual CI workflow now runs
one explicitly selected native configuration, performs local reconciliation
and archives raw evidence; it makes no cross-platform acceptance claim.

## Final correctness fixes

Execution and reconciliation now share one common context and one live identity
verifier. Reconciliation validates retained reports without publishing an
intermediate complete matrix, then rehashes current source/adapter, SDK,
candidate, selected tools and declared inputs and rereads the current session
before final publication. A historical internally consistent epoch cannot
silently qualify a different current selection.

A time-dependent JSON defect was also corrected: re-normalizing decoded raw CT
events could convert numeric arrays such as `[8,42,32]` into strings. Existing
JSON-safe maps now preserve those arrays. A deterministic regression covers it.

Generated-source completeness remains bound to the original Make outputs,
original Emakefiles and staged/retained/generated input receipts. Missing,
edited or extra generated suites and modified recipes are rejected.

## Identities and maintained outputs

The original OTP 29.0 input pin is
`550d7b7898706c7822362c42e7b93120c1d1f29a`. The repository context at final
verification was `d886931854002d12e761163da93331f97baa560f`; file and artifact
hashes, rather than unrelated commit changes, bind the evidence.

| Identity | Value |
| --- | --- |
| SDK version / configuration | 17.0 / Linux x86_64 Emu Release |
| SDK source | `fc45b1dba20033afebee1fa282d442d2dce1c8c4d42ad70ddc48e112147c518b` |
| SDK toolchain | `21257f2875b9c46260561276e5313041cd7be4d463fefec85a00e8415184aea2` |
| SDK build | `d1dee3abf93914a1867abfd5da707940be93fdcaeb26745fc3d2a69dbc4ddbe2` |
| SDK manifest SHA-256 | `a36abfd1cd1ede9f8e1fb768554ae3f5b7f02cedc6d06f066b907b0802ac7d22` |
| Candidate VM SHA-256 | `2626627bc5c77867796a7ba5aaa3e17bbf8c1c4011a26cf34c7915dc271ec1b2` |
| Final common test epoch | `bb52a9f9255632e90440edd70cb663d9050148537e7ace153e0dc3c588633e1e` |

The maintained `build/linux-x86_64-emu` and `install/linux-x86_64-emu` outputs
were refreshed against current launcher sources with the existing explicitly
selected dependency cache. A follow-up build reported no work. The Linux VM
binary remained byte-identical after refresh. No maintained OTP JIT/Debug output
was available to refresh; all four installed SDK variants were left unchanged.
All 65 selected SDK artifacts are checked by the identity verifier; the
candidate inventory records 3,347 installed file/link entries.

The native host was Linux `7.0.0-43-generic`, x86_64, with GCC
`15.2.0-16ubuntu1`, CMake 4.2.3, OpenSSL 3.5.5 and Javac 17.0.21.0.3.
Controller execution used two schedulers, one dirty CPU scheduler and one dirty
I/O scheduler. No older-glibc, other-distribution, JIT, Debug, macOS or Windows
runtime coverage is inferred.

## Bounded execution results

| Original selection | Passed | Failed / skipped |
| --- | ---: | ---: |
| Complete EUnit main specification | 15 | 0 / 0 |
| Compiler `andor_SUITE` | 9 | 0 / 0 |
| Generated Compiler `andor_no_opt_SUITE` | 9 | 0 / 0 |
| Core-derived Compiler `lfe_andor_SUITE` | 9 | 0 / 0 |
| Emulator `bs_bincomp_SUITE` | 6 | 0 / 0 |
| Generated emulator `bs_bincomp_no_opt_SUITE` | 6 | 0 / 0 |
| Crypto engine load/register and listing cases | 2 | 0 / 0 |
| Compiler group `p`, cases `t_case,t_andalso` | 2 | 0 / 0 |
| Kernel public-driver sequence-trace cases | 2 | 0 / 0 |
| Total executed original case occurrences | 60 | 0 / 0 |

These are bounded selections and include distinct generated variants and a
repeated diagnostic subset; the total is not unique full-corpus coverage.
All nine report selections share the final epoch above. Raw outcomes contain
no callback failures, unexplained skips or source-integrity failures.

The original ordinary yielding-C shell driver passed with exit zero. The
controller selftest passed all 66 assertions across 12 project-owned CT
invocations. The maintained build-tree check passed after its relocated script
caller/import were updated.

The first build-tree invocation was accidentally sent to the unbuilt
experimental registration tree and failed before launching `erlc`. Its failure
log is retained; the corrected maintained-build invocation passed. The nine
suite/session/controller entries in that initial CTest selection all passed.

## Rejection and reconciliation evidence

The final verification covered 22 scenarios, including:

- SSL, OS_Mon, FTP and EPMD remain `blocked`, exit nonzero and start no
  preparation child command. They are not passing skips.
- Empty, unknown and Linux-excluded suite selections fail. Retired CLI option
  and profile names fail without aliases; an empty CTest selection fails.
- Current full EUnit/yielding reports match the live epoch/session, but their
  partial matrix fails solely for missing domains.
- A changed current session, a changed selected tool path, a prior epoch and
  duplicate component reports are rejected.
- A valid, passed individual-suite report with the same current epoch/session
  cannot complete a full matrix.

For the last scenario, full-only receipt validation reports
`malformed_report_evidence`, which masks the earlier specific profile error.
The initial QA assertion expected that more specific diagnostic. Review checked
the valid input, matching epoch/session, nonzero exit and independent full-only
rejection. The original assertion result and its explicit review are retained;
the functional rejection criterion passes. Improving error granularity belongs
to the deferred controller audit, not another acceptance exception.

No real 39-component matrix was claimed complete. Positive reconciliation and
negative accounting properties are exercised by project-owned selftests;
actual partial and mismatched-input runs remain visibly noncomplete.

Execution was serial. A task-owned EPMD used nondefault port 43694, bound only
to `127.0.0.1` and `127.0.1.1`. Its registry was empty after verification and it
was stopped normally. No system packages were installed, and no SDK, pinned
reference or original test input was manually changed.

## Evidence locations and limitations

Final task-owned evidence is under workspace
`tmp/otp-stage4-completion-JlimPo/`:

- `maintained-{configure,build,install,noop}.log` records output refresh.
- `inventory.json` and `registration.json` record the selectable CTest graph.
- `ct/reports/` and `ct/runs/` retain original preparation, events and outcomes.
- `qa/` retains public CLI commands, logs, reports and rejection matrices.
- `qa-summary.json`, `diagnostic-review.json` and `verification-summary.json`
  retain the diagnostic expectation and final scenario assessment.
- `completion-evidence.json` records counts and complete selected identities.

The earlier selftest proof is
`tmp/otp-stage4-evidence-hJH1tn/live-fixed-summary.json`; the final registered
controller selftest is also in the final job's `ct/reports/selftest.json`.
These paths are disposable review evidence, not product/test dependencies.

CI YAML/embedded JavaScript, caller references and preset consistency were
checked statically; no workflow was dispatched. macOS and Windows execution
remain later native passes. The original specifications, selected input
inventories and the three agreed Linux exclusions remain unchanged.

The earlier installed-product warning-filter and SSH hybrid assertions remain
unresolved parity findings from the audit; they were not weakened, waived or
claimed green here. Full distribution/application/runtime acceptance, missing
EI public metadata, service ownership, historical releases, GUI and other
prerequisites remain in their later numbered stages.

No commit, push, publication or Stage 5 work was performed by this task.
