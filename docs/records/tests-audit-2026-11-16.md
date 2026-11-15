# Tests directory audit — 2026-11-16

This read-only review covered the 30 maintained files under `tests/` at commit
`65dbe72`, on `master`. It traced CMake, CI, documentation and direct callers;
it did not execute tests or qualify the current checkout. Existing execution
evidence retains its own source, SDK and candidate identities and must not be
attributed automatically to this commit.

The user requested this record so the audit can be revisited separately from
finishing Stage 4. Recommendations below are review findings, not authorization
to implement every cleanup. This document is never a build, preparation,
execution or result-classification input.

Paths describe the audited snapshot. A subsequent working-tree move of
`tests/build_tree.py` to `tests/otp/build_tree.py`, and the addition of
`tests/README.md`, were already in progress when this record was written. Those
changes are preserved and require their callers/documentation to be reconciled;
this audit does not establish their completed integration.

## Overall assessment

Most files protect distribution contracts that the original OTP suites cannot
test: build-tree selection, installed SDK integration, installation, relocation,
producer isolation and public native interfaces. The existence of a caller does
not by itself justify every assertion or responsibility inside a file.

The main simplification opportunities are the oversized operational manifest,
duplicated Common Test execution/result handling in the product checker,
application-semantic regressions mixed into installation smoke tests, and CI
provisioning placed under `tests/`.

## Distribution checks and host support

| Audited file | Purpose and disposition |
| --- | --- |
| `tests/CMakeLists.txt` | Registers product checks and includes OTP suite registration. Keep. |
| `tests/build_tree.py` | Checks launchers, bootstrap/product compiler selection, application inventories, preload inspection, native loading, command transport and owned-output cleanup. Keep the responsibility; its subsequent relocation is noted above. |
| `tests/installed.py` | Owns installed, `DESTDIR`, relocated, producer-isolated and selected-original-case checks. Keep installation orchestration, but narrow duplicated Common Test execution and result interpretation. |
| `tests/build_graph.py` | Exercises real no-op builds, dependency propagation, environment poisoning, missing-output recovery and module selection in disposable source copies. Keep as an explicitly invoked, expensive developer check. It has no CTest/CI caller. |
| `tests/sdk_selection.py` | Tests SDK variant/version selection, receipts, malformed metadata and conflicting selectors. Keep. Its fixture helpers also support native architecture checks. |
| `tests/native_architecture.py` | Tests compiler/host/SDK compatibility and rejection of unsupported build configurations. Keep; this is distinct from validating SDK metadata. |
| `tests/native_process.py` | Process-group and Windows Job ownership for product checks; imported by build-tree and installed checks. Keep as shared support. |
| `tests/test_install_tree.py` | Exercises real CMake atomic publication, replacement, containment, symlink handling, modes and preservation of unrelated files. Keep. |
| `tests/landlock.py` | Linux implementation of producer-isolated installed execution. Keep while the distribution claims that boundary. |
| `tests/test_landlock.py` | Checks actual denied reads, permitted execution/writes and exit propagation. Keep as a harness test; it is currently manual-only. |
| `tests/test_windows_publish.py` | Windows publication checks, including locked-DLL replacement rejection. Keep; this covers a distinct native publication mechanism. |

Python is reasonable for filesystem/process experiments and native OS isolation.
That justification does not automatically extend to generating Erlang test
invocations and interpreting Common Test outcomes. Runtime assertions already
execute in Erlang; changing the language of host orchestration alone would not
remove its independent responsibilities.

## Installed-product fixtures

| File under `tests/fixtures/` | Purpose and disposition |
| --- | --- |
| `otp_probe.erl` | Installed identity/code paths, preload assets, restart, peers and boot-script generation. Keep; exact metadata expectations need a pinned parity basis. |
| `otp_product_probe.erl` | Bounded usability checks for packaged applications, generated resources and native components. Keep as package smoke coverage, not application acceptance. |
| `otp_distribution_SUITE.erl` | Installed Common Test execution, native loading, RuntimeTools driver and packaged helpers. Keep a narrow assembly smoke suite; review generic runtime-behavior duplication. |
| `otp_probe_tests.erl` | Installed EUnit smoke plus warning filtering, source-location and private SSH assertions. Narrow substantially or separate the semantic regressions from mandatory installation checks. |
| `otp_probe_supervisor.erl` | Sole helper for the custom supervision case. Weak independent justification; remove with that case unless a distinct assembly failure justifies it. |
| `otp_probe_nif.c` | Minimal consumer of installed public NIF headers and runtime loading. Keep. |
| `otp_probe_nif.erl` | Required loader/stub matching the native NIF module. Keep with the C fixture. |
| `otp_probe_drv.c` | Minimal installed public driver ABI consumer. Keep; driver loading is distinct from NIF loading. |
| `JinterfaceSmoke.java` | Compiles/runs against the installed JInterface JAR. Keep as a packaging/classpath check without external distributed infrastructure. |

