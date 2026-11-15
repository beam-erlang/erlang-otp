# Linux amd64 Stage 8: Emu Release

Stage 8 began on 2026-11-17 after the user explicitly closed Stage 7 and asked
to carry its [unfinished work](linux-amd64-stage7.md#deferred-work-at-the-user-directed-closure)
forward. **Stage 8 is in progress.** The user approved the controller and
disposable-installation correction after the first review stop; its bounded
candidate/reference proof now passes. Full qualification remains pending.
Closing Stage 7 is a checkpoint decision;
its failures, skips, unproven services, deferred historical participants and
pending manual results remain unresolved coverage. No full acceptance is claimed.

The selected original source remains OTP 29.0 commit
`550d7b7898706c7822362c42e7b93120c1d1f29a`. The candidate is the maintained
`install/linux-x86_64-emu` product, with its matching build and installed public
BEAM SDK. The complete unchanged Stage 2 Emu Release installation and configured
source remain the reference. Original sources/tests remain unchanged; the only
agreed Linux suite exclusions remain `mtx_SUITE`, `ethread_SUITE` and
`erl_print_SUITE`. Documentation generation remains unsupported under Stage 6's
revised scope. Stage 5's separate deferred validation is not silently closed.

Distribution and first-attempt evidence remain in workspace
`tmp/otp-stage8-linux-amd64-IGouLP/`; controller proofs and the second attempt
remain in `tmp/otp-stage8-ct-run-amd64-jKiLAl/`. The current full campaign is
`tmp/otp-stage8-default-epmd-amd64-1liEbJ/`. Temporary configurations and
installations stay under those owned paths; standard preset outputs retain
their normal purpose. No commit, push, publication, system package installation,
historical OTP 27/28 provisioning or SSH namespace redesign is authorized by
this stage transition.

## Execution contract

1. Refresh identities and run the existing distribution checks, including the
   installed, DESTDIR, relocated and producer-isolated products.
2. Configure a separate test build selecting the maintained candidate, original
   pin/configured source, explicit native prerequisites and matching SDK. Register
   all 35 applications plus emulator, system, EPMD and yielding-C once, without
   diagnostic suite duplication or additional public presets.
3. Execute serially with original specifications and deadlines. Preserve raw
   failures/skips, callbacks, prerequisite blocks and owned-service cleanup.
   Keep the emulator corpus in one controller VM and system cleanup ordered.
4. Compare with the corresponding original reference under matching prerequisites
   through its own original workflow. Do not label the original VM as produced
   by the project's SDK. A matching failure is evidence, not an exemption.
5. Reconcile current identities and component reports, document any unexecuted
   coverage, then report and stop before Stage 9.

The initial prerequisite profile is the unchanged Stage 7 `native-inputs.json`
(SHA256 `344dd436da171170a278190bf4f46970d8ff272dc4bf37db4b67b5ca8da49700`).
Its three closed native roots and explicit PropEr/tools remain operational
inputs. Development records are not harness inputs. Known incomplete service,
manual and historical prerequisites must stay nonpassing in results.

## Initial identities

- Product checkout: `8f9b5d216f8232afc3cb501f0d376ddd1ec7b063` on `master`,
  initially clean. Record-only changes for this checkpoint do not alter helpers.
- SDK build: `d1dee3abf93914a1867abfd5da707940be93fdcaeb26745fc3d2a69dbc4ddbe2`.
- SDK source: `fc45b1dba20033afebee1fa282d442d2dce1c8c4d42ad70ddc48e112147c518b`.
- SDK toolchain: `21257f2875b9c46260561276e5313041cd7be4d463fefec85a00e8415184aea2`.
- Launcher: `6dd3cad4ee2a1d49a8479f218594af3bac575600e543efb739fc8ff9914787a3`.
- Support: `3a3af4632ec6e105cf8073a6da3dea1fa18e4386b59a21a7f9cc33b3cf7fcc2a`.
- Initial available space: 57 GiB. Monitor it before larger execution batches;
  preserve existing jobs and immutable references.

## First candidate campaign and review stop

The experimental test build registers 51 tests: nine other distribution checks,
the controller self-check, and the full selection's session start, 39 components
and reconciliation. There are exactly 35 application tests, four ERTS tests,
no diagnostic-suite registrations and no duplicate component. Every component
is serial and selects the same three native roots. Original deadlines remain
172,800 seconds per normal component and 3,600 seconds for yielding-C.

One `ctest -L '^full$' -j 1` invocation started the candidate campaign and its
session. Individual application invocations were not used to restart that
session. Kernel compiled its 64 selected suites and declared 1,940 cases.
Execution stopped during `erl_distribution_SUITE:tick_change` after two
confirmed adapter-context failures. Last completed native statistics:
**187 passed, 2 failed, 7 user-skipped, zero auto-skipped**. There is no
`test_done`, finished Kernel receipt or complete-component result. The other
38 components and reconciliation were not attempted.

Raw console output, Common Test logs/events and preparation receipts remain
under the evidence root. SIGINT interrupted CTest before it emitted the
requested campaign JUnit/output-log files; their absence is explicit, not a
successful empty run. Earlier Stage 7 diagnostics do not fill this coverage.

## Distribution results

| Check | Current outcome | Elapsed |
| --- | --- | --- |
| Installed | Passed | 15.17 seconds |
| DESTDIR | Passed | 10.42 seconds |
| Relocated | Passed | 13.72 seconds |
| Producer-isolated | Passed | 15.50 seconds |

The first sandboxed attempt failed all four at the same loopback TFTP socket
bind with `eperm`. The authorized unchanged rerun outside that tool sandbox
passed all four in 54.81 seconds. Both attempts' raw reports are retained in
`distribution/`. No source/test change was made to obtain the rerun.

These four checks establish their distribution boundaries only. The installed
payload's 3,617-entry identity remained unchanged, as did selected SDK/VM bytes.
The generated build `install_manifest.txt` reflects the last private install;
temporary installed prefixes were removed. Isolation passed through Landlock,
with existing Python ctypes deprecation warnings retained in the raw log.

## Confirmed harness failures

| Original case | Actual failure | Cause and implication |
| --- | --- | --- |
| `code_SUITE:all_loaded` | Module/filename assertion at original lines 632–635 | Five support modules are loaded with `.erl` filenames by `compile_controller`; the generated escript module is also present. The original case requires each nonpreloaded module's filename basename, minus `.beam`, to equal its module name. Running CT inside this escript violates that contract. |
| `code_SUITE:on_load_embedded` | `{case_clause,{error,erofs}}` at original line 1529 | The original case deliberately creates `code:lib_dir()/on_load_app-1.0`, compiles its fixture and starts an embedded peer. The launcher's blanket read-only installed prefix prevents the link before those assertions execute. |

These results demonstrate project execution-context interference, not a VM or
code-loader regression. Original tests/assertions were not changed. The
diagnostic receipt is `kernel-first-review-gate.json` (SHA256
`38a3ca9dca8658d4bfdd106a972826272f4df410ff3895ae17d449701e577586`).

Three native skips originate from the exact `code:coverage_support()` false
guard in `code_coverage_SUITE`, selecting `toggle_modes`, `get_coverage` and
`error_info`. No blanket Emu exemption or new passing classification was added.
The other four are `erl_boot_server_SUITE:start/start_link/add/delete`, reporting
`Not enough good hosts`. These are unresolved capability/endpoint coverage,
not accepted results. No original reference corpus has run for this attempt.

## Interruption and preservation

The agent sent one SIGINT only to the uniquely identified campaign CTest PID
3134297, rechecking its executable, exact test-directory arguments and start
time. The parent execution session returned 130. All 25 watched campaign
processes were subsequently gone, with PID-reuse checks. The readable namespace
scan found no owned matches; four unrelated pre-existing process namespace
reads were denied. Wrapper termination/status receipts were absent, so no
successful trap/callback completion is claimed. Raw interrupted logs, events
and inputs were retained in `cancellation/`; no other process was signalled.

The existing read-only `otp_ct_prepare:verify/1` subsequently passed for all
11,817 original files and every declared staged/retained/generated/artifact/
receipt closure, with no differences. All 17 initial identity files still
match. The check compiled only existing verifier modules in memory and started
no CT, service or network. See `kernel-interrupted-integrity.json` (SHA256
`96210b6bd8ed9a0202b042e0f5ef86e2318c49333998ecee2da4d7d97b85893f`).

## Boundary correction approved after the first stop

The user's script-rework review gate caused the first stop. The design proposed
for review was:

1. Prepare and verify the original Make/`ts` payload in a short-lived preparation
   process. Keep orchestration modules outside the case VM.
2. Run the selected installed original `ct_run` in a fresh controller VM. Compile
   the event helper normally to its real `.beam` file. Use the original main
   specification and native CT terms for measurement and the three agreed
   exclusions. Common Test continues to own specification/group/case semantics.
3. Supply an exact task-owned writable copy of the installed prefix for original
   fixture operations, while keeping the maintained installation read-only.
   Verify copied bytes, modes and link text before execution; preserve and
   assess generated/mutated view contents afterward. Record the producer prefix
   and execution view separately. This replaces isolated per-suite exceptions
   with a deliberate installed-test boundary.
4. Assess native statistics, events, callback outcomes, identities and completion
   afterward in a separate process. Process exit zero alone cannot accept a run.
   Reuse existing strict evidence handling and keep CMake limited to arguments,
   registration, dependencies and timeouts.

No such change was applied before the review. The user then explicitly approved
using original `ct_run` and a verified disposable writable installation, keeping
original sources/tests unchanged. The implementation and proof follow below.

`reference-execution-plan.{md,json}` records all 39 reference components and
their original recipes. The reference uses its own upstream runtime/public
development-file identities, without a project SDK producer label. An
unexecuted temporary command draft exists in `reference-commands-fJdev0/`;
it is uncompiled, needs revision/review and is not ready to run. At that review
stop, no reference Make, generator, service or testcase had executed. The new
bounded proof below uses a separate driver. Actual OTP 27/28 remains deferred.

Stage 7's deferred-work table remains open. Stage 8 is not accepted or complete,
and Stage 9 has not started.

## Implemented controller and installation boundary

Current evidence is under workspace
`tmp/otp-stage8-ct-run-amd64-jKiLAl/`. The earlier attempt remains untouched.
The existing shared Stage 8 execution lock still serializes all tests.

The existing escript prepares inputs and assesses results. It launches the
selected installation's original `ct_run` in a separate Erlang process and
executes no cases itself. The orchestration process remains alive outside the
Common Test process, rather than introducing a new cross-platform shell
framework for preparation/assessment. This is the bounded orchestration
difference from the initial three-process proposal. The actual controller,
specification parsing, groups, repetitions, suite/case lifecycle and compiler
semantics remain original Common Test behavior.

The child receives the original specifications plus native CT terms for the
event handler/configuration and agreed exclusions, using `-join_specs` and
`-allow_user_terms`. Only the normally compiled `otp_ct_event.beam` measurement
helper is added to that process; preparation/assessment modules stay outside.
The child records actual startup/completion facts, without preloading Crypto or
Mnesia just to measure them. Pinned native `totals.info`, raw events, child
runtime snapshots, process exit and completion must agree. Exit zero alone
does not accept cases, skips or callbacks.

Every run gets a fresh complete byte copy of its producer installation under
owned scratch. Root/directory/file modes, bytes and literal link targets must
match before launch; no hardlinks point back to the producer. The full producer
tree hash is part of the common identity. Final receipts separately record all
added/changed/deleted copy entries and verify the immutable producer again.
Changed/deleted original copy inputs require review. The old Tools-only Emacs
mount/identity exception was removed; legitimate fixture writes now use this
single installation boundary. Receipts record before/after state, not an audit
of transient writes during individual cases.

CMake only gained the optional input-profile argument for its existing
controller self-check. Original names, one public test preset per configuration,
serial registration and deadlines remain. Original product/test files and SDK
interfaces are unchanged. The same common controller/copy path serves other
platforms; no parallel compatibility route was introduced, and native evidence
for those platforms remains pending.

## Bounded proof after the correction

| Proof | Result | Preservation |
| --- | --- | --- |
| Project controller regression check | 75/75 checks passed | Deliberate case/callback/cleanup failures, real missing CT configuration, empty selections and altered native evidence remain nonpassing. |
| Runtime copy/receipt probes | 18 checks passed | Actual candidate copy: 3,618 entries including root, exact bytes/modes/link targets, distinct inodes and unchanged read-only producer. |
| Candidate original `all_loaded` and `on_load_embedded` | 2 passed, 0 failed, 0 skipped | 11,817 original inputs unchanged; no producer/copy delta or identity drift. |
| Original-reference same two cases | 2 passed, 0 failed, 0 skipped | 11,817 original inputs and all 3,443 original installed-manifest entries unchanged; 3,680-entry full reference tree/copy identical, empty final delta. |

The project missing-prerequisite probe now uses original CT's real
`{require,probe_service}` case metadata. Its earlier synthetic case fabricated a
`require_failed` return, which native logs categorized inconsistently; that
failed attempt is retained. Strict native/event count equality was not relaxed.
Both original-case proofs retain matching native totals/events, zero not-built
suites, single completion/logging events and the actual child root/node.
Reference identity has no project SDK field; it remains an independently built
original distribution. Explicit EPMD/namespace cleanup was observed for the
reference, with no surviving owned namespace process.

The maintained Emu Release build regenerated and remained a no-op. Available
other configurations are not qualified by these changes. The current run must
use a fresh session and new helper identities; earlier partial/full diagnostic
reports cannot satisfy this campaign.

The registered CTest `otp-test-controller`, using the actual optional native
input profile and existing owned EPMD lifecycle, also passed in 68.44 seconds.
This verifies the public registration path rather than only the temporary probe
bootstrap. It does not count as original application-corpus execution.

## Second corpus attempt: EPMD environment and cancellation

The fresh full selection reached Kernel, its first of 39 components. Before
interruption its raw events recorded 436 passed cases, one failure, 48 counted
user skips and no automatic skips. It stopped during
`gen_tcp_echo_SUITE:slow_passive_echo`; there is no native completion, final
runtime-change receipt, reconciled report or completed application batch.
The two previously failing code-loading cases passed in this full run.

`erl_distribution_SUITE:epmd_reconnect` exposed a controller environment error.
Its unchanged recipe explicitly selects EPMD port 12321. The adapter's inherited
`ERL_EPMD_PORT=43690` is translated by the original `erlexec.c` into an earlier
`-epmd_port` argument; original `erl_epmd:get_epmd_port/0` selects that first
argument. The first original `wait_for_names` therefore timed out before the
case's daemon kill/restart assertions. The retained native HTML is hashed as
`f6bcbab7a3b67e1958d765fc82387f142f64a244d84232365ddb2d7d2e5e6686`.
This is an adapter defect, not accepted evidence of a product EPMD failure.

Linux now clears global EPMD port/address overrides and owns original default
port 4369 inside its already private network. Original suites' explicit
alternate ports can then take effect normally. The launcher no longer has an
`--epmd-port` option; Linux input profiles must omit the field or select 4369.
The inherited IPv4 distribution-interface override was also removed to preserve
native transport selection. No original source, test or staged recipe changed.
The interrupted selection remains a separate helper epoch and will not be
relabelled as a completed run.

CTest-only SIGINT exited CTest with status 130 but left its wrapper and owned
namespace alive. The uniquely revalidated wrapper was then sent TERM; its
existing trap returned 143, reaped the namespace parent and removed all 17
watched process identities. A subsequent readable namespace scan found no
owned survivors. Four unrelated pre-existing namespace entries were unreadable
and are recorded as observation limits. The retained cancellation receipt is
`epmd-port-stop/summary.json`, SHA-256
`02285db6175cdd8badcc83c43812a58b1e03e97e23de533073d96e2d4e3d9aa0`.

A bounded launcher correction arms TERM on parent death using the selected
util-linux `setpriv`, before creating any owned children. It rechecks the
original parent identity after re-exec to reject the intervening death race;
the existing TERM/EXIT cleanup remains the only cleanup mechanism. Synthetic
CTest cancellation passed: normal completion returned zero, a mismatched parent
was rejected before work creation, and SIGINT to only the synthetic CTest caused
automatic wrapper TERM/143 cleanup. All eight watched processes and owned
namespace members disappeared in 11 ms, without a follow-up wrapper signal.
The receipt `parent-death-probe-recheck/summary.json` has SHA-256
`e0194d95bb2479ec20e7e74f12ed565527c7c4bcccce0d165c2498868caf6e9b`.
The first job-only assertion incorrectly required numeric exit 130 rather than
the equivalent POSIX SIGINT termination; that raw attempt remains retained.

The unchanged original `epmd_reconnect` case then passed independently on both
candidate and original reference: one passed, zero failed/skipped, native totals
and events agree, no not-built suites, complete native lifecycle, no original
input changes and empty producer/runtime deltas. Candidate report SHA-256 is
`8afb68f9a2482baa9e48e486161bd7ea9012512d5ba85c9e68007bdc9ca5d4a6`;
reference verification receipt SHA-256 is
`49cbd4d68ba4e27e87c2cdb0172e502eb313e5adb0e95ae545a2d19f27f1e6af`.
The reference case exercised its original alternate-port kill/restart behavior.
Both controller snapshots show no injected `epmd_port` argument; the owned
default daemon used 4369. The earlier successful two-case proof is untouched.

Post-interruption read-only verification also confirmed all 11,817 original
inputs and all preparation closures unchanged. Producer and stopped runtime
match their 3,618-entry baseline with no delta. A diagnostic invocation without
locale settings initially misread three Unicode names; independent byte/mode
checks and the identical verifier with UTF-8 locale passed. This does not supply
the missing original run completion/finalization evidence.

The registered controller self-check passed again with the corrected default
EPMD/parent-death route: all 75 checks, CTest 73.40 seconds. The fresh campaign
directory is workspace `tmp/otp-stage8-default-epmd-amd64-1liEbJ/`; it registers
39 original components plus session setup/reconciliation, with no individual
suite diagnostics in that selection. Earlier attempts remain separate evidence.
Its maintained Emu Release build regenerated with `ninja: no work to do`.
The new full selection starts in one CTest invocation under the existing shared
lock; setup, 39 components and reconciliation share a fresh session. Frozen
campaign inputs/proof bindings have SHA-256
`0ded7416381a8aa8b18967fec6d91d8dd560c2e937024a3b1af7a986064077b2`.
No component completion or full acceptance is claimed at launch.

At launch about 52 GiB remained free. Current per-component retained inputs
allocate roughly 642–695 MiB, so the candidate matrix baseline fits. Retaining
both full matrices plus case-generated data may exceed that capacity; review
space and task-owned retention before starting the full reference matrix.
Read-only retention review found seven task-generated `otp-inputs.tar` files
with identical bytes: 229,601,280 bytes each, regular mode 0664, SHA-256
`f9876904dd3f765162a64067b3185c197975653180fffcfa026be83bca852b12`.
The archive verifier binds absolute path, regular-file kind, byte count and
hash, without an inode/link-count binding. After candidate reconciliation,
archive-only hardlink consolidation could preserve every recorded path and
receipt while reclaiming duplicate allocation. The present seven-file group
would save 1,377,632,256 bytes; a matching 38-CT-component matrix could save
about 7.9 GiB. Re-enumerate and verify the actual closed group before any action.
No archive, raw evidence, source/test tree, runtime copy, producer installation
or pinned reference was modified during this review.

The 48 counted skips remain raw nonpassing results: three coverage guards,
four insufficient-host selections, two missing OTP 27 selections, one
unsupported alternate-name case, two Windows-specific cases, 34 SCTP guards,
one connection-refusal timing case and one missing IPv4 link-local address.
Four further callback skip events are uncounted by native case totals. The
source-based disposition receipt `kernel-skip-disposition-review.json` has
SHA-256 `b74593f717aa843b729b01937a211bc010c5007af472565453fd7020d8a5bef7`.
These categories introduce no new exemptions. Historical releases remain
explicitly deferred.
