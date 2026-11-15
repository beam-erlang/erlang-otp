# Linux amd64 Stage 7: test prerequisites and lifecycle

Stage 7 began on 2026-11-16 under explicit authorization to close Linux test
prerequisite and lifecycle gaps. **Stage 7 was closed by explicit user direction
on 2026-11-17, with unfinished work deferred below.** This completes the stage
checkpoint, not prerequisite readiness or product acceptance. The earlier work
stopped at the broader harness-design review gate. The user resumed
it with original sources and tests unchanged, original-runner FTPS reproduction,
and actual OTP 27/28 provisioning explicitly deferred. This record is
development evidence, never an input to the test controller or build.

The pin remains `550d7b7898706c7822362c42e7b93120c1d1f29a`. The selected
candidate is the maintained Linux x86_64 Emu Release installation, using its
installed public BEAM SDK. The unchanged complete Stage 2 reference and its
configured source remain comparison/preparation inputs. Stage 5's deferred
validation remains separate; unsupported documentation generation from Stage 6
is not reopened. No new original-source or original-test change is authorized.
The three agreed Linux exclusions remain `mtx_SUITE`, `ethread_SUITE` and
`erl_print_SUITE`.

## Original setup and the containment boundary

| Component | Original behavior | Required boundary |
| --- | --- | --- |
| SSL | `ssl_test_lib` invokes `pkill openssl`; suites create TLS, OCSP, CRL and peer processes. | Private PID namespace with its own procfs, private network, owned writable files and descendant teardown. |
| FTP | Main suite selects tagged processes through `ps`; property helper uses `killall vsftpd`, daemonization and `netstat` PID discovery. | Same process/filesystem/network boundary, selected real vsftpd and netstat. Original `run_as_launching_user=YES` disables daemon chroot; containment must come from the OS envelope. |
| OS_Mon | Linux CPU and disk cases discover helpers through `ps` and kill their PIDs to test recovery. | Private PID/proc view while retaining real OS helper/resource observations and original deadlines. |
| EPMD | Suite owns TCP 2243 and SSH forwarding port 2244; two cases require a genuinely nonlocal connection. | Owned controller EPMD on a separate port; isolated ports; real SSH peer in a second private network namespace with a distinct source address. |

The project-owned `tests/otp/support/otp_ct_linux.sh` is one Linux launcher.
CMake selects its arguments; it does not parse specifications, provision test
services or reproduce Common Test lifecycle semantics. The launcher uses an
outer user/PID/mount/network namespace and an inner bubblewrap view retaining
the invoking UID/GID. Host inputs are read-only; only the owned workspace
`tmp/` job is writable. Procfs, devpts, temporary files, IPC, runtime directories
and SSH state are private. Resource limits are not introduced, because OS_Mon
and emulator tests observe real host resources.

For EPMD, a veth pair connects controller `10.203.0.1` to peer `10.203.0.2`.
An unmodified nonroot OpenSSH daemon runs with private keys and configuration;
the original `ssh -L2244:<controller>:2243 otp-epmd-peer read` command is retained.
The peer resolves the controller name to its private non-loopback address.
The controller resolves its own name to loopback, as required by the existing
distribution setup. No host account, system SSH configuration, shared daemon
or host network is changed.

Admission checks compare the six actual namespace identities against the
launcher's outside identities and require a read-only root mount. A profile
boolean cannot remove the lifecycle gates. Selected launcher tools are hashed
in the stable execution identity; per-run namespace IDs are execution evidence,
not part of the common cross-component epoch. The controller starts its own
candidate EPMD inside the verified namespace and checks its registry before
shutdown. Namespace exit also removes detached descendants after failure,
timeout or cancellation.

## Bounded evidence so far

Evidence is under workspace `tmp/otp-stage7-linux-amd64-4HJPzb/`.

- `prerequisite-inventory.{json,md}` audits all 39 components: 35 applications,
  emulator, system, EPMD and the separate yielding-C driver. This is a source
  inventory, not a claim that every component is ready or has run.
