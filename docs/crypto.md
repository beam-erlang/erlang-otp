# Source-built Crypto application

## Local completion setup correction

The engine suite now translates the case-name token `dsa` to Crypto's public
capability atom `dss`. Both previously guarded DSA cases pass under their
unchanged assertions on candidate and pinned original JIT; a fresh candidate
interpreter run likewise records 30 passes and one user skip. The remaining
`get_pub_from_priv_key_ecdsa` case reports the retained implementation's exact
`ECDSA not supported` outcome. The strict gate remains nonpassing, with named
limitation evidence and supplemental checks still required. The declared
adaptation and source hashes are in `tools/upstream-test-adaptations.json`.
The 28-pass/three-skip result below is the historical initial assembly.

## Historical assembly checkpoint

The independent installation builds Crypto 5.9 from the retained OTP 29.0
sources. Its two Erlang modules and application/upgrade resources join the
shared `OTP_APPLICATIONS` inventory. `cmake/OTPCrypto.cmake` compiles the native
implementation with the installed `BEAM::NIF` interface target and
`OpenSSL::Crypto`. No Crypto product source or upstream test source is modified.
No BEAM VM or SDK change is needed for this ordinary extension.

For the tested shared OpenSSL configuration, installation contains `crypto.so`,
`crypto_callback.so` and `otp_test_engine.so` under `lib/crypto-5.9/priv/lib`.
The callback remains a separate library loaded by upstream Crypto policy.
The native libraries have no VM-private imports or SDK runtime search path.
`crypto.so` depends on system `libcrypto.so.3` and libc; third-party OpenSSL
remains an explicit operating-environment prerequisite, not a bundled second VM.

CMake finds OpenSSL normally and checks declaration/link support for
`CRYPTO_memcmp` and the engine interface. It refreshes those probes when
reconfigured. EVP DH/HMAC use upstream defaults; FIPS build support remains
disabled as in the upstream default configuration. The static OpenSSL branch
keeps the callback in the main NIF, following upstream ownership, but has not
been validated. Other OpenSSL versions, static linking and FIPS configurations
are not certified by this checkpoint.

## Validated installation

Both Linux flavors build with OpenSSL 3.5.5 from
`/usr/lib/x86_64-linux-gnu/libcrypto.so`. `crypto-dependency.txt` in each build
records the selected version/library and probe outcomes. Use the normal
[build commands](build.md); OpenSSL development headers/libraries are now
required. The installed SDK identities and source HEADs are unchanged from the
[native-extension checkpoint](native-extensions.md#artifact-and-source-provenance).
Build, fixture, harness and documentation changes remain uncommitted.

Both flavors pass the relocated and filesystem-isolated product checks,
including three boots with two `init:restart` operations. On each boot the
candidate starts/stops Crypto, verifies its module and native-library origin,
checks the standard SHA-256 `abc` vector and AES-128 zero-key/zero-block vector,
performs encryption/decryption and random-byte/hash-comparison operations, and
then continues the existing product checks. The isolated run has no original
SDK, source or build tree available. This establishes bounded application
integration, not comprehensive cryptographic certification.

Nine application resources are now installed, with 341 source-built application
modules and thirteen external preloads. All 354 Erlang artifacts are
byte-identical between interpreter and JIT builds. Shared VM SDK binaries are
unchanged; their prior runtime/playground/package evidence remains historical
and was not rerun for this OTP-only build change.

## Unchanged engine suite and unresolved coverage

The full upstream `engine_SUITE` executes all 31 selected cases. Its source,
Common Test hook and ten key fixtures match the original import. No groups,
cases or assertions are removed. Each flavor reports:

| Passed | Failed cases | User skips | Automatic skips |
| ---: | ---: | ---: | ---: |
| 28 | 0 | 3 | 0 |

The three upstream skip paths are:

- `sign_verify_dsa` and `get_pub_from_priv_key_dsa`: `init_per_testcase/2`
  derives `dsa` from the case name and asks `pkey_supported/1` about that atom.
  The retained Crypto implementation advertises the algorithm as `dss`.
  Consequently the unchanged guard returns `Unsupported in this cryptolib`.
- `get_pub_from_priv_key_ecdsa`: the retained `privkey_to_pubkey_nif` implementation
  marks ECDSA extraction unimplemented and returns `notsup`; the suite converts
  that result into `ECDSA not supported`. ECDSA signing/verification is a
  separate case and passes.

These explanations follow the original source; the skips are not passing
coverage, and no new platform exclusion or test change has been adopted.
They remain open coverage items. The strict harness still requires all selected
cases to pass without skips, so `upstream-engine_SUITE` is **nonpassing** in
CTest. The other eleven OTP checks pass on both flavors, including the complete
35-case dirty-NIF suite and the previous thirty application cases. Aggregate
upstream results are 93 passed, zero failed cases and three user skips per
flavor; the CTest coverage gate must not be described as all green.

Native engine error diagnostics can contain non-UTF-8 bytes. The harness now
preserves subprocess output as bytes in `execution.log` and decodes only its
human-facing error message with escaped invalid bytes. It writes actual CT
counts, skip names/reasons and `complete: false` into `result.json` even when
the strict coverage gate fails. The initial text-decoding failure was an
orchestration problem, corrected without changing suite behavior.

Run `ctest --preset linux-emu --output-on-failure` and the corresponding JIT
preset. Full records are under `build/<preset>/checks/upstream/engine_SUITE-*/`
and CTest's `Testing` directory; disposable aggregate logs are workspace
`tmp/otp-crypto-full-{emu,jit}.log`. The twelve input hashes and SDK selection
are preserved in the build-local preparation/result JSON records. The original
import `9f719f9235cde79a8b58f4360eed70200d35b966` and upstream pin remain the
source references.

The much larger `crypto_SUITE`, property tests, benchmark suite and remaining
Common Test runtime dependencies have not been validated. Complete Linux
application assembly, wider native/API coverage, external-node interoperability
and releases/upgrades remain unfinished.
