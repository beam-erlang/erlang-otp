# OTP launchers and local distribution

OTP owns command parsing and launch policy. The retained Unix `erl` script invokes
upstream `erlexec`, which processes environment flags, argument files, detached
startup and EPMD launch policy before executing the public-API host. The shared
VM is the installed SDK's `libbeam`, linked statically into the OTP host.

## Layout and ownership

- `bin/erl` and `erts-17.0/bin/erl` are generated from the retained upstream shell
  template, substituting the ERTS version, emulator name and installation prefix.
  Its existing root discovery supports relocation.
- `erts-17.0/bin/erlexec` is compiled from the retained C source. Its only source
  adaptation removes unused `erl_driver.h` and `erl_misc_utils.h` includes. Its
  command-policy implementation remains unchanged.
- `erts-17.0/bin/beam.smp` is the OTP-owned public-API host. It links the
  selected installed SDK's `BEAM::RuntimeStatic`; the installed OTP tree contains
  no shared VM, SDK archive or additional VM implementation.
- The host consumes the launcher's separated emulator arguments as typed public
  options, then supplies the remaining init arguments without synthesizing a
  duplicate root, bindir or program name. Argument-file/environment parsing is
  not duplicated in this host.
- Unchanged C sources supply `erlc`, `escript`, `ct_run`, `erl_call` and EPMD.
  EPMD is ordinary OTP command support, compiled independently with socket and
  platform probes and the standalone formatter. It has no VM link dependency.
- OTP owns its resolver and the standard command/resource layout. The installed
  child-setup helper is the matching executable selected through the public SDK
  artifact inventory. Product assembly uses no private SDK paths.

`start` and `start_erl` preserve literal relocated paths, including spaces and
Unicode. `RUN_ERL_PIPE_DIR` optionally selects an existing private FIFO directory
for `start`; include its trailing slash. Without it, the traditional `/tmp/`
selection remains. This permits independent embedded-system instances and keeps
acceptance FIFOs inside the test's own scratch. Command acceptance exercises the
real `start` → `run_erl` → `start_erl` → `erlexec` → host chain, observes the actual
host/helper images, and requires orderly shutdown before removing their inputs.
On Darwin this chain runs under Seatbelt with its original assembly inputs denied.


`-version` reports the selected OTP ERTS version. Supported VM switches still
translate to the public runtime's typed options. Unimplemented VM policies fail
explicitly; retaining the upstream command parser does not implement every
emulator option. Additional public mechanisms belong in BEAM, while flag parsing
and OTP defaults belong here.

## Legacy kernel-poll option

The independent OTP distribution accepts `+K true`, `+K false` and joined forms
such as `+Ktrue` for compatibility with pinned OTP 29.0. The host consumes the
value without changing polling or emitting a warning. As upstream does, it also
accepts arbitrary strings and empty split values; this is not a boolean control.
The launcher rejects a missing value before application startup. Arguments after
`-extra`, including literal `+K` strings, remain application inputs.

This compatibility handling belongs to the OTP startup host. It adds no option
to the modern BEAM/Erlang `beam` command or the public SDK. The existing
`otp-command-policy` check owns argument variations and relocated command
acceptance; its isolated start-chain fixture also supplies `+Ktrue`.

### 2026-10-26 validation

The [machine-readable evidence](command-kernel-poll-validation.json) records
source HEADs, the implementation/test diff and file hashes, exact SDK identities,
commands and bounded failure diagnostics. The production change is confined to
the OTP host; upstream launcher, suite and fixture sources remain unchanged.
The selected SDKs are built from BEAM `5fb78576ff346196f6cfad0584fd43864e72b13e`,
with package source `86ac0e595867f2c66e1d8fc637179db05e0f150e`; OTP is
`5c9858415b3101e7a42e15ee35f17f4e91e21d0b` plus the recorded local changes.
The identical implementation/test files are also captured by
`4d2f099ac05f87266d8c403c46e1e3ecd64a58d5`.

| Check | `linux-emu` | `linux-jit` |
| --- | --- | --- |
| Installed/relocated command policy, including isolated `+Ktrue` start chain | Passed | Passed |
| Complete BEAM CTest inventory | 36 passed, 1 capability skip | 36 passed, 1 capability skip |
| Installed-OTP VM Common Test selection | 4 suites, 22 cases passed | 4 suites, 22 cases passed |
| Complete registered OTP CTest inventory | 90 passed, 15 nonpassing, 7 wx deferred | 90 passed, 15 nonpassing, 7 wx deferred |

