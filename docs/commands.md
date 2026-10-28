# OTP launchers and local distribution

OTP owns command parsing and launch policy. The retained Unix `erl` script
invokes upstream `erlexec`, which handles environment flags, argument files,
detached startup and EPMD launch policy before executing the public-API host.
The installed SDK's `libbeam` is linked statically into that host.

## Layout and responsibilities

`bin/erl` and `erts-<version>/bin/erl` come from the retained upstream template
with version, emulator and prefix substitution. Root discovery supports
relocation. `erlexec` is built from retained OTP source; its command policy is
not reimplemented in the runtime. The OTP host at `erts-<version>/bin/beam.smp`
translates separated emulator arguments into supported typed public SDK options
and passes remaining init arguments without synthesizing duplicate root/bindir/
program-name entries. The installation contains no shared VM or SDK archive.

OTP builds the retained `erlc`, `escript`, `ct_run`, `erl_call` and EPMD front
ends. EPMD uses system socket/platform interfaces without linking a VM. OTP owns
hostname resolution, standard resources and command layout; the matching child
helper is acquired through the verified public SDK inventory. Windows native
commands discover their installation through their own executable location.

`start`/`start_erl` preserve literal relocated paths, including spaces and Unicode.
`RUN_ERL_PIPE_DIR` selects an existing private FIFO directory for `start` and
must include its trailing slash; otherwise upstream's `/tmp/` selection applies.
The start-chain fixture executes `start → run_erl → start_erl → erlexec → host`,
observes actual host/helper images and requires orderly shutdown before cleanup.

## Arguments and VM options

The upstream launcher owns `ERL_AFLAGS`, command arguments, `ERL_FLAGS`,
`ERL_ZFLAGS`, nested quoted argument files and detached/EPMD behavior. Arguments
after `-extra` are literal application inputs. `-version` reports OTP's selected
ERTS version; SDK identity is a separate build/acceptance input.

Supported emulator options translate into typed public runtime values. Retaining
the original parser does not implement every upstream VM policy. Unsupported
controls fail explicitly; new generic mechanisms belong in the SDK while flag
parsing/defaults belong to OTP. See the retained
[erl command reference](../erts/doc/references/erl_cmd.md) for upstream semantics
and [compatibility](compatibility.md) for acceptance obligations.

The legacy `+K` option accepts split `+K true`/`+K false` and joined forms such
as `+Ktrue` for OTP 29 compatibility. The host consumes the value without changing
polling or warning. Upstream also accepts arbitrary strings and empty split
values; it is not a boolean control. Missing values fail in the launcher before
application startup. Literal `+K` arguments after `-extra` remain program inputs.
This handling adds no option to the modern BEAM command or public SDK.

## Command acceptance

```sh
ctest --preset linux-emu -R '^otp-command-policy$' --output-on-failure
ctest --preset linux-jit -R '^otp-command-policy$' --output-on-failure
```

The fixture covers argument/environment ordering, argument files, literal extra
arguments, detached startup, private foreground EPMD, node registration and real
EI requests. Candidate peers exercise discovery, ping/RPC and orderly shutdown.
The start chain is repeated under filesystem isolation with original inputs
unavailable; terminal behavior has its independent owning fixture. Windows uses
the native development fixture described in [build instructions](build.md).

Generated transcripts, identities and bounded diagnostics stay in ignored test
output or CI artifacts. A local peer or selected command probe cannot establish
external OTP interoperability, complete option coverage or release lifecycle
compatibility. [Qualification](local-qualification.md) reconciles command-control
observations against their source manual hashes and exact installed products.
