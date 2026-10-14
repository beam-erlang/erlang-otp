# Upstream test execution

The [local qualification inventory](local-qualification.md) records specification
discovery and per-case evidence for the expanded completion work. The historical
bounded selections below retain their stated source/SDK scope; they do not
establish execution of the complete inventory.

The candidate installation runs selected complete OTP 29.0 suites through its
source-built Common Test application. Suite sources, assertions, fixtures and
test hooks remain unchanged. CMake and the OTP-owned Python harness prepare
isolated build outputs and invoke installed candidate commands.

For focused ET, primitive-file and sendfile comparison, the harness also accepts
`--prefix`, `--provenance` and `--work-root` instead of `--build`. It verifies the
complete selected installation before executing identical fixture preparation
and assertions on candidate and original reference. Sendfile supports explicit
single/paired case selection and separately labelled syscall diagnostics. See
the [comparison procedure and results](et-sendfile-comparison.md).

## Disposable output

The owned runners remove copied installations, compiled fixtures and private
server data after each run, including failures and catchable interruption.
They retain bounded text diagnostics and `cleanup.json` alongside CTest output:
at most 8 MiB per run and 1 MiB per file. Oversized structured records are omitted,
not truncated. `BEAM_TEST_KEEP_WORK=1` explicitly retains a run for debugging;
remove it once the investigation finishes. Existing selected installations are
never removed. Reusable dependency packages belong in workspace `downloads/`,
with explicit version/hash records; they are not per-test data.

