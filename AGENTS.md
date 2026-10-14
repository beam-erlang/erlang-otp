# Erlang/OTP distribution work

## Local Linux completion

The 2026-10-27 [completion direction](../dev-documents/otp-compatibility.md#objective)
reopens wx and dependent GUI acceptance on the current Linux x86-64 stack,
authorizes evidenced narrow upstream bug/test-setup corrections, and permits
exact named upstream limitations with supplemental checks and visible raw skips.
It supersedes earlier deferral/paused-authorization text below. Qualification
remains incomplete; no signal/lifetime workaround, assertion weakening,
publication, commit or other-platform expansion is implied. Follow the
[bounded implementation sequence](../dev-documents/otp-completion.md).

## Static SDK and faithful OTP assembly

The current implementation adds `BEAM::RuntimeStatic` alongside shared
`BEAM::Runtime`. OTP product/private hosts use the static target, embed thirteen
OTP-owned preloads and explicitly compose already-linked NIF/driver implementations.
The VM still embeds exactly nine core modules and owns no OTP native inventory.
Modern commands/components retain shared linkage. Native extensions must resolve
against one host runtime; mixed linkage and second-runtime mappings are rejected.

OTP must reproduce the pinned original installation tree, including paths, entry
types, modes and literal link targets for equivalent build features. It installs
no `libbeam.so`, development VM archive, startup wrapper libraries, `otp-runtime/`
directory or validation manifest. Standard external resources remain upstream
owned. Build/source/SDK provenance stays outside the installation. The custom
OTP C playground is retired; independent product fixtures own its preparation,
copied-input, recovery and lifecycle coverage. See the
[implementation evidence](../dev-documents/static-sdk-otp-runtime.md) for current
validation; the ownership checkpoint below is historical evidence and its former
shared-runtime placement is superseded. The current bounded assembly milestone
adds Observer and Reltool and completes the upstream installation shape through
ordinary playground examples. wx acceptance and release upgrades remain deferred.
Both flavors assemble all 35 applications. Matching-flavor installation-tree
equality, content review, allocator/crash-dump acceptance and the complete
playground matrix pass; see [assembly fidelity](docs/assembly-fidelity.md).
The ET event-file and restart-taint probe corrections now pass full relocated
and isolated product checks on both flavors. Socket sendfile reproduces the
same two failures on pinned original upstream; native correction requires an
explicit upstream-bug-fix decision. See [the comparison](docs/et-sendfile-comparison.md).
Preserve historical failures and deferred coverage.

## Ownership cutover checkpoint

`beam-erlang/src/otp/` is removed in the main checkout. BEAM's command now uses
modern boot exclusively; runtime-family selection/locking and OTP-specific boot,
acquisition and deployment adapters are removed. OTP selects its own terminal,
Zstandard and RAM-file artifacts through its host inventory. The ownership
migration and final interpreter/JIT validation are complete. BEAM passes all
21 tests per flavor; OTP completes all 101 entries per flavor with 79 passes,
seven deferred wx entries and 15 retained nonpassing gates. These results do not
establish full OTP compatibility. See [the cutover record](../dev-documents/otp-ownership-cutover.md) for implemented changes, acceptance
transfers and unresolved compatibility gaps. Older descriptions of selectable families,
static OTP registrations and duplicated installation assets below describe the
pre-cutover baseline and must not be restored as policy.


Ownership migration edits belong directly in this main checkout. Keep fresh
builds, isolated installations and logs under workspace `tmp/`; do not create
separate source worktrees. Existing validation snapshots stay fixed until their
running jobs finish. Integration does not establish passing acceptance or
complete a migration milestone. See the workspace runtime strategy for the
full goal and validation requirements.

This repository owns the OTP distribution assembled around the installed
BEAM/Erlang SDK. `libbeam` is its sole VM implementation. The
[runtime strategy](../dev-documents/runtime-evolution-strategy.md) defines the
ownership boundary and the migration from the current implementation.

OTP owns all OTP-specific source, startup modules and policy, native services,
drivers, helpers, commands and build machinery. The shared VM owns exactly nine
embedded Erlang modules and their VM implementation: `erts_code_purger`, `erlang`,
`erts_internal`, `erts_literal_area_collector`, `erts_trace_cleaner`,
`erts_dirty_process_signal_handler`, `atomics`, `counters` and `persistent_term`.
Modern BEAM libraries and components, including the seven base modules, belong
outside `libbeam`; their ownership does not make them VM core.

Normal generation and compilation use private OTP-owned seed and source-built
hosts linked only to `BEAM::RuntimeStatic`. `bootstrap/` supplies 277
source-attested modules; mandatory deterministic reproduction precedes ordinary
application compilation. The BEAM command, its private compiler and bundled
applications are not build inputs. The product and private hosts share the
OTP-owned linked-native and embedded-preload inventories. Preparation copies
composition inputs without starting a VM. Real upstream external dependencies,
including the child helper, retain failure/recovery acceptance.

Historical shared-runtime acquisition, loose-native deployment and bootstrap
results belong to the cutover record. Their former paths and counts are evidence,
not current installation requirements. Current validation is recorded in the
[static SDK evidence](../dev-documents/static-sdk-otp-runtime.md); passing ownership
or layout checks does not resolve the retained compatibility failures.

Keep OTP-owned builds and hosts on the public SDK. Private-header or
private-symbol dependencies require a supported generic mechanism or an OTP-owned
replacement; they do not justify leaving OTP implementations in BEAM. Runtime
family selectors and APIs are removed. Preserve generic composition, native
admission and lifecycle mechanisms: OTP supplies thirteen additional preloads,
retaining its 22-module preload, sticky and restart semantics while the VM owns
only nine. Preserve the public-boundary, native-origin, copied-input, failure and
restart acceptance independently of the retired custom OTP playground host.

Temporary development documents now belong in the workspace's
[`../dev-documents/`](../dev-documents/README.md). The existing build and evidence
documents in this repository's `docs/` remain in place pending a separate review;
upstream documentation is also retained. The
[OTP compatibility record](../dev-documents/otp-compatibility.md)
defines the objective, completion gates and paused implementation checkpoint.
Documentation moves do not change acceptance requirements or resolve recorded
failures and deferrals.

The initial target is every Linux-capable OTP 29.0 application on interpreter
and JIT configurations. The current CMake project establishes installed dependency discovery, a public
SDK probe, source compilation of kernel, STDLIB, compiler, Parsetools, SASL,
Common Test, Syntax Tools, Crypto, ASN.1, Tools, Public Key, SSL, Runtime Tools, Mnesia, Inets, EUnit, Xmerl, FTP, TFTP, SSH, EDoc, ELDAP, Diameter, OS Monitor, JInterface, Dialyzer, SNMP, Megaco, ODBC, wx and Debugger, standalone Erlang Interface libraries, and an
independently installed OTP-owned host. The unchanged Base64, math, queue and complete dirty-NIF
suites run through installed candidate commands; see [upstream testing](docs/upstream-testing.md). Upstream launchers now own argument/environment parsing and detached/EPMD
policy; the public-API host lives under the ERTS command directory. See
[command evidence](docs/commands.md). Further VM options, resources and product
compatibility remain in progress. Public NIF/driver headers are deployed by the
SDK into standard OTP include directories; unchanged native fixtures run in
relocated and isolated product acceptance. See [native extension evidence](docs/native-extensions.md)
and [the build guide](docs/build.md).

- Select an installed SDK explicitly. Do not add sibling source/build paths,
  copy VM-private headers, import private symbols, or use an external Erlang
  runtime as a build or execution fallback.
- Crypto links system OpenSSL through its normal CMake package and the public
  NIF SDK. Preserve its retained sources and record third-party capabilities.
  The engine suite currently has three upstream skips; its strict coverage
  gate remains nonpassing. See [Crypto evidence](docs/crypto.md).
- ASN.1 generators and its ordinary NIF are OTP-owned. Preserve the explicit
  product inventory and source inputs. Generated PER/UPER example constants
  match a recorded pinned-upstream limitation; see [ASN.1 evidence](docs/asn1.md).
- FTP interoperability uses an explicitly selected external vsftpd inside private
  process/network namespaces. Its strict gate currently has ten upstream setup
  skips; see [file-transfer evidence](docs/file-transfer.md).
- EDoc consumes the standard ERTS application tree, including SDK-deployed
  embedded-core bytecode. Its four upstream EEP-48 skips remain a coverage gap;
  see [EDoc evidence](docs/edoc.md).
- ELDAP interoperability uses an explicitly selected OpenLDAP package tree
  in private namespaces. Its unchanged suite has TLS setup skips; preserve
  verification defaults and assertions. See [ELDAP evidence](docs/eldap.md).
- Runtime Tools builds its IP/file tracing drivers through `BEAM::Driver` and
  its dynamic-tracing NIF through `BEAM::NIF`. Discover the compiled VM backend
  through the public native capability query; do not force tracing off or copy
  private configuration headers. Validate the new ownership separately from
  historical SDK-built evidence. See [native ownership](docs/runtime-tools.md).
- Diameter owns dictionary generation and `diameterc`. Preserve normal compiler
  metadata in OTP applications and the upstream assembly/abstract-code pairing
  for `prim_eval`; VM-owned core inspection artifacts come from the SDK. See
  [Diameter assembly](docs/diameter.md).
- Tools and Public Key retain source-owned parser/schema generation. Generated
  artifacts stay in the build tree; see [assembly evidence](docs/public-key.md).
- OS Monitor owns its Linux CPU/memory helper executables. Run unchanged
  helper-kill suites in private process namespaces with neutral launcher names;
  the CPU idle-measurement skip remains explicit. See [OS Monitor evidence](docs/os-monitor.md).
- Dialyzer owns its Erlang analysis modules and the retained `dialyzer`/`typer`
  command front ends. Preserve version defines and unchanged suite inputs;
  build PLTs with the installed candidate. See [Dialyzer assembly](docs/dialyzer.md).
- SNMP owns MIB/parser/codec generation and agent/manager resources. Preserve
  unchanged suite inputs and explicit compiler-fixture preparation. Its retained
  Perl converter has a focused portability correction; see [SNMP assembly](docs/snmp.md).
- Megaco generates its parsers/codecs from retained grammars and schemas. Build
  both Flex scanners against `BEAM::Driver`, with explicit Flex dependency
  selection; see [Megaco assembly](docs/megaco.md).
- ODBC owns its EI-linked port program and system driver-manager dependency.
  Database acceptance uses an explicitly selected disposable PostgreSQL cluster;
  see [ODBC assembly](docs/odbc.md).
- wx builds its retained bindings and ordinary NIFs through the public SDK.
  The private PCRE collision is corrected in BEAM and both-flavor runtime,
  playground and GLM acceptance passes. wx work and acceptance are explicitly
  deferred; retain strict checks disabled by default with `OTP_ENABLE_WX_TESTS`.
  The pinned upstream runtime reproduces native reload and GTK child-process
  failures. Continue other applications and non-GUI behavior; GUI coverage that
  requires wx remains deferred. See [wx evidence](docs/wx.md). Do not silently
  change process signal policy, native lifetimes or upstream assertions.
- Debugger builds retained interpreter and GUI modules; validate headless
  interpretation and breakpoints independently of deferred wx. Install product
  sources so protected-application checks work after relocation and isolation.
  See [Debugger evidence](docs/debugger.md).
- Keep product adaptations focused on the public SDK and distribution boundary.
  Preserve upstream suite sources, assertions and fixtures unless the maintainer
  authorizes a specific test change. Replacement build/test orchestration may
  compile and generate existing inputs without changing their assertions.
- Keep build outputs under ignored `build/<preset>/` and installs under
  `install/<preset>/`. Do not commit generated outputs or scratch evidence.
- Preserve the explicit bootstrap inventory, source attestation and mandatory
  seed-to-source-built compiler verification. Candidate refresh writes only to
  the build tree; review candidates before changing checked seeds or hashes.
  Use only the selected `libbeam` for execution. Do not make
  the build depend on a bundled OTP environment in BEAM, a sibling build tree
  or a second VM; seeds do not substitute for source-built product applications.
- Application versions come from `OTP_VERSION` and `otp_versions.table`.
  Retained compiler generators must match the selected VM's bytecode format.
  Native builds and deployment must follow supported public SDK contracts.
  Report an unresolved boundary instead of inventing a private dependency.

Keep commits and permanent documentation independent of interactive sessions.
Preserve license and copyright notices. The upstream tracker is a separate
read-only reference, not a source directory for this build.

## Preview SDK qualification

The [release strategy](../dev-documents/distribution-release-strategy.md) records
upstream-based product identities and public compatibility policy. OTP retains
its upstream OTP version plus a distribution revision; BEAM adopts its upstream
ERTS version plus a BEAM distribution revision, currently `17.0-r1-preview.1`.
Keep actual SDK/evidence versions intact; earlier identity validation does not
qualify a new SDK. OTP retains its own `OTP_VERSION` and `otp_versions.table`
for application assembly after their removal from the modern repository.
The [sync process](../dev-documents/Upstream-Sync-Process.md) defines OTP
`maint-<OTP-major>` branches from product checkpoints, paired with the selected
BEAM `maint-<ERTS-major>` generation. The initial pairing is OTP `maint-29` and
BEAM `maint-17`; names do not replace exact SDK qualification or declare support.
Changes to experimental modern reporting do not remove OTP's own reporting and
compatibility requirements. Preserve the private matching-build native contract.

The BEAM preview pipeline consumes this repository at an explicit source pin and
builds against its acquired, verified SDK archive. Expected BEAM version, build
identity and flavor are independent of OTP_VERSION. Preserve upstream reporting,
all owning acceptance and external provenance. Playground is not a release input
or gate. Existing nonpassing OTP checks block promotion; this release work does
not authorize their correction or reopen wx.

## Test output cleanup

Follow the workspace [validation storage lifecycle](../AGENTS.md#validation-storage-lifecycle).
Runners clean disposable payloads on success, failure and catchable interruption,
keeping bounded diagnostics and result identities. `BEAM_TEST_KEEP_WORK=1` is an
explicit debugging-only retention override; record its size and remove it after
investigation. Existing development installations and selected input prefixes
are never cleanup targets.

Select system tools or verified reusable packages from workspace `downloads/`,
following the workspace cache policy. Flex is a build dependency. vsftpd,
OpenLDAP and PostgreSQL/psqlODBC are external interoperability-test inputs;
private server instances and their mutable data remain inside disposable test
directories. Never store the reusable dependency packages in `tmp/`.
