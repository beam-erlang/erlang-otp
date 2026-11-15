# OTP tests

One Erlang wrapper prepares and checks the pinned OTP 29.0 tests on Linux,
macOS and Windows. The installed original `ct_run` executes the suites in its
own Erlang process. Preparation and assessment modules stay outside that
process. The path uses the installed candidate, original OTP commit
`550d7b7898706c7822362c42e7b93120c1d1f29a`, original Make targets, `ts:install`,
`ts:compile_datadirs`, and Common Test. There is no legacy runner fallback.
Native execution evidence is required separately on each platform and for
Emu/JIT × Release/Debug. Current registration alone proves none of those runs.

## CTest interfaces

| Interface | Scope |
| --- | --- |
| `ctest --preset <configuration>` | Routine distribution checks and controller self-checks |
| `otp-app-<application>` | Complete original main specification for one of the 35 applications |
| `otp-erts-emulator` | Complete ordered emulator specification in one controller VM |
| `otp-erts-system` | Complete system specification, including final cleanup |
| `otp-erts-epmd` | Supplemental original EPMD specification |
| `otp-erts-yielding-c-fun` | Unchanged original OTP ordinary shell regression driver |
| `otp-suite-<domain>-<suite>` | Independently selectable suite diagnostics |
| `otp-tests` build target | All 39 original OTP components, followed by report reconciliation |

There is one public test preset per build configuration. Shared preset policy
selects routine checks, prints failures, rejects an empty selection and uses
serial execution. Test selection does not add more preset families. Use CTest names/labels or the `otp-tests` target
for other selections. Adding `-L full` to the routine preset does not
remove that preset's exclusion of full test runs.

Common Test owns specifications, group expansion, repetitions and test
lifecycle. CMake registers names, arguments, dependencies and timeouts. Full
execution preserves the emulator's cross-suite state in one Erlang process;
individual-suite execution starts a fresh process. Individual-suite
`a_SUITE`/`z_SUITE` requests pair the original state holders
and cleanup cases in one CT invocation. Individual-suite reports never satisfy full
acceptance. Dynamic selection hooks that cannot be validated in individual-suite
preflight are rejected explicitly.

Before individual-suite metadata discovery, exported Common Test `ct_make`
helpers compile supporting modules with the released Emakefile options. Common
Test still owns module discovery and compilation; the adapter does not parse
Emakefiles. Helper compilation failures reject the selection before cases run.

## Select the candidate and inputs

Build and install the candidate using its supported preset first. Keep
experiments in workspace `tmp/`; do not repurpose a maintained preset directory
with task-specific options. An experimental configuration can test an existing
maintained installation by selecting `OTP_TEST_CANDIDATE` and
`OTP_TEST_CANDIDATE_BUILD` explicitly.

| CMake setting | Required selection |
| --- | --- |
| `OTP_TEST_CANDIDATE` | Installed OTP prefix; defaults to the installation prefix |
| `OTP_TEST_CANDIDATE_BUILD` | Matching build containing `sdk-selection.txt` |
| `BEAM_SDK_ROOT` | Exact installed public SDK selected by that receipt |
| `OTP_TEST_REFERENCE_GIT` | Local Git repository containing the exact original OTP pin |
| `OTP_TEST_CONFIGURED_SOURCE` | Matching configured original OTP tree |
| `OTP_TEST_WORK_ROOT` | Owned output below workspace `tmp/`, separate per job/configuration |
| `OTP_TEST_INPUTS` | Optional explicit input profile described below |
| `OTP_TEST_MAKE`, `OTP_TEST_GIT`, `OTP_TEST_TAR` | Selected native preparation tools |
| `OTP_TEST_CLANG`, `OTP_TEST_BASH` | Tools required by the ordinary yielding-C driver |
| `OTP_TEST_BWRAP`, `OTP_TEST_UNSHARE`, `OTP_TEST_IP` | Linux namespace launcher tools |

The C/C++ compiler, Java compiler, Perl and wx-config selections come from the
product configuration. Missing host tools or original configured inputs block
preparation; the controller does not synthesize another platform's build inputs.
The original OTP checkout's current HEAD is irrelevant: preparation archives the
exact pin into a fresh job directory and verifies the operational manifest.

Original `release_tests_spec` targets stage each domain and its test server.
The controller supplies the selected installed Erlang commands and the SDK's
recorded target. It copies normal generated Make inputs and the
installed public opcode header. Original Make generates Compiler/emulator and
Dialyzer suites and the released Emakefiles. No original OTP suite or recipe is
manually edited, and no SDK-private fixture package is consumed.
FTP receives original `MODULES` and `FTP_DATADIRS` Make-variable overrides to
include its unchanged property suite/tree, which its default release rule omits.
The original helper generates its compiler options and Emakefile entries.

## Register and select tests