All Erlang fixtures are currently compiled by a glob in
`tests/installed.py:219–247`, including modes that do not execute all of them.
Explicit fixture selection would clarify ownership and preparation requirements.

The warning-filter test (`otp_probe_tests.erl:17`) requires particular warning
behavior and identical executable BEAM chunks. The SSH hybrid check (`:74`)
extracts private functions from installed abstract forms and recompiles a proxy
(`:133`). The last observed installed-product run failed these two assertions;
the audit did not rerun the reviewed HEAD. They must not implicitly compel
original-source changes. Their place in the pinned parity contract requires an
explicit decision; no assertion was weakened and no exemption was applied.

The source-location check (`:46`) demands basename-only frames and exact
formatted output. Keep that precision only where the selected original build
or the agreed portable distribution contract justifies it.

## Original OTP suite adapter

The runtime layer contains 2,475 lines in six files, plus a 383-line project
probe. Its intended boundary is selection, prerequisites, integrity and evidence.
Original Make owns release layout and generated wrappers; `ts` owns installation
and native fixture recipes; Common Test owns compilation, groups, repetitions
and case lifecycle.

| File | Purpose and disposition |
| --- | --- |
| `tests/otp/support/otp_ct.escript` | Public CLI, job/session dispatch and final publication. Keep; use one common identity/context construction for execution and reconciliation. |
| `tests/otp/support/otp_ct_prepare.erl` | Original Make/`ts` preparation and sealed-input verification. Keep; simplify overlapping inventories and dependencies on retired manifest structure. |
| `tests/otp/support/otp_ct_evidence.erl` | Native selection validation, callback/skip/outcome accounting and report reconciliation. Keep the responsibility; its 1,057 lines and duplicated discovery/schema validation warrant complexity review. |
| `tests/otp/support/otp_ct_event.erl` | Raw CT events, including failures absent from the numeric return tuple. Keep this small helper. |
| `tests/otp/support/otp_ct_support.erl` | Shared commands, files, environment and live identities. Keep with a bounded support role; make it the common identity authority. |
| `tests/otp/support/otp_ct_yielding.erl` | Runs the original supplemental yielding-C shell driver outside Common Test. Keep. Parsing a CMake data registry through regex is an avoidable representation boundary to review. |
| `tests/otp/otp_ct_evidence_probe.erl` | Real positive/negative project CT checks for false passes, malformed evidence and invalid selections. Keep outside runtime bootstrap; synthetic platform identities are not native execution proof. |
| `tests/otp/manifest.json` | Registration inventories, source identities, generated variants and source-bound classifications. Keep a substantially smaller explicit inventory. |

### Manifest findings

The manifest is 2,510,416 bytes and 51,876 lines. It contains 38 Common Test
domains: 35 applications, emulator, system and EPMD. Yielding-C supplies the 39th
component through its separate data registry.

These 13 sections have no direct semantic reader:

- `auxiliary_recipes`
- `top_recipe_text`
- `empty_directories`
- `release_assets`
- `dynspecs`
- `spec_exclusions`
- `prerequisites`
- `private_vm_fixtures`
- `diagnostic_allowances`
- `recipe_corrections`
- `compile_recipe`
- `execution_blockers`
- `private_test_support`

Their minified values total approximately 345,813 bytes. They are not wholly
inert: `otp_ct_prepare:records/2` recursively harvests nested path/hash records;
`verify_manifest/3` checks their hashes, modes and embedded text; retained-entry
collection turns existing product files into runtime receipts. Preserve needed
integrity entries explicitly when removing obsolete translation/prose sections.

Directly active fields include source/domain/specification/suite inventories,
variants and generated names; `compile_sources` for authored-source lookup;
`top_recipe` for generated provenance; and native recipe text/path records used
by the EI prerequisite gate. Applicability and prerequisite rules retain source,
caller/helper identities and matching predicates. Their explanatory fragments
and old observations are not matcher inputs.