- `envelope-probe/attempt-rkKeP2/result.json` records success (0), deliberate
  failure (17), timeout (124) and cancellation (143). Original-style name-based
  cleanup affected only inner inert canaries. Matching outside processes and
  an outside TCP listener survived; detached inner children disappeared.
  Procfs, loopback IPv4/IPv6, PTY/devpts and read-only host-file probes passed.
- `epmd-proxy-probe/` records real OpenSSH forwarding with the original command
  shape and a measured peer source address of `10.203.0.2`. This is transport
  evidence; the two unchanged EPMD assertions still require execution.
- `controller/reports/prepare-os-mon-2.json` records successful original
  OS_Mon preparation through the new controller admission. The first disposable
  invocation omitted the controller's domain argument; its failed log/report
  is retained rather than counted as test execution.

One automatic approval review rejected a product-launcher probe by citing an
earlier user stop from a previous stage. A direct retry explicitly citing the
latest Stage 7 authorization was accepted and the harmless `true` smoke passed.
An additional synthetic layer around the already nested launcher encountered
the host's nested-unshare policy; it is not a supported or passing topology.

## FTP release scope and selected inputs

The original FTP `release_tests_spec` defaults release only two suites, although
the retained inventory and original all-suite selection include its property
suite. The adapter supplies two original Make variables for this domain:

```
MODULES=ftp_SUITE ftp_format_SUITE ftp_test_lib ftp_property_test_SUITE
FTP_DATADIRS=ftp_SUITE_data property_test
```

The unchanged Makefile and `make_emakefile` generate and release the additional
unchanged inputs. No Emakefile parser, compiler-option reconstruction or manual
suite rewrite is added. `ftp-preparation-probe/result.json` records three
released suites, four freshly compiled modules, unchanged original compiler
options and 13 matching original manifest inputs. The assignments are recorded
in the sealed preparation receipt.

Three explicitly selected Ubuntu packages were downloaded and extracted into
`downloads/otp-stage7-ubuntu-resolute-amd64/`, without system installation or
another OTP core: net-tools `2.10-2ubuntu1`, erlang-proper and erlang-proper-dev
`1.5.0-1build1`. Archive hashes and sizes match local APT metadata. The package
label is not the application identity: its `proper.app` declares `1.4.0`, and
its BEAM compiler information reports `8.6.1.2` with stripped source/options.
All 26 modules load on the candidate and a trivial property passes; four
headers are present, with no native shared object or `load_nif` import found.
This bounded check does not establish all original property-suite compatibility.
The original FTP property module also compiles with `-DPROPER` using the
candidate and these inputs. See the package `artifact-validation.json` receipt.

## Remaining readiness work

The complete canonical specifications remain authoritative. In particular,
SSL and INETS main specifications include benchmark suites; separate benchmark
specifications are not permission to omit them.

- Finish controller/lifecycle integration and original-case evidence, negative
  admission, timeout/cancellation and cleanup checks for the production launcher.
- Preserve the now-validated property application/include selection and
  candidate-peer inheritance without shadowing OTP modules. Historical
  participant activation is deferred; candidate code must not leak into it.
- Record the original historical provisioning contract and deferred real
  participants/catalog. Do not acquire or build OTP 27/28 in this stage. An
  empty directory or current-runtime impersonation does not provide coverage.
- Close actual DNS, SSH, Telnet, Net-SNMP, HTTP proxy/nginx, LDAP and PostgreSQL
  prerequisites and their selected configuration/data closure. Existing
  extracted service binaries alone are not a working service selection.
- Supply a private graphical display and real PTY, terminal/editor tools.
  Preserve original capability checks and timetraps. The three wx OpenGL checks
  explicitly require manual `user` configuration; automated display startup does
  not supply those results.
- Preserve the optional SSH foreign-version image catalog's zero coverage when
  no images are selected. Stdlib's exported Docker example is not selected by
  `all/0` or `groups/0`; it is not a canonical prerequisite. Neither the pinned
  original base image nor its workflow provisions an inner Docker image catalog.
- Obtain genuine outcomes for the 27 original Debugger manual cases. Separately,
  `dbg_ui_SUITE:dbg_ui/1` unconditionally skips even with a display
  (`Gunilla: Workaround`); Xvfb cannot make that original case pass. No new
  applicability exemption or fabricated manual result has been added.

