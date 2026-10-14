# Megaco assembly

Megaco 4.9 builds from 55 retained Erlang modules and ten generated modules.
CMake generates four Yecc text parsers and six ASN.1 codecs: BER and PER for
protocol versions 1, 2 and 3. BER retains its selective-decoding configuration;
all ASN.1 codecs preserve `legacy_erlang_types`. The generators run through
the installed BEAM compiler host with explicitly source-built parser and ASN.1
tools. The full application then compiles with its behavior modules first,
upstream parser inlining and `app_vsn` metadata.

The optional upstream Flex implementation is included in this Linux product.
CMake requires Flex 2.6 or newer, discoverable normally or explicitly selected
with `FLEX_EXECUTABLE`. It generates both standard and reentrant scanners with
line-number tracking. Their shared libraries compile against `BEAM::Driver`
and install under `lib/megaco-4.9/priv/lib`. They use only public driver functions
and system libraries, with no private VM headers or alternative VM.

Application and upgrade resources, public headers, module and generated sources,
ASN.1 schemas/configuration, Flex sources and examples install under the standard
application directory. ET's retained header is a build input to `megaco_filter`;
this does not establish ET or graphical tracing acceptance. ET and Debugger
remain separate pending applications in the full product inventory.

## Acceptance boundary

The installed-product probe starts Megaco and roundtrips protocol versions 1–3
through pretty/compact text, BER, PER and Erlang-distribution codecs. It also
decodes both text formats through the reentrant scanner and exercises the standard
scanner directly through the public driver/port API. The retained native scanner
lowercases quoted text; the probe explicitly checks that existing behavior rather
than imposing the Erlang scanner's case preservation. Driver closure and application
shutdown are checked before repeating across three boots. Relocated and isolated
execution excludes the original SDK and source/build paths.

The unchanged upstream harness selects these complete suites:

| Suite | Cases |
| --- | ---: |
| `megaco_app_SUITE` | 2 |
| `megaco_flex_SUITE` | 3 |
| `megaco_binary_term_id_SUITE` | 25 |
| `megaco_sdp_SUITE` | 2 |
| `megaco_codec_mini_SUITE` | 26 |
| `megaco_codec_v1_SUITE` | 123 |
| `megaco_codec_v2_SUITE` | 172 |
| `megaco_codec_v3_SUITE` | 164 |

Suite sources, helpers and data are copied and hashed, compiled by the candidate's
installed `erlc`, and run from a relocated installation with filesystem isolation
and private HOME, cookies and EPMD. The harness preserves upstream case deadlines,
assertions and fixtures. Every selected suite requires zero failures and zero
skips to pass its strict gate.

All **517 cases pass on each flavor**, with zero failures and zero skips.
Both relocated and isolated product checks also pass. Final evidence combines
the initial selections with focused retries; the initial matrices did not pass.
The first version-1 runs on both flavors and version-2 run on JIT omitted the
unchanged `megaco_test_msg_vN_lib` helper modules, producing `undef` failures.
Adding those original helpers to preparation resolves the failures. The first
JIT product probes incorrectly expected quoted-text case preservation from the
native scanner; their corrected assertion checks the retained lowercasing
behavior described above. No upstream assertion or fixture changed.

TCP/UDP transactions, distributed gateways, timers/load, tracing and external
interoperability need broader upstream and consumer coverage. Codec assembly and
this selection do not certify full Megaco or OTP behavior.

## Source and artifact checkpoint

Sources are OTP `72a1beb074a9fb8481d652418db80255c2962008` and BEAM
`795e3ac7fa39433cce26bc979bd8889da324d52a`, with the recorded uncommitted work.
SDK identities and runtime hashes remain those in [Diameter evidence](diameter.md).
This increment changes no retained Megaco sources, upstream suite inputs,
bootstrap seeds or VM/SDK implementation.

Both installations contain 29 application entries and 994 BEAM files: 985
source-built files and nine SDK-owned core inspection files. All 929 preceding
files remain byte-identical, and all 994 execution-chunk sets match across
flavors. Compiler dependency inspection confirms that both generated scanner
libraries use installed public SDK headers and system headers; imported runtime
symbols belong to the public driver API.

The build dependency is Flex 2.6.4, explicitly selected from the extracted
`flex_2.6.4-8.2build2_amd64.deb` package without system installation. Its package
SHA-256 is `622d3959e0424ca276a01946a44a30c327d4bd6963f96b070b94e9b80b541bb8`;
the executable SHA-256 is
`380517b969e8c6e6d0ec8bf60b58f29d0779e45f63613f78efaa679de3900153`.
The CMake recipe contains no scratch-path default.

Shared-runtime, playground and matching GLM acceptance is carried forward from
the unchanged SDK checkpoint, not represented as newly executed validation.
At this checkpoint, six application entries and broader compatibility remained
pending; stage 4 and [compatibility gates 2–5](../../dev-documents/otp-compatibility.md#completion-gates)
remained open.

## Reproduction

Build with the selected installed SDK and Flex dependency, then run both flavors:

```sh
ctest --test-dir build/linux-emu -R '^(initial-product|isolated-product|upstream-megaco_(app|flex|binary_term_id|sdp|codec_mini|codec_v[123])_SUITE)$' --output-on-failure
ctest --test-dir build/linux-jit -R '^(initial-product|isolated-product|upstream-megaco_(app|flex|binary_term_id|sdp|codec_mini|codec_v[123])_SUITE)$' --output-on-failure
```

Per-run `checks/upstream/<suite>-*/result.json` records exact inputs, source hashes,
SDK identity and case outcomes. Workspace logs use
`tmp/otp-megaco-{build,check}-{emu,jit}.log`.
Focused retries use `tmp/otp-megaco-final-check-{emu,jit}.log`.
The aggregate artifact and selected-suite record is `tmp/otp-megaco-artifacts.json`.
