# Linux amd64 Stage 5: recipe alignment and deferred validation

Stage 5 was closed at the user's explicit request on 2026-11-16 so Stage 6
could begin. Recipe changes are implemented, but **Stage 5 validation is not
complete**. The pending checklist below is the resumption contract. This record
is review evidence, never a build or test dependency.

The source pin remains OTP 29.0 commit
`550d7b7898706c7822362c42e7b93120c1d1f29a`. The last observed repository context
was `423c7b74714133f0d2d67997bebdc36996fb2947` plus the final ASN.1 frontend
corrections and documentation edits. The user made intermediate WIP commits;
this task made no commit, push or publication.

## Implemented recipe changes

- Restored the original application warning/error policy and source-specific
  options. Corrected Megaco scanner definitions, SNMP directory scopes, Public
  Key generated/handwritten scopes and ELDAP generated compilation options.
- Restored original Debug Erlang definitions for Diameter, ET, Megaco, Mnesia
  and ODBC, including Diameter's private compiler jobs. Private Diameter and
  SNMP compilation now shares the application options rather than a reduced
  temporary recipe.
- Restored Common Test's own output code path and SNMP's explicit
  behavior-before-implementation order. These were exposed by warning-as-error
  and clean Debug preparation; no original source was changed to suppress them.
- Removed forced deterministic generation where the original defaults omit it.
  Public Key now invokes one frontend per schema in the original 31-schema
  order. Public Key, SNMP and ELDAP use the original `-bber` frontend option.
  ELDAP also retains the original generator warning/debug/include options.
  A literal `FLAGS` list in the existing frontend helper supplies these
  arguments; there is no new parser or execution framework.
- Added the supported Linux amd64 GCC hardening and linker probes from
  `ERL_OSSF_CFLAGS`/`ERL_OSSF_LDFLAGS`. Kept per-component warnings, optimization,
  threading and linking rules explicit. Linux uses the compiler-default
  dialects, as the original recipes do: this host defaults to GNU C23/C++17.
- Corrected Crypto's declaration/link probes, default test-engine selection,
  callback dependency, narrow OpenSSL 3 warning exceptions and Debug native
  definitions/filenames. Corrected wx Debug library selection, definitions,
  generated-source reductions and frame-pointer settings.
- Restored the `openpty` fallback probe and conditional system-library link for
  `run_erl`. Applied original helper/EI warning policies. The existing Python
  process-cleanup fallback recognizes `beam.debug.smp`; no Python was added to
  the preparation/execution/reporting controller.
- Restored the original warning policies for demo and Sudoku examples, and
  compilation of the four simple examples. Their build-only BEAMs remain under
  `CMakeFiles/otp/wx/examples/simple`; the original source-only release inventory
  is preserved.

| Native component | Release | Debug |
| --- | --- | --- |
| ERTS commands, EPMD, EI, Dialyzer/Typer launchers | `-O2 -g` | Retain `-O2 -g`, add original `DEBUG` |
| Formatter / yielding-C | `-O3 -g` | `-Og -g -DDEBUG` |
| Crypto / Runtime Tools | `-O2 -g` | Unoptimized, `DEBUG`, original typed native names |
| ASN1 NIF | `-O3` | Retain `-O3`, ordinary native name |
| Megaco scanners | `-O2 -g`, original unrolling | Same native policy; MT thread definitions restored |
| ODBC | `-O2 -g`, original compile-flags-at-link behavior | Same optimization, original extra debug information |
| wx | Ordinary sources unoptimized; generated C++ `-O1` | Unoptimized; original `DEBUG`, no Release reductions/frame omission |

Linux DED libraries use original `-Bsymbolic`; wx and executables do not. ODBC
retains the original Makefile's distinct linking behavior. CMake's initial
Release `-O3 -DNDEBUG` can remain in the command line, followed by the effective
component optimization and `-UNDEBUG`. Extra explicit `-fno-common` on wx/ODBC
does not change this GCC's default behavior. Other platforms were not executed.

