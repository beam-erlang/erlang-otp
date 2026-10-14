# SSH assembly and installed execution

SSH 6.0 builds all 43 retained product modules. Its eight behavior modules
compile before their consumers, with `ssh_dbg` first. Source-built Public Key
is an explicit build dependency for code and generated public headers. Versioned
application resources, upgrade metadata, source files and internal headers are
installed together. No VM, SDK, native component or retained SSH implementation
changes are required.

Both flavors contain twenty-one application resources, 710 application modules
and thirteen external preloads: 723 byte-identical BEAM files. All 667 preceding
application modules remain byte-identical to the FTP/TFTP checkpoint. The
[full application inventory](application-coverage.md) retains remaining work.

## Installed product checks

Both interpreter and JIT pass relocated and filesystem-isolated product checks.
The candidate generates a temporary RSA host-key file, starts its SSH daemon on
a private loopback endpoint, authenticates a client with test credentials,
executes a command, checks output and exit status, and uploads/downloads a file
through SFTP. It verifies disk contents and closes client, channels, daemon and
application dependencies before repeating across two `init:restart` operations.
The probe accepts only its local test endpoint's generated host key without
saving it; this changes no product host-verification defaults.

The isolated variant cannot access original SDK, source or build directories.
The candidate's installed `libbeam` is its sole VM. These local checks do not
establish external OpenSSH interoperability or every SSH algorithm/profile.

## Upstream preparation

The complete retained `ssh_basic_SUITE` defines 49 cases and uses its original
parallel groups. The harness compiles the retained key callbacks, test CLI,
peer-address subsystem, common SSH helper and event hook, with the original
transport/test headers and full suite data. Neither sources, assertions, keys
nor fixtures are edited. The exact-49 coverage gate rejects failures and skips.

## Completed acceptance

Both complete basic-suite runs return `{49,0,{0,0}}`: all 49 cases pass without
failures or skips. Each records 38 unchanged suite/helper/header/data inputs.
The original parallel grouping and event hook remain enabled. Coverage includes
shell and command execution, compression, IPv4/IPv6 options, descriptor-based
daemon startup, key callbacks and host-key handling, and connection lifecycle
behavior. This is the basic suite, not all SSH suites or interoperability profiles.

All three focused CTests pass per flavor: relocated product, isolated product
and unchanged basic suite. Both build/install operations pass. Python syntax,
touched local links, retained-source preservation and `git diff --check` pass.
The eight earlier retained-file adaptations remain unchanged; no retained
application, suite, fixture or bootstrap source is modified by SSH assembly.

## Provenance and reproduction

Source HEADs and installed SDK identities remain those in the
[Runtime Tools record](runtime-tools.md#revisions-and-acceptance-record), with
implementation uncommitted. This iteration changes OTP build/probe/harness code
only. Shared-runtime/playground/GLM acceptance carries forward; preceding suite
results apply to their byte-identical application outputs and are not new runs.
Existing Crypto engine and FTP/TLS setup gaps remain explicit.

Use the [build guide](build.md), then run
`ctest --test-dir build/linux-emu --output-on-failure -R 'product|upstream-ssh_basic_SUITE'`
and the corresponding JIT command. Disposable logs are workspace
`tmp/otp-ssh-{configure,reconfigure,build,install,check}-{emu,jit}.log`.
Build-local upstream results record exact source hashes, selected SDK and case
outcomes. Full SSH compatibility remains incomplete.