`OTP_ENABLE_TEST_SUITES=ON` registers all 35 applications, four ERTS
components, a test-session setup test and reconciliation.
`OTP_ENABLE_ERTS_TESTS=ON` registers the four ERTS components independently when
the complete profile is disabled. Enabling both options registers each component
once. `OTP_ENABLE_INDIVIDUAL_SUITES=ON` additionally registers individual suite names.
All three options default to `OFF`.

For a configured experimental build, select its directory explicitly:

```sh
ctest --test-dir "$build_dir" -N -L '^full$'
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error \
  -R '^otp-app-eunit$'
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error \
  -R '^otp-erts-emulator$'
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error \
  -R '^otp-suite-compiler-andor_SUITE$'
cmake --build "$build_dir" --target otp-tests
```

Selecting one application automatically creates its session when required; it
does not automatically run the other components or reconcile a partial run.
The complete original OTP selection runs 39 components once and reconciles them
against the current session. Complete product acceptance also requires the
distribution checks. Individual-suite tests have separate `suite` labels;
they are excluded from the complete original OTP selection.

`otp-tests-prepare-<domain>` prepares one component without executing its
cases. `otp-tests-prepare` prepares all components; `otp-erts-prepare` and
`otp-erts-check` select the four ERTS components. Empty CTest selections fail.

For a group or individual case, use the same controller and arguments as the
registered CTest command (`ctest --test-dir "$build_dir" -N -V -R …` displays
them), replacing selection arguments with:

```text
run --domain compiler --profile suite --suite andor_SUITE --group p --case t_case
```

`--suite`, `--group` and `--case` accept comma-separated names. Group/case
selection requires one suite. Unknown, duplicate or empty selections fail.
Direct invocations must use the candidate's own escript and an owned `HOME`
below workspace `tmp/` before starting the VM; CTest supplies this environment.
On Linux, retain the registered `otp_ct_linux.sh` launcher and its arguments
when changing a suite/group/case selection. Invoking the escript directly does
not supply the required Linux ownership envelope.
Run `otp_ct.escript --help` for the complete argument list.

## Explicit prerequisites and private services

Linux CTests use Bash, util-linux `unshare`/`nsenter`/`setpriv`, bubblewrap, iproute2 and
OpenSSH client/server/key tools. The host must permit the required user, PID,
mount, network, IPC and UTS namespaces. Missing capability fails execution;
the launcher does not change host security settings. It retains the invoking
UID/GID, exposes host inputs read-only, and makes only the owned job writable.
Procfs, runtime directories, temporary files, PTYs and SSH state are private.
An outer namespace owns detached descendants on normal exit and cancellation.

The Linux controller starts and stops a candidate EPMD inside that private
network, using the original default port 4369. `ERL_EPMD_PORT` is cleared before
startup: its native argument precedence would otherwise override original
suites' explicit alternate ports. The profile must leave `epmd_port` absent or
select 4369 on Linux. The controller verifies namespace admission, an empty
registry and shutdown. EPMD's original suite
uses its separate fixed ports and an owned real SSH peer on a second private
network. Host names resolve to loopback in the controller and the private
non-loopback controller address in that peer.

Other platforms still require a caller-owned nondefault EPMD supplied before
VM startup. Their lifecycle execution needs its later native pass.
The original `ct_run` starts with `-boot start_sasl`, error logging and
`maybe_expr`, using original configuration files and timetrap scaling. A
normally compiled event helper records the actual controller's root, node,
runtime configuration and startup facts. An explicit per-domain
configuration selection replaces the example configuration set. The controller
and its peers use the selected candidate and a controlled environment. Execution uses
local test paths. The original empty `ts_net_dir` and Common Test's local fallback
resolve the same paths; a nonempty network-mounted value blocks execution
until its execution envelope is supplied.

The current input-profile fields are:

```json
{
  "artifacts": {
    "selected-input": {"path": "/absolute/input", "sha256": "<64 lowercase hex digits>"}
  },
  "ct_config": {"application": ["/absolute/original-compatible.config"]},
  "proper": {"path": "/absolute/proper-VERSION", "tree_sha256": "<tree digest>"},
  "native_roots": [{"path": "/absolute/native-input-root", "tree_sha256": "<tree digest>"}],
  "executables": []
}
```

Artifacts and CT configuration files are hashed. Declare the complete external
input closure explicitly; a config filename does not identify every resource it
references. Unsupported profile fields fail rather than activating retired
adapters. `proper` is optional: its closed tree includes file bytes, directory
and file modes, and contained symlink targets. The digest is produced by
`otp_ct_support:input_tree/1` in the installed candidate. Its actual `.app`
version is recorded; directory and package labels do not override that value.
The controller rejects OTP module collisions, keeps candidate application roots,
and adds PropEr at the end of the code path for itself and candidate peers.
Combining PropEr with a configuration's explicit `otp_releases` program paths
is currently rejected: those historical launches retain candidate `ERL_AFLAGS`.
Native historical-root activation is still a readiness gap.

