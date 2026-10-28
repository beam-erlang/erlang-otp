# Fixture and platform preparation

[Upstream testing](upstream-testing.md) describes runner selection and results;
[compatibility](compatibility.md) defines the required scope. Preparation builds
or generates original inputs using the selected product. It must preserve
behavioral assertions, fixture data, deadlines and original run structure.
[OTPTesting.cmake](../cmake/OTPTesting.cmake) and
[check_upstream.py](../tools/check_upstream.py) own the executable selections.
Descriptions here do not claim that a selection has passed.

## Installed inputs and lifecycle

Build-mode checks install into private work before relocation. An explicit
installed selection requires complete external provenance and private work;
isolated tests receive private copies rather than writable or hardlinked shared
fixtures. Candidate and reference fixtures use identical preparation. Verify
actual product, helper and native image origins, sanitize user/loader state and
hide original SDK/source/build paths during isolated execution. Permission,
network or namespace denial is a failed prerequisite, not a pass or silent skip.

The product probe exercises application/native/helper behavior across initial
startup and restarts. Independent startup/preparation fixtures retain copied
inputs, partial acquisition, allocation/descriptor failure, cancellation,
caller-state preservation, recovery, 22 sticky preloads and real cleanup.
Preparation success cannot substitute for later execution or restart checks.
Standard release fixtures generate ordinary releases and execute them unchanged
after isolated relocation; no custom launch overlay may supply missing assets.

Upstream native fixtures must compile against installed common/versioned ERTS
headers and installed commands. Product smoke fixtures are distinct from complete
NIF/driver suite acquisition. Dirty-NIF preparation keeps the original native
libraries, peer programs, data and callbacks required by the complete suite.

## Paths, peers and resources

Private HOME/cookies and EPMD isolate candidate peers; verify each peer's root
and runtime identity. Use the hostname expected by the original fixture helpers,
rather than changing it to `localhost` when cleanup constructs node names from
the machine hostname. Native observations must measure descriptors, threads,
children and loaded images; inspection errors must fail, never become fabricated
empty results.

Some unchanged suites convert filenames to atoms. Use a short work root through
`OTP_SHORT_TEST_ROOT` or `--work-root`; shortening generated fixture paths does
not change Erlang's atom limit. EUnit's command fixture splits the program path
on spaces, so it uses an ordinary path while independent product acceptance
retains spaces/Unicode coverage. Preserve both boundaries.

OS Monitor helper-kill suites need private process namespaces on Linux, neutral
launcher names, the SASL boot profile and candidate named peers where required.
Do not let the suite's process-name search target unrelated host processes.
Darwin's unchanged global kill suites require an explicitly disposable worker;
`OTP_DISPOSABLE_WORKER` is not appropriate on an interactive machine. A busy-host
CPU measurement skip retains its raw reason and strict nonpassing result.

Large primitive-file and RAM-file cases keep their real disk/memory workloads
and original deadlines. Run resource-heavy cases serially when needed. The full
RAM-file suite intentionally leaves a marker that skips `large_file_heavy`;
`upstream-ram_file-heavy` runs that case unchanged in fresh state. Its separate
result supplements the full-suite skip rather than rewriting it.

## External services

Test server packages are explicit dependencies, never product assets or system
services to modify. Select system-installed tools or verified cached packages;
record versions/URLs/checksums with reusable inputs. Keep mutable databases,
configuration, logs and accounts inside private disposable test work.

| Workload | Selection | Preparation |
| --- | --- | --- |
| FTP | `OTP_FTP_SERVER` / `--ftp-server` | vsftpd executable; private process/network/filesystem namespaces, account mapping and fixed suite ports. |
| ELDAP | `OTP_LDAP_ROOT` / `--ldap-root` | OpenLDAP executable, MDB backend, libslapi and core schema; private MDB state and generated TLS credentials. |
| ODBC | `OTP_POSTGRES_ROOT` / `--postgres-root` | PostgreSQL/psqlODBC package root, private cluster/DSN and explicit system driver manager. |

FTP TLS setup supplies a generated test CA while preserving peer verification.
ELDAP supplies explicit CA options for LDAPS and STARTTLS; apply `sslopts` only
to SSL connections because supplying that option enables TLS in `eldap:open`.
Keep plain and STARTTLS discovery modes distinct. Only the external server may
receive dependency loader overrides; candidate commands and children must not.

ODBC uses private Linux 64-bit DSNs and `psqlodbcw.so`; trust authentication and
fixed port 5432 stay inside the private network namespace. Preserve independent
transaction/parameter/rollback and helper-loss probes. Unicode setup queries
`SQLGetInfo(SQL_DRIVER_VER)` on the actual driver instead of guessing from word
size; unknown drivers retain the original guard. SQL Server-only cases retain
their own restrictions and raw skips. No shared host database is a test fixture.