The source-layout checkpoint used focused validation; no new OTP runtime or
cross-product compatibility result is claimed. See the
[relocation record](../../dev-documents/source-map.md#relocation-validation).

## Build and execution boundary

The initial testing checkpoint added Common Test 1.31 (47 modules) and Syntax
Tools 4.1 (9 modules), alongside kernel, STDLIB, compiler, Parsetools, SASL and
Erlang Interface. Its 352 generated BEAM files, including thirteen external
preloads, were byte-identical between interpreter and JIT builds. Later
application and suite checkpoints are recorded below.

Common Test compilation uses retained Common Test, SNMP and Xmerl headers.
That header dependency does not imply runtime acceptance of the SNMP/Xmerl
integrations. Syntax Tools uses the upstream nine-module product inventory;
`merl_tests.erl` remains a test input rather than a shipped application module.
Its `merl_transform` bootstrap compiles once with `MERL_NO_TRANSFORM`, then uses
that source-built seed and the newly compiled syntax modules to compile the
final transform. The seed stays in the generated build directory. No external
runtime or SDK copy of these applications supplies product code.

`cmake/OTPTesting.cmake` registers one CTest per selected upstream suite.
`tools/check_upstream.py` installs the candidate into a fresh prefix containing
spaces, copies the unchanged suite and required upstream helper sources into
its work directory, records SHA-256 hashes, and compiles them with installed
`erlc`. It then calls installed `erl` and `ct:run_test/1`, checking application
origins and the exact pass/fail/skip tuple. `auto_compile=false` delegates fixture
compilation to the replacement harness; it does not change suite execution.

The original `ts_install_cth` hook is compiled and used. These selected suites
have no native data-directory build requirement. No legacy `variables` file is
supplied, and the hook follows its existing no-file path. This does not establish
CMake preparation for suites with drivers, NIFs or other generated fixtures.

Commands run from the work directory with isolated HOME and candidate-first
PATH, with runtime/loader overrides removed. Each run keeps compiler output,
Common Test HTML/logs, the raw result and an SDK/input provenance record under
`build/<preset>/checks/upstream/<suite>-<run>/`. Timeout handling terminates the
owned process group. The separate `isolated-product` test covers execution with
the original SDK/source/build trees unavailable; these suite runs do not yet
repeat that namespace isolation.

## Accepted checkpoint

Both Linux x86-64 flavors passed the following complete suites:

| Suite | Interpreter | JIT | Scope |
| --- | --- | --- | --- |
| `base64_SUITE` | 19 passed, 0 failed, 0 skipped | 19 passed, 0 failed, 0 skipped | Encoding/decoding modes, errors, roundtrips and doctests |
| `math_SUITE` | 4 passed, 0 failed, 0 skipped | 4 passed, 0 failed, 0 skipped | Constants, rounding, error information and doctests |
| `queue_SUITE` | 7 passed, 0 failed, 0 skipped | 7 passed, 0 failed, 0 skipped | Queue operations, I/O, errors and doctests |

The full OTP CTest run passed all nine checks per flavor: six dependency/product
checks plus these three upstream suites. An earlier Base64 run passed 18 cases
and failed its doctest because Syntax Tools was absent. Adding the required
application resolved that build-assembly failure; no suite change or skip was
introduced.

Runtime HEAD was `795e3ac7fa39433cce26bc979bd8889da324d52a`; OTP HEAD was
`72a1beb074a9fb8481d652418db80255c2962008`, with uncommitted source-build,
public-host, command, test-orchestration and documentation changes. Both SDK
identities and runtime hashes are recorded in the
[command-hosting checkpoint](../../dev-documents/otp-ownership-cutover.md#historical-command-hosting).
Those artifacts were unchanged for this suite iteration. The original source
pin is `550d7b7898706c7822362c42e7b93120c1d1f29a` (OTP 29.0).

Input hashes are identical on both flavors:

| Input | SHA-256 |
| --- | --- |
| `lib/stdlib/test/base64_SUITE.erl` | `39182d8dcf47fc8163bce30ac9a75ceff407ac80d2ae91e412df059af71677ad` |
| `lib/stdlib/test/math_SUITE.erl` | `6267014d9fd6df426411b15b6af921cc788e15039b30c2f508756df119a5d4ac` |
| `lib/stdlib/test/queue_SUITE.erl` | `0a86e490dd538f9270d771f71af4c2a4cd5939ebd090199dd0197238b9d4780e` |
| `lib/stdlib/test/error_info_lib.erl` | `eac1dbbd36801cff352d357ff29e050ab2a599a07b6baccaa0ffa4e5c5e2fcb5` |
| `lib/common_test/test_server/ts_install_cth.erl` | `72ffadc4c6e67cbaf44e5f5afc5bd9a4aebbcdbc8f8e3a5081e5d8843bd8497a` |

Reproduce using the [build guide](build.md), then run all OTP checks with
`ctest --preset linux-emu` and `ctest --preset linux-jit`. For just the registered
upstream suites, use `ctest --test-dir build/linux-emu -L upstream --output-on-failure`
and the corresponding JIT directory. Disposable aggregate logs are workspace
`tmp/otp-upstream-ctest-{emu,jit}.log`; the table and provenance above are the
durable result record.

The remaining upstream application and ERTS suites have not run. Native fixture
construction, peer-node startup, further test dependencies, complete application
assembly and release/interoperability acceptance remain required. Thirty cases
per flavor establish a usable initial harness, not full OTP compatibility.

The subsequent [command checkpoint](commands.md) adds upstream launcher policy,
local EPMD/node execution and native `ct_run`. It repeats the unchanged Base64
suite through that native front end and brings the OTP CTest inventory to ten
passing checks per flavor. Broader native-fixture and suite work remains pending.

## Complete dirty NIF suite

The native fixture recipe in `tools/fixtures/native/CMakeLists.txt` builds the
retained dirty-NIF suite's seven NIF libraries and echo driver against the
candidate installation's public headers. The harness copies all nine native
source inputs unchanged, compiles the complete suite plus its unchanged
`literal_area_collector_test` helper and `ts_install_cth` hook using installed
`erlc`, and runs its entire `all/0` and group selection. No cases are selected
out or assertions replaced.

| Flavor | Suite | Passed | Failed | User/automatic skips |
| --- | --- | ---: | ---: | --- |
| Interpreter | `dirty_nif_SUITE` | 35 | 0 | 0 / 0 |
| JIT | `dirty_nif_SUITE` | 35 | 0 | 0 / 0 |

Coverage includes dirty native execution and exceptions, scheduler exit,
process termination, heap/process/tracing behavior, code purge and literal
collection, port lookup, and normal/dirty scheduler halt callbacks including
old/new native code. This is the complete dirty-NIF suite, not the separate
larger `nif_SUITE` or all driver suites.

A private foreground EPMD uses an ephemeral port and binds loopback plus the
local hostname's IPv4 address, allowing upstream peers to retain their normal
hostname behavior. The parent and peers execute the candidate's installed
commands. A preflight uses upstream `peer:start_link` and verifies the peer's
installation root and loaded candidate `libbeam.so` before running the suite.
Scheduler defaults are supplied through `ERL_AFLAGS` as
`+S2:2 +SDcpu2:2 +SDio2`; test-specific explicit switches still override them.
The harness records these settings and stops its own EPMD after execution.

Two preparation failures were corrected without product or suite changes:
initial peer preflight lacked its explicit cookie, and the first complete runs
passed 33 cases but failed two because `literal_area_collector_test` had not
been compiled. Including that retained helper produced 35/35 on both flavors.
The complete Base64, math and queue suites were also rerun successfully through
the extended harness. The current four-suite selection totals 65 cases per
flavor with no skips; the OTP CTest inventory now contains eleven checks.
Existing product checks retain their preceding acceptance evidence.

Reproduce with `ctest --preset linux-emu -R '^upstream-dirty_nif_SUITE$'
--output-on-failure` and the corresponding JIT preset, or use `-L upstream`
for all four registered suites. Build-local `checks/upstream/dirty_nif_SUITE-*/`
contains the full execution log, Common Test HTML/logs, result term and
`result.json` with all twelve original input hashes, eight native output names,
SDK identity and scheduler settings. The harness additionally writes
`preparation.json` before suite execution so failed attempts retain provenance.
Disposable aggregate logs are workspace `tmp/otp-dirty-{emu,jit}-3.log`;
regression logs are `tmp/otp-native-harness-regression-{emu,jit}.log`.

The SDKs and source HEADs are unchanged from the
[native extension checkpoint](native-extensions.md#artifact-and-source-provenance).
Only OTP test orchestration, fixture build rules and documentation changed in
this iteration; shared-runtime acceptance was not rerun. All twelve input
hashes match the original import `9f719f9235cde79a8b58f4360eed70200d35b966`.
The suite hash is
`e11456d9f0e961b2cdca3e71ea3a00f1e416e9c6bdbd6e34d88e8312b9efcaf1`;
the literal-collector helper hash is
`24bc1bd39313e6739274fe9aa6240df9657bd15afc68b562dbf861bafbb3abf5`.

Broader suite preparation and full Common Test optional functionality remain
unfinished. Its declared runtime dependencies still include unbuilt applications
such as Crypto, Runtime Tools, Tools, SSH, SNMP and Xmerl. Those dependencies
remain part of complete Linux application assembly; successful use of the
current Common Test selection does not remove them from the objective.

The subsequent [Crypto checkpoint](crypto.md) adds the full unchanged engine
suite: 28 passed and three explicit upstream user skips per flavor. Its strict
coverage gate remains nonpassing; no assertion is relaxed. The four earlier
suites still pass all 65 cases per flavor. Current totals and skip explanations
belong to that later record rather than implying all registered checks are green.

## ASN.1 application and syntax suites

The complete unchanged `asn1_app_SUITE` (5 cases) and `syntax_SUITE` (12 cases)
pass on both flavors, without failures or skips. The same installed-candidate
harness compiles each original suite and hook and requires its exact result.
The seven registered upstream suites now total 110 passed and three Crypto
engine user skips per flavor. A separate generated-value check fails for
PER/UPER and is not counted as an upstream suite. The [ASN.1 record](asn1.md)
separates passing codec behavior from that open discrepancy.

## Expanded ASN.1 and Public Key coverage

Tools 4.2 supplies Xref for the full ASN.1 suite. The harness now compiles suite
helpers with debug information and places the Common Test hook in a separate
code directory, preserving the ASN.1 suite's own unused-export checks. It copies
the retained `External.hrl`, all ASN.1 Erlang helpers and the full shared corpus;
531 upstream inputs are recorded for the unchanged 103-case `asn1_SUITE`.
Its default peer is checked against the installed candidate before execution.
Both complete runs passed all 103 cases without failures or skips. They used
the preceding native-header SDK identities recorded in [ASN.1 evidence](asn1.md),
not the later tracing SDK. Disposable execution logs are
`tmp/otp-asn1-expanded-{emu,jit}.log` and build-local Common Test logs.

The complete unchanged `error_SUITE` passes all 21 cases per flavor. Its first
run failed `imports_exports` because the harness put shared ASN.1 data one
directory too high. CT's trailing data-directory separator affects the suite's
parent-directory calculation. Restoring the original sibling relationship
resolved that preparation failure without changing sources or assertions.
The corrected run records 436 input hashes; disposable logs are
`tmp/otp-asn1-errors-{emu,jit}.log`.

Source-built Public Key adds the complete unchanged `pbe_SUITE` (5 cases) and
`pubkey_policy_tree_SUITE` (10 cases), all passing without skips on both flavors.
The former includes the full 16,777,216-iteration PBKDF2 vector, with no reduced
work factor. All eleven PBE inputs and the two policy-suite/hook inputs remain
unchanged. These suites exercise installed candidate commands, generated Public
Key code, the Crypto NIF and system OpenSSL. See [assembly evidence](public-key.md).

The historical eighteen-check regression run excluding the then-running full ASN.1
suite finished with sixteen passing checks per flavor. The generated-value gate
then failed for PER/UPER; the engine gate reported 28 passed and three user
skips. Completed upstream suites then totaled 146 passed and three user skips per
flavor, excluding the full ASN.1 run at that checkpoint. Logs are
`tmp/otp-public-key-check-{emu,jit}.log`; the installed SDK identities remain
unchanged from the [ASN.1 checkpoint](asn1.md). This is not full upstream-suite
or product certification.

## SSL and pinned-upstream generated values

The complete unchanged `ssl_rfc_5869_SUITE` (7), `ssl_cipher_SUITE` (4) and
`tls_1_3_record_SUITE` (4) pass on both flavors, with no failures or skips.
The record suite uses the retained SSL test helper and header, and all suites
compile against installed product resources. Product checks additionally
exercise actual authenticated TLS 1.2/1.3 over both networking backends after
relocation, isolation and restart; see [SSL evidence](ssl.md).

The prior ASN.1 generated-value round-trip expectation exceeded the pinned
upstream behavior: the original autoconf/make release reproduces the exact
PER/UPER error and byte-identical generated sources and headers. The own
compatibility check now verifies those exact outputs, BER success and the
specific upstream error. Both candidates pass; no upstream assertion or source
changed. The [reference comparison](asn1.md#pinned-upstream-comparison) records
the archive and all hashes; the reference executable was never a candidate
build tool or acceptance runtime.

At the SSL checkpoint, twenty checks passed per flavor when combining the
twenty-one-check regression run (excluding the then-running full ASN.1 suite) with focused corrected-probe
reruns. The engine gate remains nonpassing with three user skips. Completed
upstream totals were 161 passed and three skips per flavor at that checkpoint.
The subsequently completed ASN.1 suite adds 103 passing cases per flavor. This supersedes the earlier generated-value
gate failure while retaining its observed upstream limitation.


## Runtime Tools and debugger coverage

The complete unchanged `runtime_tools_SUITE` (3) and `dbg_SUITE` (22) pass on
both flavors without failures or skips. The debugger's ordinary native fixture
builds against installed product headers, and its peers execute the installed
candidate. Short harness paths preserve the suite's filename-to-atom limit;
no test sources or assertions are modified. See the
[Runtime Tools record](runtime-tools.md) for the initial preparation failure,
SDK identities, native ownership and corrected full-suite evidence.

With the tracing SDK, the 23-check regression excluding ASN.1 plus focused
corrections yields 22 passing checks and the existing nonpassing engine gate
per flavor. Completed upstream suites in that selection total 186 passed and
three user skips. The 103-case ASN.1 suite separately passed on the preceding
SDK. These results do not certify all upstream suites or full product behavior.

## Mnesia installation and Inets coverage

The unchanged Mnesia installation sub-suite (3 cases), `inets_SUITE` (6),
`http_format_SUITE` (18) and `httpc_cookie_SUITE` (10) pass on both flavors
without failures or skips. This does not cover the full Mnesia suite hierarchy.
The harness supplies its existing two-node hook and a consistent cookie in
private HOME; the [database/HTTP record](database-http.md) documents the initial
peer-authentication failure and corrected reruns. No upstream test edits were
needed. The 27-check regression excluding full ASN.1 plus focused reruns yields
26 passes and the existing nonpassing engine gate per flavor; upstream totals
are 223 passed and three skips on the tracing SDK. The separate 103-case ASN.1
results retain their preceding SDK provenance.

## EUnit and Xmerl coverage

The unchanged EUnit suite (15), Xmerl SAX suite (12), SAX stream suite (4),
main Xmerl suite (46) and XML Schema suite (85) pass on both flavors, without
failures or skips. The harness preserves EUnit's helper/example layout and
executes stream tests serially across flavors because of their fixed port.
The Schema suite initially lacked its retained comparison helper; the corrected
full reruns pass. See [preparation and provenance](xml-unit-testing.md).

The regular 29-check regression passes 28 checks per flavor. Combined with the
three separately run XML selections, 31 checks pass and the existing Crypto
engine gate remains nonpassing. Current-SDK upstream totals are 385 passed
and three user skips per flavor; full ASN.1's 103-case results remain separately
recorded on the preceding SDK. Broader XML conformance corpora and full product
compatibility remain unproven.

## FTP and TFTP coverage

The complete unchanged FTP response suite (12) and TFTP suite (9) pass on both
flavors without skips. The complete FTP interoperability suite reports
`{74,0,{4,6}}` against explicitly selected vsftpd: nine TLS setup skips and one
following cleanup skip. Its exact-84 gate remains nonpassing. The
[file-transfer record](file-transfer.md) identifies missing certificate options
in retained test setup, external-server provenance and private namespace
containment. No assertions, product verification defaults or fixtures change.
Previously accepted suites were not repeated for byte-identical older modules;
the full application and compatibility scope remains open.

## SSH basic coverage

The complete unchanged `ssh_basic_SUITE` passes all 49 cases on interpreter and
JIT, without failures or skips. Its original parallel groups and event hook
remain active; 38 unchanged suite/helper/header/data inputs are recorded. See
[SSH evidence](ssh.md) for installed authentication, command and SFTP checks,
provenance and remaining suite/interoperability scope. Earlier Crypto engine
and FTP/TLS setup gaps remain nonpassing gates.

## EDoc and EEP-48 coverage

The complete unchanged EDoc suite passes ten cases per flavor. EEP-48 reports
40 passes, no failures and four explicit upstream unsupported-case skips; the
exact-44 gate remains nonpassing. The harness shortens its output directory to
respect existing filename-to-atom handling, without altering suite contents.
EDoc acceptance requires the standard ERTS application directory and SDK-owned
core inspection files; see [EDoc evidence](edoc.md) for provenance, initial
failures and installation corrections.

## ELDAP interoperability

The unchanged complete `eldap_basic_SUITE` reports `{56,0,{30,30}}` on both
flavors against an explicitly selected scratch OpenLDAP package. IPv4 and IPv6
connection groups run. LDAPS discovery and STARTTLS setup omit trusted CA
options under the retained SSL defaults; their 60 skips remain incomplete
coverage. An independent product probe verifies authentication, CRUD, LDAPS and
STARTTLS with explicit CA trust before the suite starts. Server and candidate
execution use private process/network namespaces without host service changes;
see [ELDAP evidence](eldap.md). Suite sources and assertions remain unchanged.

## Diameter and inspection metadata

Six complete unchanged Diameter suites pass on both flavors: application (7),
compiler (5), codec (5), configuration (2), synchronization (1) and registry (1).
All 21 cases pass without skips. Initial application-suite failures exposed
missing compiler options, core inspection metadata and the upstream
`prim_eval` abstract-code generation step. Corrections belong to the OTP build
and BEAM-owned artifacts; no upstream assertions changed. The final application
suite and relocated/isolated product checks pass after the focused correction.
See [Diameter evidence](diameter.md) for exact SDK identities, initial failures,
regression coverage and remaining transport/interoperability work.

## Linux OS Monitor

The complete Linux selections cover application metadata (2 cases), CPU (5),
disk (9) and memory (7). Both flavors report 22 passed, no failures and one
CPU utilization user skip because host load exceeds the unchanged suite's
idle threshold. The strict CPU gate remains incomplete. Installed SASL boot,
private process namespaces, neutral launch arguments and candidate peer setup
supply the required test environment without editing suite assertions.
See [OS Monitor evidence](os-monitor.md) for preparation corrections, helper
termination checks, exact results and the Linux exclusion of `os_sup_SUITE`.

## Java interoperability

The unchanged `jinterface_SUITE` and `nc_SUITE` use the selected JDK and installed
JAR with private cookies and EPMD. Test fixtures are compiled from hashed
retained inputs. Both flavors report 55 passed, zero failed and two upstream
unimplemented-case skips. Execution uses the relocated product with source and
SDK trees hidden. The strict node-suite gate remains nonpassing; see
[JInterface evidence](jinterface.md).

## Dialyzer and Typer

Eight complete unchanged suites cover 119 passing cases per flavor without
skips: application/PLT resources, parallel utility behavior, classic and
incremental PLTs, diagnostics, Typer, abstract forms and configuration. Tests
compile retained helpers and create PLTs through the installed candidate, with
private HOME/cookies/EPMD and source/SDK isolation. The interpreter's initial
two-scheduler merge case hit its 180-second timetrap; a focused retry with eight
schedulers passes, preserving that deadline and every assertion. JIT passes
both scheduler selections. See [Dialyzer evidence](dialyzer.md) for the exact
selection, initial failure, final results and outstanding generated/property
suites. No VM or retained product-source changes were required.

## SNMP

Four complete unchanged suite selections produce 35 passes, zero failures and
four explicit upstream unimplemented-case skips per flavor. Application and PDU
suites pass completely; compiler and configuration strict gates remain
nonpassing. Preparation supplies the original compile-time data-directory
macro, copied shared MIB inputs and the source-built `Test2.bin` fixture without
changing suite assertions. Execution uses the relocated candidate under
filesystem isolation. See [SNMP evidence](snmp.md) for the final combined
results, corrected initial build inventory, converter adaptations and remaining
agent/manager/interoperability coverage.

## Megaco

Eight complete unchanged suites cover application resources, native Flex
scanners, termination IDs, SDP and protocol-version 1–3 codecs. Both flavors
pass all 517 cases without failures or skips, using relocated installations,
private cookies/EPMD and filesystem isolation. Initial failures exposed omitted
message-building helpers in test preparation; focused retries with those
unchanged helpers pass. No retained Megaco sources or upstream assertions were
modified. See [Megaco evidence](megaco.md) for the precise selection, artifact
provenance, corrected product probe and outstanding transport/gateway coverage.

## ODBC

All four complete Linux suite selections execute against an explicitly selected,
disposable PostgreSQL 18.6 database and psqlODBC 17.00.0007 driver in private
namespaces. Both flavors report 91 passes, zero failures and 17 user skips.
Startup and connection suites pass completely; query and data-type gates remain
nonpassing because their retained PostgreSQL/type/resource/Unicode predicates
skip cases. The modern driver's capabilities are not inferred from those guards.
The initial native-helper connection failure was a missing CMake IPv6 probe;
the rebuilt helper passes with unchanged product sources and test inputs.
See [ODBC evidence](odbc.md) for exact results, dependency provenance, isolation,
both networking backends and repeated-restart product checks.