The user explicitly selected **record manual checks as pending** while the
automated prerequisites are completed. Those 27 checks remain missing manual
coverage; this does not create passing results or a full-acceptance exemption.

Installed public EI `src/eidefs.mk` now exists from Stage 6; the old general
missing-EI claim is stale. OS_Mon and EPMD themselves do not require EI native
data recipes. Other native preparations and all four configurations still need
their own current evidence. No full Stage 8 corpus qualification is claimed.

## Earlier bounded executions

| Bounded execution | Outcome | Disposition |
| --- | --- | --- |
| Registered controller self-test | Passed, 21.28 seconds | One existing public test preset; no additional preset family. |
| OS_Mon full specification | Native return `{22,0,{2,0}}` | Strict nonpassing: background CPU utilization (5.174762%) exceeded the original guard, 33% divided by 22 logical processors (1.5%); the other raw skip is the source-bound Linux `os_sup` applicability guard. No failing case or callback remains. |
| EPMD nonlocal registration/kill | 2 passed, no failure/skip | Actual bidirectional SSH preflight and original daemon messages confirm nonlocal traffic, rather than a denied SSH channel. |
| FTP passive `ls` | 1 passed, no failure/skip | Real downloaded vsftpd, original server configuration and private `ftp` account. |
| FTPS passive `ls` | No case passed; group setup skipped | Missing CA options in the unchanged original test; remains nonpassing. |
| SSL RFC 5869 vectors | 7 passed, no failure/skip | Cryptographic vectors only; not complete SSL or OpenSSL lifecycle coverage. |
| SSL TLS 1.3 ALPN selection | 1 passed, no failure/skip after helper compilation fix | Original helper options, ALPN `spdy/2`, data exchange and all five callbacks verified. The earlier metadata `undef` is retained as a superseded project failure. |

`final-bounded-results.json` retains the six diagnostic outcomes and their
actual helper/input epochs. `epmd-final-selected-tool.json` is the subsequent
EPMD recheck after making its preflight use the same controlled PATH lookup as
the original suite. It again passed both cases, with no identity drift, the
actual `10.203.0.2` peer and the selected SSH executable hash. These diagnostic
reports are not combined into a full-acceptance matrix.

Earlier failures remain recorded. The original `escript` boot did not start
SASL despite its argument; explicit public application startup now matches the
original controller. Inherited `ERL_FLAGS` also duplicated the original peer
helper's `-setcookie`, causing authentication failure and the OS_Mon timeout.
The controller now supplies its cookie once and writes a mode-0600 cookie file
in its owned home for ordinary peers. The original peer's own cookie options
retain authority. The formerly blocked memory-data case now passes, without
changing its timetrap or assertions.

FTP initially could not find its required `ftp` account. Its launcher now
generates a private passwd/group view with that account mapped to the invoking
UID/GID, leaving the host databases unchanged. Admission hashes the mounted
private account files. The original configuration, daemon and anonymous data
operations are retained. Native executable selection and PropEr activation
were also checked independently: original `include_lib` compilation, five
properties, candidate-peer inheritance and core application origins passed.
Negative input checks include a FIFO rejected before hashing, mode/target drift,
escaping links, OTP module/runtime shadowing and invalid historical combinations.

Work/input overlap is now rejected: the launcher checks its known source and
candidate roots, and controller admission checks all declared immutable roots,
tools, profiles, artifacts and framework paths before original preparation.
`rejected-overlap.json` is blocked with `linux_work_input_overlap`; no original
archive or Make command was created. The launcher also clears ambient Erlang
and dynamic-loader injection variables before starting the VM. The final
timeout probe entered its private PID namespace and returned timeout 124;
the launcher recorded signal exit 143 and reaped its owned namespace parent.
Earlier explicit cancellation evidence measured 78 ms and zero survivors.

The maintained Emu Release build was regenerated and is a no-op. Its installed
payload was not changed by these harness edits. Other OTP configurations were
not built or qualified. CI dependency declarations were updated statically;
no workflow or system package installation was executed. Three dependency
archives were extracted into the download cache only.

