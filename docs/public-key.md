# Tools and Public Key assembly

The source build includes Tools 4.2 and Public Key 1.21 on Linux interpreter
and JIT configurations. Tools contributes sixteen modules, its generated Xref
parser and the retained stylesheet. Public Key contributes eleven retained
Erlang modules and 31 modules generated from its ASN.1 schemas. The assembled
product has twelve application resources and 434 BEAM artifacts, including
thirteen external preloads; all are byte-identical between flavors.

## Generation and ownership

Tools uses the source-built Parsetools generator for `xref_parser.yrl`.
Public Key uses the source-built ASN.1 compiler through the selected installed
BEAM compiler host. `cmake/OTPPublicKey.cmake` records the explicit schema
inventory and the upstream generation options: BER, DER, `noobj`, `asn1config`
and deterministic output. Schema imports and configuration files come from
retained product inputs. No private VM build interface is involved.

Generated Erlang sources and headers stay under `build/<preset>/generated`.
The information-object-only `KEMAlgorithmInformation-2023` schema does not emit
a header; the build does not declare a nonexistent output. `PKCS-FRAME.hrl`
installs with the public headers, and the retained schema/configuration inputs
install under the versioned application's `asn1/` directory.

The retained `convert.escript` regenerates Diffie-Hellman constants through the
installed host. Its output matches the retained `pubkey_moduli.hrl` byte for
byte. A byte-identical build copy of `pubkey_ssh.erl` ensures Erlang's local
include search consumes this generated header. Retained source files are never
rewritten. The upstream `app_vsn` attribute is applied to the eleven handwritten
modules through the compiler's `sys_pre_attributes` transform.

## Product evidence

Both flavors pass the relocated and filesystem-isolated product checks with:

- Application startup through ASN.1 and Crypto dependencies and installed
  Public Key module-origin checks.
- RSA key generation, SHA-256 signing, positive and negative verification.
- Public-key DER encoding/decoding and private-key PEM encoding/decoding.
- Repetition across three boots, including two OTP restarts.

Existing native, shell, compiler, command, networking and ASN.1 product checks
remain enabled. No runtime changes were needed; the SDK identities and source
HEADs remain those recorded in [ASN.1 evidence](asn1.md). Build-local selection
records identify the exact dependency artifacts. Shared-runtime/playground/GLM
acceptance remains the preceding matching-SDK evidence, not a new execution.

The complete unchanged Public Key `pbe_SUITE` (5 cases) and
`pubkey_policy_tree_SUITE` (10 cases) pass on both flavors without failures or
skips. Password encryption includes the retained 16,777,216-iteration PBKDF2
vector. Sixteen of eighteen regression checks pass per flavor; the two existing
coverage gates below remain nonpassing. The larger 103-case ASN.1 suite runs
separately and is not included in that total. See the
[upstream testing record](upstream-testing.md).
No suite assertions or fixtures were changed. The Crypto engine skips remain open. The later
[pinned-upstream comparison](asn1.md#pinned-upstream-comparison) resolves the
generated ASN.1 constant discrepancy as matching upstream behavior.

Reproduce through the [build guide](build.md). Disposable workspace build logs
are `tmp/otp-public-key-build-{emu,jit}.log`; regression logs are
`tmp/otp-public-key-check-{emu,jit}.log`. All changes remain uncommitted at this
checkpoint. This assembly does not certify all Tools profiling facilities,
Public Key certificate/OCSP/policy behavior, operating-system trust stores or
the full Linux application set. Runtime Tools, SSL and other dependent
applications remain subsequent work.