The fourteen focused kernel-poll startup checks also pass against a verified
pinned original JIT installation. They cover unchanged polling/init arguments,
split/joined and arbitrary/empty values, repeated flags, adjacent options and
missing-value rejection. Existing command checks additionally cover environment
flags, nested argument files and literal `-extra` inputs.

EMU's nonpassing gates comprise seven strict skip-coverage gates (RAM-file,
Crypto engine, EEP-48, CPU Monitor, JInterface and SNMP compiler/configuration),
one socket-sendfile gate with its two retained case failures, and seven
prerequisite-blocked gates: the missing matching original EMU installation, FTP,
LDAP and four ODBC suites. External server packages are neither installed nor
cached; those cases are untested. The full original JIT tree is independently verified and copied
for comparison. These results do not establish full OTP compatibility or release
qualification; wx GUI coverage remains deferred.

JIT's installed-tree comparison also remains failed on the
[pre-existing native-library permission gap](assembly-fidelity.md#fresh-build-mode-gap-2026-10-26).
The pre-fix source baseline reproduces that gap; it is independent of `+K`.
Its remaining nonpassing gates match EMU's seven skip-coverage gates, one
socket-sendfile gate and six external-server prerequisite gates. The JIT
comparison's subsequent native-capability checks and other platforms are
untested. No unexpected regression is attributed to the command correction.

Fresh Release/Ninja builds and private installations use
`tmp/otp-kernel-poll`, with one flavor at a time and explicitly verified cached
Flex 2.6.4 and Rebar3 3.27.0. The initial storage estimate is below 20 GiB with
73 GiB available. EMU runs serially; JIT uses at most two independent private
fixtures concurrently. All producer builds, private SDKs, copied references and
disposable installations are removed after recording compact evidence. No
task-owned process remains. Stable installations are unchanged.

## Historical Linux command checkpoint

Both `linux-emu` and `linux-jit` built, installed and passed all ten OTP CTests.
The expanded `otp-command-policy` check additionally passed native `ct_run`
acceptance on each flavor after its noninteractive invocation was corrected.
The nine existing checks continue to cover public imports/headers, source-built
compiler execution, native/restart behavior, terminal shell, filesystem-isolated
relocation and three unchanged upstream suites.

The new command check installs then relocates a prefix containing spaces and
verifies:

- OTP version output, ordering of `ERL_AFLAGS`/command arguments/`ERL_FLAGS`/
  `ERL_ZFLAGS`, nested quoted argument files, comments and literal `-extra` input.
- Detached startup executing its requested expression and halting.
- A private foreground EPMD on an independently selected loopback port, named
  candidate-node registration, and an `erl_call` EI request returning a computed
  result from that node.
- A second candidate node discovering and pinging the first, performing RPC,
  checking its installation root and requesting orderly shutdown. The peer uses
  the launcher's default EPMD-start path against the test-owned daemon.
- The native `ct_run` front end compiling no suite code itself and executing the
  complete unchanged Base64 suite in noninteractive mode: 19 successful cases,
  zero failures and zero user/automatic skips. Its original test hook is retained.

Local distribution uses explicit `@localhost` names matching the private
loopback-only EPMD. An earlier fixture used the machine hostname, which resolved
to a different interface and could not contact that listener; fixing the fixture
address did not change runtime or EI code. Owned daemon/node processes are cleaned
up. This is candidate-to-candidate local interoperability, not certification
against an upstream OTP peer or a multi-host network.

The source HEADs remain BEAM `795e3ac7fa39433cce26bc979bd8889da324d52a` and OTP
`72a1beb074a9fb8481d652418db80255c2962008`, with uncommitted implementation and
acceptance changes. The [SDK identities and shared-runtime acceptance](../../dev-documents/otp-ownership-cutover.md#historical-command-hosting)
are unchanged for this launcher iteration. Product-source differences from the
reviewed deletion checkpoint remain the seven preload adaptations plus the two
unused include removals in `erlexec.c`. Upstream suites, fixtures, bootstrap and
other retained implementation sources remain unchanged.

Reproduce with the [build guide](build.md) and `ctest --preset linux-emu` or
`linux-jit`. The command check alone is `ctest --preset linux-emu -R '^otp-command-policy$'`.
Each build keeps command transcripts, EPMD/node output, native Common Test logs,
SDK identity and exact result summaries under `checks/commands/<run>/`.
Disposable aggregate logs are workspace `tmp/otp-launcher-final-{emu,jit}.log`
and `tmp/otp-native-ct-{emu,jit}.log`.

Remaining work includes additional VM options through public mechanisms,
ordinary native-extension development/fixture support, full installation
resources and licensing, more command modes and applications, external OTP
interoperability and release upgrades. The three upstream suites and local RPC
checks do not close those compatibility dimensions.