`closing-source-preservation.json` verifies all **6,838 retained original
corpus inputs**, including supplemental EPMD and yielding-C paths, against the
pin with no content or executable-mode changes. The earlier 6,756-input count
covered application/emulator/system paths only. The 155 already omitted paths
in that narrower repository inventory remain pre-existing omissions; original
preparation still archives the full pin. Presets are unchanged: 16 public test
presets, one per supported build configuration. No private VM fixture export,
additional Linux exclusion, original test edit, commit, push or publication
was performed by this work. User-created WIP commits during execution are
preserved.

## Original-runner reproduction and provisioning decision

The resumed work follows the pinned original provisioning contract rather than
patching historical sources. `.github/dockerfiles/Dockerfile.ubuntu-base` fetches
kerl, updates its release catalog, selects the latest patch in each of three
major families and builds/installs each with kerl. Tests consume those installed
participants. The recipe also records the latest participant's path/version.
It does not build old releases from the current product or use its SDK. Its
unversioned kerl/catalog inputs mean an actual future provisioning run must
record those identities and resolved releases. The user's current instruction
defers providing OTP 27/28; no historical runtime was acquired or built.

`original-ftps-runner-1DbDQ7/comparison.json` binds fresh pinned source copies,
original Make/test-target/`ts`/`ct_run` commands and raw outcomes for candidate
and complete original reference. Both run the unchanged `ftps_passive` / `ls`
selection. Both exit zero but report **zero passed, zero failed, one user skip**:
`{options,incompatible,[{verify,verify_peer},{cacerts,undefined}]}`. The case body
does not execute. Original `ct_run` accepts this user skip; the project's strict
result handling retains it as nonpassing. This proves the fixture's behavior
under the original runner; it does not provide FTPS coverage or an exemption.
All 11,817 present original source inputs per copy and all 3,443 original
installed-reference entries remain unchanged. Namespace survivors: zero.

The helper-discovery repair uses exported `ct_make:all/1` and `ct_make:files/2`
with the original helper options before calling suite metadata. The original
Emakefile owns discovery and options. Its persistent probe exercises a helper
requiring an Emakefile macro/header, a broken helper and CWD restoration. All
69 project checks pass. The real original TLS 1.3 ALPN case then passes, with
no input drift and all callback outcomes intact. Evidence is in
`helper-metadata-BO8K5i/` and `ssl-alpn-helper-fixed-review.json`.

## Withdrawn proposals: historical evidence only

The earlier historical Perl patches and FTP CA/SNI patch remain unapplied.
They are withdrawn from the current design and are not pending approval
requests. Exact proposals remain in the job's `historical-proposal/` and
`ftps-option-review/UNAPPLIED-ftp-trust-proposal.patch` as historical evidence.
The proposed SNI option would add hostname checking to the original socket
upgrade; the original-runner reproduction does not justify that as a minimal
parity repair. No older source was extracted or built.

## Native inputs, display and installed Emacs fixture

The resumed work downloaded 42 native prerequisite archives (73,230,106 bytes)
into `downloads/otp-stage7-native-prerequisites-ubuntu-resolute-amd64/`.
Package hashes/sizes were checked; no installation or maintainer script ran.
Knot, Apache/tinyproxy/ncat/nginx, Net-SNMP, Emacs/Vim and Expect are selected
native dependencies, not additional Erlang installations. Native package and
actual executable versions are recorded separately; Net-SNMP reports
`5.9.4.pre2` despite its package's `5.9.4+dfsg-2ubuntu3.1` version.

The original extracted roots remain unchanged. Closed task-owned runtime views
complete needed development-library links from hash-recorded matching host
inputs. Exactly two inert dangling documentation links are omitted: the
Emacs alternatives manpage alias and PostgreSQL's missing package README.
The actual manuals remain. An empty optional nginx module directory completes
its package link; no optional module or coverage is invented. The receipt
records every added file/link, mode, omission and its reason. The final ordered
profile `native-inputs.json` binds three roots and 238 artifacts. Its SHA256 is
`344dd436da171170a278190bf4f46970d8ff272dc4bf37db4b67b5ca8da49700`.
Some lower-host interpreted tool data still needs a complete active-input
binding review; the package/ELF audit alone is not full runtime-data closure.