## Application acquisition

ASN.1 application/syntax/error/full suites require their original schemas,
headers and helper modules. The generated personnel-record oracle in
`tools/fixtures/asn1-value-reference.json` is a test input, not an expendable run
report. Product schema-ordered round trips remain independent of that pinned
upstream limitation. Crypto engine setup translates the case name `dsa` to the
public capability atom `dss`; it does not remove DSA or ECDSA behavioral checks.

Public Key/SSL fixtures retain certificate generation, retained vectors and
positive/negative verification. SSH preserves original key callbacks, parallel
groups, transport headers and suite data. Fixture-only local endpoint trust must
not change ordinary product verification defaults.

Xmerl preparation includes original test helpers, grammars and data. The SAX
stream suite uses a fixed loopback port and must run serially across flavors.
EUnit compiles its original helpers/examples against installed public headers
and parse transforms. EDoc/EEP-48 need selected source/inspection metadata and a
short path where their unchanged filename-to-atom behavior requires it.

Diameter fixtures retain dictionary/parser helpers and complete core/preload
abstract forms for Xref. Runtime Tools needs original native tracer fixtures;
monitor actual trace-client termination after `dbg:stop`. SNMP preserves its
`snmp_test_data` define/shared data and compiles imported MIB fixtures before
augmentation cases. Megaco includes the original versioned message helpers;
retain native-scanner quoted-text behavior rather than imposing another
scanner's semantics.

Java fixtures compile against the installed JAR using explicitly selected Java
and Javac. Private `user.home`/cookie configuration and candidate peers remain
necessary. JAR content review uses the same JDK as the original reference;
matching source does not erase compiler-version differences. Dialyzer fixtures
use candidate-built PLTs, retain the standard base applications and preserve
original large-merge deadlines. Scheduler selection may supply the workload's
needed parallelism; changing deadlines or suppressing warnings is not preparation.

Observer/Etop/TTB/crash-dump and Reltool selections remain explicitly bounded in
the runner. Headless selections do not cover GUI cases or unselected terminal
and old-release peers. Crash-dump peers require supported typed allocator-tagging
options. Reltool fixture compilation follows its original Makefile targets;
other fixture applications retain original uncompiled contents and empty data
directories. Do not synthesize replacement application behavior.

## ET and sendfile

ET collector `write` expects an existing file to rename to `.OLD`. The product
probe separately checks append/create, write/clear with exact previous bytes,
and public `start_trace_client(Collector, event_file, File)` reload. Monitor
collector/reader shutdown and disk-log restoration. Native taints persist across
`init:restart`: check an empty initial state and exact later retention rather
than clearing the list to make a restart assertion pass.

Sendfile supports `--inet-backend inet` and `socket`, standalone close/crash
cases via repeated `--case`, paired order and the complete suite. Repetitions use
fresh VMs/work roots and real descriptor observations. `--strace` marks a
separate diagnostic run; traced timing must not replace uninstrumented outcomes.
Partial-send errors, queued TCP notifications and saved-file-handle cleanup are
separate behaviors. No message draining, errno remapping or forced descriptor
closure belongs in test preparation.

## Graphical and native platform checks

Linux wx checks select Xvfb through `OTP_XVFB`/`--xvfb` and run with TCP disabled
inside private user/process/network/filesystem namespaces. Use a private display
socket, no inherited user display/session bus, explicit Mesa software rendering
and only copied fixtures/product/system dependencies. Set `OTP_ENABLE_WX_TESTS=ON`
to execute the registered wx tests. Disabled entries are untested.

The independent wx probe edits widgets, observes events, exercises OpenGL and
attempts repeated boots. Upstream interactive OpenGL guards require genuine
attendance and configuration; do not invent user presence. Automated software
rendering does not establish WebView, hardware rendering or manual desktop use.
GUI-dependent Debugger, ET, Observer and Reltool behavior needs its own acceptance.

Darwin observations use libproc/Mach/dyld rather than ELF/proc assumptions.
Seatbelt must deny original SDK/build/source and generated-release assembly
inputs to descendants without an unsandboxed retry. Preserve real unlinked-image
origins, terminal modes/control characters/stream flags, bounded preparation
failure and resource restoration. Test-only allocation interposition supplies
faults without adding a product hook. Stop owned EPMD/process groups before
removing payloads; never stop host services.

Windows `otp-windows-development` compiles an external NIF with installed headers,
executes ordinary services/commands, relocates a spaces/Unicode installation and
repeats with sanitized paths. It is a development smoke check, not filesystem
isolation or full upstream qualification. The owned interactive GUI fixture is
invoked through installed commands as described in [build instructions](build.md).
Run one application at a time, exercise a control and close normally; retain
renderer/resource assertions and attendance requirements for the OpenGL probe.