On Linux, `native_roots` supplies explicit native package resources at their
normal `/usr` and `/etc` locations through read-only overlays. Later roots have
priority; private hosts, account and SSH views retain their separate ownership.
Each root uses the same strict closed-tree digest, rejects VM/runtime payloads,
and must match the launcher's ordered `--native-root` arguments. Reconfigure
after changing that list. No package installer or maintainer script runs.
Record any selected runtime-view omissions or extra native dependency bytes;
an extracted archive with dangling links is not a complete closed input.

GUI domains use a private authenticated Xvfb session. Other domains receive no
ambient display. This supplies automated display capability, without enabling
the original manual GUI cases or inventing their outcomes.
Each CT execution receives a fresh disposable copy of the complete installed
candidate. Bytes, modes, directory entries and literal symlink targets must
match before cases run, and no file is hardlinked back to the producer. This
permits original fixture writes, such as temporary applications under `lib/`
and Emacs `.elc` output. The maintained installation stays read-only and is
checked again afterward. Added, changed and deleted copy contents are retained
separately; changed/deleted original inputs remain nonpassing pending review.

Current Linux readiness is incomplete. The namespace's single UID/GID mapping
supports real SSH authentication but does not support OpenSSH PTY ownership and
login records. A service-identity design review is required before claiming
those SSH cases ready. PostgreSQL/LDAP service readiness, complete native tool
data bindings and genuine external endpoint selections also remain unproven.

`executables` lists artifact keys that name supported native commands, such as
`vsftpd` or `netstat`. Each must have a hashed `artifacts` record. Only that
selected file is exposed through the owned tool view; its whole containing
directory is not added to PATH. Runtime command names and aliases resolving to
them are rejected. This executable-view activation currently supports POSIX
hosts; Windows selections fail explicitly pending its native pass.
Selecting a tool or application does not provision a service. See the remaining
[prerequisite families](test-prerequisites.md).

Linux lifecycle admission requires the verified process/network envelope.
Installed public Erl_Interface `src/eidefs.mk` is supplied for applicable native
fixtures. Historical releases, complete service provisioning,
graphical sessions and other active dependencies must be supplied and validated
before the corresponding full acceptance can pass.

Under the agreed Linux scope, `mtx_SUITE`, `ethread_SUITE` and `erl_print_SUITE`
are intentionally excluded in all four configurations. Their omissions remain
recorded, and explicit requests for these suites fail. On other platforms, full
emulator/system preparation and these suite selections remain blocked. Their
coverage is deferred pending a separate decision. The SDK supplies no private
fixture package or private VM interfaces for these tests.

## Evidence and implementation

Each job retains its command transcripts, source and SDK identities, released
input inventories, native preparation, exact CT selection, raw events, results
and skip classifications. The original controller's native `totals.info`, raw
events, runtime snapshots and command exit must agree. Completion requires
both final test and logging events; exit zero alone cannot accept a run.
Preparation binds the original source and released
suite/recipe closures and checks them again after CT. Generated suite omissions
and modified inputs cannot be accepted as a smaller successful corpus.

Passing requires complete consistent CT statistics, actual selected outcomes,
and no unresolved failures, prerequisite gaps, unknown skips or callback
failures. Reconciliation rechecks raw evidence and preparation receipts. It
rejects missing/duplicate components, individual-suite reports, mixed identities/sessions
and reports from an earlier session. It collects the current candidate, SDK,
adapter, tool and declared-input identities through the same verifier used by
execution, and compares that epoch and the current session before publishing.
Manual reconciliation therefore needs the same common candidate/build/SDK/tool
arguments as execution; the registered CTest command supplies them.
A matching original OTP failure is review
evidence, not an exemption.

| File in `tests/otp/support/` | Responsibility |
| --- | --- |
| `otp_ct.escript` | Public preparation/assessment entry point, arguments and job/session lifecycle |
| `otp_ct_prepare.erl` | Original Make/test-server preparation and input integrity |
| `otp_ct_evidence.erl` | Native CT selections, original `ct_run` invocation, outcomes and reconciliation |
| `otp_ct_yielding.erl` | Unchanged supplemental yielding-C shell driver |
| `otp_ct_support.erl` | File, command, environment, verified installation-copy and identity operations |
| `otp_ct_event.erl` | Raw Common Test events and actual controller startup/completion facts |

The controller's project-owned regression probe lives beside the tests in
`tests/otp/otp_ct_evidence_probe.erl`. The operational `manifest.json`
retains the pinned inventory and source-bound classifications; it is not an
alternate Make or Common Test interpreter. Development records are not runner
inputs. The superseded Python runner, fixture translator, service adapters,
pilot implementation and their implementation-specific checks have been
retired. Python remains in independent product build-tree, installation,
relocation, isolation and SDK checks, outside this preparation/execution path.