Linux Debug's canonical emulator is `beam.debug.smp`. Relative ordinary and
selected-flavor aliases support the unchanged launcher in a prefix containing
one selected VM. Explicit `-emu_type opt` through the ordinary alias still
selects that prefix's Debug VM. Runtime Tools has ordinary aliases to its typed
Debug natives because its original Erlang loaders request ordinary names.
These layout differences and ASN.1 staging are described in the
[source differences](../source-differences.md).

## Completed evidence

The maintained Emu Release build and installation were refreshed after the last
ASN.1 corrections. Its installed VM SHA-256 is
`459bc4433a808c30e29c9d238da6a0b1ece70227c75c9ae39ea05b7ee6967093`.
The SDK remains the installed Linux Emu Release 17.0 selection with source
`fc45b1dba20033afebee1fa282d442d2dce1c8c4d42ad70ddc48e112147c518b`.
The authoritative SDK identities are in the selected SDK manifest,
`sdk-selection.txt` and the retained controller reports; do not infer them from
the product commit alone.

- The initial source comparison found 10,472 retained original files identical
  to the pin. Only the three previously approved product-source adaptations
  differed, alongside project repository metadata/README files. Stage 5 changed
  no original product source or test.
- All 1,298 application BEAM modules match the reference inventory and compiler
  option multisets after excluding include paths. 634 raw option lists also
  match exactly; 664 differ in ordering. Broader out-of-tree include paths and
  source/debug path differences remain recorded, not treated as byte identity.
- All 65 Jinterface class files and its manifest match the reference exactly.
  The JAR container hashes differ; archive timestamps are not normalized unless
  the original `SOURCE_DATE_EPOCH` interface is selected.
- The native recipe audit passed 217 checks over 233 compile commands and 31
  native targets per Emu configuration. Its latest saved receipt predates the
  final four ASN.1 declaration edits, so the input-hash refresh remains pending.
- The Release build-tree check passed. An earlier installed Release native
  smoke passed 12 named checks; both public EI archives passed the standalone
  initialization/ETF roundtrip checks. These precede the final ASN.1 metadata
  refresh and are not the deferred combined Release/Debug/relocation check.

The final original-suite runs all passed with no failures or skips:

| Selection | Cases |
| --- | ---: |
| Compiler `andor_SUITE` | 9 |
| Crypto engine load/register and listing | 2 |
| Megaco scanner plain / port exit / garbage input | 3 |
| Runtime Tools IP/file trace ports | 2 |
| SNMP description / warning-as-error compilation | 2 |
| ASN1 invalid BER length / optional BER data | 2 |
| Total | 20 |

All six final reports share epoch
`76acfab826b166db46e280049e47efc0c2e19afa3bc378d974d0d9ec38fff0c5`.
The controller selftest also passed all 66 assertions. These bounded selections
do not qualify a complete application, the full corpus or another configuration.

## Generated ASN.1 differences: disposition

Raw chunk comparison found 963 modules identical over the selected executable,
attribute and line chunks, with 335 differing. The initial line audit resolved
325 of those to equivalent basename/line sequences with different paths or
filename-table aliases. Generated ASN.1 metadata accounts for constant line
offsets; final line-table recount after the frontend corrections is pending.

Three Public Key codecs retain different numbered internal helper names:
`CryptographicMessageSyntax-2009`, `OCSP-2024-08` and `PKIXCMP-2023`.
A strict bijection of 98 helper names makes all 1,097 normalized function ASTs,
exports and remaining source forms match. The entire 31-module generated family
has no foreign, dynamic or indirect references to these numbered helpers.
Raw Code/ExpT/helper exports are still different; the proof does not assert
byte identity.

The original reference generator reproduced the candidate CMS assignment when
given only copies of the candidate's 31 warm import databases. Fresh output
directories reproduced reference assignments across the original, bootstrap
and installed-candidate contexts. The original compiler preferentially reuses
compatible checked imports from its output directory; their checked state can
change recursive checking and reference-counter allocation. This is retained
original cache behavior, not a reason to patch the generator or redesign
bootstrap. Source/database inputs remained unchanged during the experiments.
Thirty-eight of 39 generator metadata option multisets match after excluding
paths; ELDAP retains only the documented extra `noobj` staging option.

## Pending Stage 5 resumption checklist