`support`, `shared_inputs` and `pinned_assets` feed recursive integrity checks.
`format` and `corpus_id` have no behavioral reader. No manifest refresh tool
remains after retirement of the old translator. A smaller curated contract plus
original Make-produced inventories is preferable to restoring that translator.

### Reconciliation correctness gap

Reconciliation currently checks the current session and recorded identity shape,
but does not compare a freshly collected complete candidate/SDK/adapter identity
with the reports' epoch. Preparation revalidates many retained files, generated
inputs and tools, but not the entire current candidate or SDK. An installed
application BEAM changed after the final component is not caught by this path.

The bounded correction is to reuse the common CLI context and
`otp_ct_support:identity/1`, compare that live epoch before publishing a complete
matrix, and test rejection of drift. This does not require another manifest
or identity implementation.

## CI provisioning currently under tests

| File | Purpose and disposition |
| --- | --- |
| `tests/windows_dependencies.py` | Live Windows CI dependency download/build provisioner. Move beside CI tooling; it is not a test. Its dependency build choices are explicit CI policy, not original OTP defaults. |
| `tests/windows_inputs.json` | Operational URLs/hashes consumed by that provisioner. Keep alongside it. |

## Concrete integration and portability findings

- `.github/workflows/upstream-full.yml:95–101` still uses removed flags/cache
  selectors and the old `upstream-full` label. Its old report-ownership/archive
  handling also refers to the retired runner. It needs migration to the shared
  path before Stage 4 is complete.
- `docs/testing.md:110–119` still describes removed Python harness checks and
  names the nonexistent `otp-original OTP-ssh-boundary` test.
- The shared distribution CT fixture launches `/bin/sh` at line 44 although
  Windows executes the same fixture. This is a test portability defect.
- `native_architecture.py:93–95` applies GNU-style `-m32` to every x86 host,
  including MSVC. That needs native platform handling.
- `test_install_tree.py:131–166` asserts POSIX modes/inodes despite unconditional
  registration. Scope those assertions to the platform contract.
- `build_graph.py` still requires `--odbc-config` and does not model the newer
  explicit ODBC include/library selectors. Its signal/process handling and output
  suffixes are POSIX-oriented; do not infer Windows coverage.
- `test_landlock.py` is manual-only and uses default temporary storage and
  `/dev/shm`; reconcile its placement requirements with workspace guidance.
- Repeated runtime checks under installed, relocated and isolated modes protect
  different delivery boundaries. They are not automatically redundant because
  their assertion bodies repeat.

## Stage 4 remainder at this checkpoint

Completed infrastructure includes the shared Erlang path without legacy platform
fallbacks, renamed interfaces without aliases, one public test preset per build
configuration, 35 application entries, four ERTS components and 972 Linux suite
entries. Full selection contains 39 components plus session setup/reconciliation
and excludes individual-suite diagnostics. Original tests remain unchanged.

Existing bounded evidence includes 61 controller checks, generated-suite
integrity/tamper checks and a final eight-entry CTest selection that passed.
The subsequent CLI checks were interrupted by the user's stop request. These
observations establish bounded infrastructure evidence, not full acceptance or
the reviewed checkout's qualification.

Required to finish Stage 4:

1. Close the live-identity reconciliation gap and validate both matching and
   changed identity behavior.
2. Finish CMake/CI/documentation integration for current names and the selected
   file layout, retaining one public preset per build configuration.
3. Complete the interrupted serial suite/group/case and prerequisite/invalid
   selection checks. Verify report reconciliation, current-session rejection,
   empty selections and absence of duplicate component execution.
4. Refresh affected available maintained build/install outputs as required;
   reconcile the final bounded evidence with actual source/SDK/candidate inputs.
5. Write the Stage 4 completion report, including limitations, failures and
   unexecuted coverage, then stop for review before Stage 5.

The broader manifest/controller simplification, fixture-scope decisions,
dependency-provisioner move and platform test repairs are preserved as audit
follow-ups. Their entire implementation is not silently added to Stage 4.
Any item that affects correctness of the Stage 4 execution/evidence path must
still be resolved or explicitly brought to the review gate.

Full product recipe parity, release/documentation completion, service and
historical-release prerequisites, and the four complete native Linux acceptance
runs remain in their later numbered stages. The two observed product assertions
need a disposition there; this record grants no exemptions. Native macOS and
Windows adjustment/execution remain later host passes.

No implementation work resumed as part of saving this audit.
