# SSL source assembly and initial TLS evidence

SSL 11.7 builds its 78 retained Erlang modules on Linux interpreter and JIT
configurations. The product contains thirteen application resources and 512
byte-identical BEAM artifacts between flavors, including thirteen external
preloads. No SSL implementation, public declaration or upstream test changed.

## Build boundary

The three SSL behaviour modules compile first. The upstream `VSN` macro comes
from `otp_versions.table`. Public Key is an explicit source-built dependency:
its code directory is passed to the compiler host, its retained headers are
staged in the ordinary application include directory, and its generated
`PKCS-FRAME.hrl` is available there before consumers compile. This preserves
normal `include_lib` resolution without borrowing SDK applications or private
VM headers. `build.term` records explicit application code dependencies.

SSL's retained Erlang sources and internal headers install in its versioned
`src/` directory, matching the upstream resource boundary used by unchanged
tests. Ordinary Crypto/OpenSSL support remains the existing public NIF
consumer. No shared-runtime or SDK changes were required.

## Acceptance

Both flavors pass product checks that start SSL through its dependencies,
create ephemeral test certificate chains, and perform mutually authenticated
TLS 1.2 and TLS 1.3 connections on both `inet` and `socket` networking backends.
The checks verify the negotiated version and peer certificate, exchange data
in both directions, close the connections and stop the application. They
repeat across three boots, including two restarts, after relocation and with
the original SDK/source/build trees unavailable.

Two probe setup errors were corrected: `gen_tcp` requires the backend selector
before all other transport options, and the reused 1024-bit test RSA key was
below SSL's unchanged minimum policy. The fixture now selects the backend first
and generates 2048-bit keys. Product policy and upstream assertions were not
relaxed. Diagnostic logs preserve both initial failures.

The complete unchanged suites pass on each flavor, with no failures or skips:

| Suite | Cases | Coverage |
| --- | ---: | --- |
| `ssl_rfc_5869_SUITE` | 7 | HKDF specification vectors |
| `ssl_cipher_SUITE` | 4 | Cipher decoding, padding and signing-algorithm logic |
| `tls_1_3_record_SUITE` | 4 | Record encoding, finished verification and handshake vectors |

The TLS record suite compiles the retained `ssl_test_lib.erl` and header;
all original input hashes are recorded by the installed-candidate harness.
These cases supplement actual loopback TLS; they do not certify all SSL,
DTLS, interoperability, certificate or release behavior.

## Evidence and remaining work

Source HEADs and installed SDK identities remain those in the
[ASN.1 record](asn1.md). The source/build/harness and documentation changes are
uncommitted. Full regression excluding the separately running 103-case ASN.1
suite, combined with the focused corrected-probe rerun, establishes twenty
passing checks per flavor. The remaining engine coverage gate reports 28
passed cases and three upstream skips. Completed upstream suites total 161
passed and three skips per flavor, excluding the unfinished full ASN.1 run.
The corrected [ASN.1 value oracle](asn1.md#pinned-upstream-comparison) passes;
it confirms upstream behavior rather than claiming that value-generation
limitation has been fixed.

Reproduce with the [build guide](build.md), selecting `initial-product`,
`isolated-product`, `asn1-value-generation` and the three suite names above via
CTest `-R` for focused checks. Disposable workspace logs are
`tmp/otp-ssl-build-{emu,jit}.log`, `tmp/otp-ssl-check-{emu,jit}.log`,
`tmp/otp-ssl-product-{emu,jit}.log` and `tmp/otp-ssl-diagnostic*.log`.
Build-local Common Test result records contain exact selections and input
hashes. Shared-runtime/playground/GLM acceptance remains prior matching-SDK
evidence and was not rerun for these OTP-only changes.

Broader SSL suites, external peers, DTLS, distributed TLS and complete
installation/application coverage remain required. Migration stage 4 and the
overall independent OTP objective remain in progress.