CMake forwards only the ordered native-root paths. The launcher overlays their
`usr` and `etc` resources read-only at conventional paths; the Erlang verifier
checks their closed trees and exact launch record. Original specification/Make
semantics and service provisioning do not move into CMake. Runtime commands,
conventional Erlang installation directories and BEAM payloads are rejected
from these native roots. The existing separate PropEr selection remains intact.
All 39 complete-component registrations forward the same three roots; 1,023
total registered tests include diagnostic suites and routine checks. No new
public preset is introduced.

The final namespace smoke validates all 238 artifacts and three closed-root
digests with the frozen helpers. Its fixed-path tool batch is **nonpassing**:
18 of 19 expected commands succeed, but `/usr/bin/tinyproxy -v` exits 127 with
empty output/error. The earlier extracted-path loader probe succeeded; that
does not establish the overlay invocation. No service was started in this
smoke, and no repair or passing waiver was applied. Raw evidence is in
`native-prerequisites/final-smoke/work/`.

Private Xvfb authentication/connectivity and installed-candidate wx startup
passed. Nongraphical domains receive no ambient display. Tools receives an
exact task-owned copy of its installed Emacs subtree at the same logical
installed path. Its original suite legitimately compiles beside `.el` files.
The complete installed input map remains identical; only new regular `.elc`
outputs with exact original `.el` siblings are permitted and separately hashed.
The physical installation is read-only. An actual Emacs compilation generated
`erlang-start.elc` only in that private view; all nine installed Emacs inputs
retained their bytes and modes. GUI and Tools cancellation completed in 10/11
milliseconds with zero recorded survivors. These are bounded environment
checks, not execution of the complete wx/Tools suites.

`native-gui-launcher-check/verification-final.json` binds the final 240-line
launcher (`6dd3cad4ee2a1d49a8479f218594af3bac575600e543efb739fc8ff9914787a3`).
`native-roots-support-check-YNlrlj/verification.json` binds the final Support
module (`3a3af4632ec6e105cf8073a6da3dea1fa18e4386b59a21a7f9cc33b3cf7fcc2a`),
compiled with warnings as errors, and 53 bounded input/mount/Emacs checks.

## Review gate: real OpenSSH PTY support

The private network now has genuine veth IPv4/IPv6 connectivity. The exact
Net-SNMP-style nonloopback IPv6 UDP guard passes. Nonroot OpenSSH on private
localhost port 22 authenticates with the task key; only the private network's
`ip_unprivileged_port_start` changes to zero. The host remains at 1024. The
existing EPMD peer route and its tighter port/forwarding policy are retained.

However, a real SSH PTY request fails:

```
chown(/dev/pts/0,1000,5) failed: Invalid argument
Attempt to write login records by non-root user (aborting)
```

The current nested user namespace maps only the invoking user/group. It cannot
supply the tty group and privileged sshd login-record operations required by
that request. Public-key authentication is insufficient proof of PTY readiness;
SFTP, rejected-key and remote-EPMD checks after the abort are unproven.
The failure/log is retained in the launcher receipt's SSH probe references.

Continuing would require a reviewed service-identity/UID-GID mapping design or
a genuinely provisioned execution environment with ordinary privileged sshd
startup and user sessions. This is broader harness rework than another native
tool selection. Work stopped before that redesign, any private root-account
alias, weakened SSH check, original-source edit or service framework. The
evidence does not demonstrate complete prerequisite readiness. The user's later
checkpoint closure does not change that technical result.

The PostgreSQL/ODBC and LDAP proposal is concrete but unexecuted, under
`service-contract-proposal-WhqAin/`. PostgreSQL preserves the original SQL
role/database `odbctest`, DSN and TCP password semantics, including a required
wrong-password negative check. LDAP preserves the original Manager DN,
password, ports and certificate generator with a task-private MDB database;
the unchanged suite owns seeding. These templates are review material, not
product dependencies or working-service evidence. LDAP's original TLS option
handling may have the same missing-CA issue as FTP; that remains untested.