1. Recheck current source/SDK/dependency/candidate identities, because Stage 6
   can change them. Refresh the final original-source preservation comparison
   and native recipe/input-hash receipt after the last ASN.1 declaration edits.
2. Finish the experimental Emu Debug build. It was explicitly interrupted for
   the user's transition to Stage 6, exit 130, at 30/92 reported build steps.
   Do not classify that as a product failure or a completed Debug build.
3. Install that Debug tree under its existing task prefix, then run the prepared
   native smoke on final Release, Debug and relocated Debug. The current script
   has 13 named checks, including the new child-helper spawn/exit check; the
   earlier 12-check Release result does not cover that addition.
4. Verify canonical Debug file type, exact relative emulator/native/helper
   aliases, explicit emulator type/flavor startup, ordinary-name behavior and
   rejection of an unavailable flavor. Exercise installed, relocated and
   applicable `DESTDIR` paths without introducing a second runtime.
5. Run both public EI archive checks against Debug and relocated Debug. Rebind
   the earlier Release evidence to current archive identities or rerun it.
6. Run `private_metadata.escript`: compare 12 Diameter and seven SNMP private
   helpers against reference Release / matching Debug shipping modules, and
   check the exact five-family Debug definition scope over shipping BEAMs.
7. Complete the 37 wx example metadata comparisons: demo/Sudoku against original
   release examples; simple against the original build-only BEAMs. Confirm the
   four simple BEAMs are not installed.
8. Refresh the final generated-metadata/line-table summary, preserve the strict
   helper-renaming/cache-causality certificates, and run appropriate final
   build-tree/no-op/identity checks after any intervening Stage 6 changes.
9. Reconcile the final Stage 5 evidence and explicitly report stale/unvalidated
   outputs. No maintained OTP JIT/Debug trees existed at the start; the four
   installed SDK variants were not modified. Do not infer JIT or cross-platform
   execution from Emu recipe inspection.

Resume with the existing explicitly selected caches, not a bare preset with
unset dependency variables:

```sh
cmake -S erlang-otp -B tmp/otp-stage5-linux-amd64-nkjXHh/debug-build
cmake --build tmp/otp-stage5-linux-amd64-nkjXHh/debug-build --parallel 2
cmake --install tmp/otp-stage5-linux-amd64-nkjXHh/debug-build
```

The experimental install prefix is already configured as the sibling
`debug-install`. Do not place this experimental configuration in a maintained
preset directory.

## Evidence and process closure

Task evidence lives in workspace `tmp/otp-stage5-linux-amd64-nkjXHh/`:

- `release-{configure,build,install}-asn1.log` record the final Release refresh;
  the separate schema/public-key target logs record the narrowed comparison.
- `debug-build-asn1.log` is the interrupted final Debug attempt. Earlier logs
  preserve fixed Common Test path / SNMP ordering failures and interrupted
  intermediate rebuilds rather than hiding them.
- `ct/reports/`, `ct/runs/`, final CLI/CTest logs and
  `stage5-close-summary.json` preserve the 20 cases and controller assertions.
  Preliminary reports are separately retained in `pre-final-reports/`.
- `native-recipe-checks.json`, `beam-options-final.json`,
  `beam-chunks-final.json`, Java comparisons, and native/EI smoke artifacts
  preserve the bounded recipe/artifact evidence.
- `warm-database-causality.json`, `helper-renaming.json`,
  `helper-reference-closure.json` and their input/proof receipts preserve the
  generated-code explanation. They are analysis artifacts, not product inputs.
- `native_smoke.escript`, `ei_smoke.c` and `private_metadata.escript` are prepared
  task-only validation inputs for the deferred checklist.

The task-owned EPMD on loopback port 43805 had an empty registry and was stopped
at transition. No validation process or build was intentionally left running.
One automatic permission review timed out before execution; its authorized
retry passed. No system packages, SDKs, immutable references or original tests
were changed. The three agreed Linux suite exclusions remain intact.

Full distribution contents/documentation are Stage 6. Existing lifecycle and
prerequisite gaps remain in Stage 7; complete four-configuration acceptance
remains in Stages 8–11. Stage 5's pending validation is not silently satisfied
by advancing to Stage 6.
