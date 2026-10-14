# FTP and TFTP assembly

## Current local completion evidence (2026-10-27)

The complete 84-case FTP selection passes without failures or skips on candidate
and pinned original OTP 29.0, independently on interpreter and JIT. The narrow
test-setup correction supplies the generated CA while retaining `verify_peer`,
and includes localhost, the fixture hostname and loopback IP addresses in the
server certificate. Behavioral assertions and SSL defaults are unchanged.

The [service evidence](evidence/otp-completion-20261027/services.json.gz) retains
before/after results, exact source adaptations and dependency/installation
identities. vsftpd is selected from the verified reusable workspace cache;
private server state and product copies are removed after execution. The earlier
74-pass/10-skip results below remain historical. TFTP was not rerun as part of
this focused FTP setup correction; wider qualification remains open.

## Historical assembly checkpoint

FTP 1.2.5 builds six retained modules and TFTP 1.3 builds eight. The source build
preserves FTP's version define and orders TFTP behavior modules before their
consumers. Sources, internal headers, application resources and upgrade metadata
install under their versioned application directories. Both are ordinary Erlang
applications using the existing public-SDK host and networking/native contracts;
no VM, SDK or retained implementation change is required.

Both flavors contain twenty application resources, 667 application modules and
thirteen external preloads: 680 byte-identical BEAM files. All 653 preceding
application modules remain byte-identical to the EUnit/Xmerl checkpoint. The
[application inventory](application-coverage.md) retains all fifteen remaining
applications in scope.

## Product and upstream evidence

Relocated and filesystem-isolated product checks pass on interpreter and JIT.
They start and stop the FTP application, perform actual multi-block TFTP upload
and download against a private loopback daemon, check the disk contents and
repeat across two `init:restart` operations. The isolated product has no access
to the original SDK, source or build trees.

The complete unchanged `ftp_format_SUITE` passes all twelve cases, and the
complete unchanged `tftp_SUITE` passes all nine cases on both flavors without
skips. TFTP includes root-directory restrictions, connection reuse, both sides'
retransmission and a 67,107,840-byte transfer exercising block-number rollover.
The harness records three and four unchanged upstream inputs respectively.
Both product checks and both suites pass: four focused CTests per flavor.

The complete unchanged 84-case `ftp_SUITE` runs against vsftpd in private user,
process and network namespaces. It reports **74 passed, zero failed, four user
skips and six automatic skips** on each flavor: `{74,0,{4,6}}`. The strict exact-
coverage gate remains nonpassing; these skips are not counted as compatibility.
Five suite/helper/configuration inputs remain byte-identical to upstream.

Nine skipped cases follow the retained suite's TLS setup: `vsftpd_tls/0` supplies
cipher suites and a TLS version but no CA certificates. The unchanged SSL
`ssl_config:default_verify(client)` selects `verify_peer`; `opt_cacerts` rejects
that configuration with `{options,incompatible,[{verify,verify_peer},{cacerts,undefined}]}`.
Four implicit-TLS groups skip during setup; four explicit-TLS cases and
`error_datafail` automatically skip after setup errors. `clean_shutdown` then
skips because the preceding failed setup leaves a server inside the test
namespace. Namespace destruction contains its cleanup. These are retained
suite/setup inconsistencies, not evidence of changed VM semantics. Do not
silently disable verification, modify assertions or report this gate complete.
Any proposed upstream suite repair requires the maintainer's direction.

## Isolated external dependency

Configure the full interoperability test with an explicit executable:

```sh
cmake -S . -B build/linux-emu -DOTP_FTP_SERVER=/absolute/path/to/vsftpd
ctest --test-dir build/linux-emu --output-on-failure -R 'product|ftp'
```

Use the corresponding JIT directory for its run. Missing vsftpd or `bwrap`
produces an explicit preparation failure rather than omitting the test. The
server is a test dependency, never an OTP product asset or alternate runtime.
The suite's fixed port and process-list cleanup are confined to its namespaces.
All files outside the private test work directory are mounted read-only.

The validation host used the configured Ubuntu archive package
`vsftpd` 3.0.5-0.4 for amd64, downloaded and extracted into workspace scratch.
No package installation, system service or host account was created. Package
SHA-256 is `92d369be2bb868acfb5cf3c6c6e740166b00cd81d6b170d42a392114065a99a9`;
executable SHA-256 is `d87aa5d11ceb87977bfb82ea4e870ecf32aecee4851fbdd3b7736b0e317bb46b`.
The runtime dependencies resolve against host OpenSSL, PAM, libwrap and libc.
The first interpreter run could not find the package's normal anonymous `ftp`
account. The harness now supplies an account alias only in its read-only private
`/etc/passwd` mount, mapped to the launching user's IDs. Corrected interpreter
and JIT runs produce the exact bounded result above. Test sources and the
retained vsftpd configuration remain untouched.

## Provenance and limits

Source HEADs, installed SDK identities and `libbeam.so` hashes remain those in
the [Runtime Tools record](runtime-tools.md#revisions-and-acceptance-record),
with implementation uncommitted. No BEAM changes are made in this iteration;
shared-runtime/playground/GLM evidence carries forward from that checkpoint.
The previously accepted application outputs are unchanged; their full suites
were not rerun merely for these two added applications. The separate full ASN.1
result retains its earlier SDK provenance. The Crypto engine skip gap remains.

Both build/install operations pass. The initial build attempt rejected a reused
variable name in the new build-driver branch; correcting that local Erlang
binding resolved the build failure. Python syntax, unchanged retained-source
checks, local links and `git diff --check` pass. Disposable logs are workspace
`tmp/otp-transfer-{configure,reconfigure,build,build-corrected,install,check,ftp}-{emu,jit}.log`
and `tmp/otp-transfer-ftp-corrected-emu.log`. Build-local upstream results record
source/SDK hashes, server identity and exact passed/skipped counts.

This evidence does not close FTP/TLS interoperability, all external-server
configurations, property-based FTP tests or the full OTP compatibility goal.
