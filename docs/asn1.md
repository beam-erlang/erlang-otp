# ASN.1 source assembly and acceptance

ASN.1 5.5 builds from retained OTP 29.0 sources against an installed BEAM SDK
on Linux interpreter and JIT configurations. It adds 22 application modules,
application/upgrade resources and the ordinary `asn1rt_nif.so` extension.
The initial ASN.1 checkpoint contained ten application resources, 363 application modules
and thirteen external preloads: 376 byte-identical BEAM files between flavors.
This is bounded assembly evidence, not complete ASN.1 compatibility.

## Build ownership

`cmake/OTPASN1.cmake` invokes the retained `prepare_templates.erl` generator
through the selected installed `BEAM::CLI`. Eight source-built runtime-template
modules supply abstract code for `asn1ct_rtt.erl`; that result and the retained
function specification supply `asn1ct_eval_ext.erl`. Each generator runs in its
own process because it calls `halt/1`. Both generated sources are byte-identical
between flavors. Generator/template tool modules stay in the build directory;
the explicit upstream product inventory excludes them.

The compiler's `vsn` macro receives version 5.5 from `otp_versions.table`.
`asn1_erl_nif.c` compiles unchanged against `BEAM::NIF`; its runtime imports are
public `enif_*` functions and libc support, with no private VM dependency or
SDK build-path RPATH. No shared-runtime change was required.

## Passing evidence

Both flavors pass:

- The complete unchanged `asn1_app_SUITE`: five cases covering application and
  upgrade resources, module inventory, exports and declared dependencies.
- The complete unchanged `syntax_SUITE`: twelve cases covering ASN.1 parser and
  tokenizer diagnostics, without failures or skips.
- Compilation of the unchanged `examples/P-Record.asn` schema and BER/PER/UPER
  encode/decode of an explicitly supplied, schema-ordered personnel record.
  Product checks repeat this on three boots after relocation and with original
  SDK/source/build paths unavailable. Compiler version/module origin and loaded
  native extension origin are checked.

At that checkpoint, unchanged upstream suite results totaled 110 passed and three Crypto engine user skips per flavor. The engine gate
remains nonpassing. The then-current fifteen-check CTest inventory had thirteen
passing checks and two nonpassing coverage gates when combining the complete
run with the focused reruns described below; no single all-green run is claimed.

## Generated-value investigation

The initial `asn1-value-generation` check required the unchanged example's
generated `v/0` constant to round-trip. BER passed, but PER and UPER failed
on both flavors. The generated constant puts `children` first, following
canonical SET tag order; the generated record/encoder use textual schema order
and expect `children` in tuple element seven. That element instead contains the
spouse's `Name` tuple, causing `length/1` to raise `badarg` in the encoder.

Retained `asn1ct_check:check_set/3` sorts PER/UPER components, and
`normalize_set/4` / `normalized_record/5` assemble the constant from that order.
This source path explains the observed output. The pinned upstream comparison
below resolves the suspected divergence: the candidate preserves the upstream
behavior, including its limitation. No compiler or VM correction was made.

An earlier harness also redundantly loaded the module after `asn1ct:compile`
had loaded it. Removing that second load corrected the resulting old-code
deletion failure. The current product probe verifies the compiler-loaded path
and supplies its own schema-ordered value; generated-value behavior is measured
independently by the upstream-compatibility check below. No upstream assertion was modified.

## Pinned upstream comparison

The original autoconf/make OTP 29.0 release archive reproduces the same BER
success and PER/UPER `length/1` failure. All six generated `.erl`/`.hrl` files
are byte-identical to both candidates. The archive is the workspace's
`references/erlang-otp-29-artifacts/linux-amd64-glibc-base/artifacts/release-tree.tar.gz`,
SHA-256 `c182aeb6306397df6b7aa9e74e154035712f546e84ab46398aecf79f896535ca`,
at upstream pin `550d7b7898706c7822362c42e7b93120c1d1f29a`. It was extracted
under workspace scratch and used only as a reference oracle. Its executable
and generated artifacts never supplied the candidate build or product checks.

The initial round-trip expectation exceeded the OTP compatibility target.
`asn1-value-generation` now verifies the pinned input hash, six exact upstream
generated-output hashes, BER round-trip success and the specific PER/UPER error
with its value and leading stack frames. Both candidate flavors pass. The
[reference manifest](../tools/fixtures/asn1-value-reference.json) records the
pin, archive and output hashes. No upstream suite, assertion or product source
changed; general ASN.1 round trips remain covered separately. This establishes
parity for the example, not a correction to upstream value generation.

Reference logs and generated files are under workspace
`tmp/otp29-asn1-value-reference/`. Candidate rerun evidence is in
`tmp/otp-ssl-product-{emu,jit}.log` and build-local `checks/asn1-values-*/`.

## Reproduction and provenance

Use the [build instructions](build.md) with each matching installed SDK. Run
`ctest --preset linux-emu` and the JIT equivalent for the full inventory, or
select `initial-product`, `isolated-product`, `upstream-asn1_app_SUITE`,
`upstream-syntax_SUITE` and `asn1-value-generation` individually with `-R`.

The source HEADs remain OTP `72a1beb074a9fb8481d652418db80255c2962008` and BEAM
`795e3ac7fa39433cce26bc979bd8889da324d52a`, with uncommitted build/harness and
documentation changes. SDK identities remain:

| Flavor | Installed SDK build identity |
| --- | --- |
| Interpreter | `863297a374d2f1cb162e64bddf5fad669b3c2d64e466e45916ed7caecef6c975` |
| JIT | `7d73ab684108516f4cff52ec57eb7c43db26dabb6aaed604f7cbd615379e33f0` |

Build-local `checks/upstream/<suite>-*/result.json` records suite/input hashes,
SDK identity and exact result tuples. `checks/asn1-{relocated,isolated}.json`
records product/schema evidence. `checks/asn1-values-*/` retains generated
sources, headers, per-rule logs and the value-compatibility result.
All ASN.1 sources, examples and suites match the original import. The only
retained product-source adaptations remain the preceding seven preloads and
two removed unused includes in `erlexec.c`; bootstrap inputs remain unchanged.

Disposable workspace logs are `tmp/otp-asn1-build-{emu,jit}.log`,
`tmp/otp-asn1-full-{emu,jit}.log` (initial harness failure),
`tmp/otp-asn1-validation-{emu,jit}.log` (syntax success/value discrepancy),
`tmp/otp-asn1-product-{emu,jit}.log` (corrected explicit-record checks), and
`tmp/otp-asn1-values-{emu,jit}.log` (historical round-trip expectation). Shared-runtime,
playground and GLM acceptance were not rerun for these OTP-only changes;
their prior matching-SDK evidence remains historical.

The subsequent [testing record](upstream-testing.md) records the passing
compiler-error suite and all 103 cases of the full unchanged ASN.1 suite passing
on both flavors without failures or skips. The full suite used the SDK identities
above and recorded hashes for 531 unchanged inputs. [Public Key](public-key.md)
and [SSL](ssl.md) now consume this compiler. Complete ASN.1 compatibility and
the full Linux application set remain unproven.