The registered `otp-test-controller` recheck passes in 21.88 seconds, with all
69 checks true. The maintained Emu Release build regenerates and reports
`ninja: no work to do`; no product binary or installation update is needed for
these harness changes. Other configurations remain unvalidated. The resumed
source audit rechecks all 6,838 retained original corpus inputs with zero byte
or executable-mode differences. Its expanded missing-path list contains 161
pre-existing paths: the earlier 155 application/emulator/system paths plus
EPMD's Makefile and five optional yielding-example Make/gitmetadata files.
The original full pin is still archived during preparation. Sixteen public
test presets remain, one per configuration. Candidate/reference VM hashes and
the selected SDK manifest hash remain identical to the Stage 2/7 inputs.

## Deferred work at the user-directed closure

These items remain open for a later pass. Stage 8 must retain actual failures,
skips and missing coverage; closing this checkpoint supplies no passing waiver.

| Deferred item | Evidence / work to resume |
| --- | --- |
| OpenSSH PTY service identity | Review a proper service UID/GID mapping or provisioned environment. Preserve caller identity, original PTY assertions and the established EPMD route. No namespace redesign or bypass was approved or implemented. |
| Tinyproxy fixed-path startup | Investigate exit 127 in the final native overlay; the extracted-path version probe does not replace this failure. |
| Native runtime-data closure | Complete active bindings for interpreted/native support data beyond the verified 238 artifacts and three closed package roots. |
| DNS, HTTP/proxy/nginx, Net-SNMP and terminal fixtures | Run actual original fixtures and verify protocol behavior, process/listener ownership, negative controls and cleanup. Tool presence/version checks are insufficient. |
| PostgreSQL/ODBC and LDAP | Execute the concrete proposal under `service-contract-proposal-WhqAin/`, including genuine authentication negatives and cleanup. Preserve the original suite; investigate its TLS handling without assuming a fix. |
| Genuine external endpoints | Supply the selected Unix Telnet endpoint and other original configuration prerequisites. Example hosts/credentials are not selections. |
| OS_Mon CPU utilization | Recheck on a genuinely quiescent host, preserving the original 1.5% guard for 22 logical processors and its deadlines. |
| Original FTPS coverage | Both original-runner reproductions skip group setup with missing CA options; zero FTPS cases passed. Preserve this unresolved coverage and review any proposed original-source change separately. |
| Historical participants/catalog | Actual OTP 27/28 provisioning remains explicitly deferred. Follow the original kerl provisioning contract later; supply real installed identities and the separate system daily release catalog. No impersonated runtime or empty catalog. |
| Manual checks | The 27 Debugger checks remain pending as directed. Original wx OpenGL manual checks and the unconditional Debugger skip do not become passing automated coverage. |
| Optional SSH image catalog | Preserve zero foreign-image coverage unless genuine images are selected later. No host Docker socket or invented image result. |
| Complete execution evidence | Stage 8 and later stages own complete canonical corpus, current configuration identities and reconciliation. Stage 7 bounded probes do not establish those results. |

The original review-stop receipt `resumed-stage7-review.json` remains immutable
historical evidence. It records the earlier incomplete stop, not this later
user-directed checkpoint closure. Stage 8 starts separately in
[its record](linux-amd64-stage8.md).

### Checklist retained from the review stop

1. Preserve original-runner FTPS evidence and deferred historical provisioning;
   no original-source/test patch is planned.
2. Review the SSH service-identity boundary before further harness rework.
   Preserve caller identity, original assertions and the established EPMD route.
   Finish native runtime-data bindings and actual fixture/service readiness;
   tool version checks and extracted binaries do not establish them.
3. Recheck the OS_Mon utilization prerequisite without changing its original
   threshold/deadline or adding a passing skip classification.
4. Complete owned selected native services and GUI/terminal readiness from the
   corrected 39-component inventory. Record real external endpoint/catalog
   handoffs explicitly. Optional Docker images are not fabricated or inferred.
5. Refresh affected available outputs and bind final preparation/readiness
   evidence to one unchanged set of selected source, SDK, dependencies and
   controller identities. Keep the 27 manual Debugger checks pending as directed.
6. Historical instruction at that stop: report before continuing. Superseded on
   2026-11-17 by the user's explicit closure and authorization to start Stage 8.
