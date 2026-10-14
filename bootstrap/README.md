# OTP compiler bootstrap

This directory owns the private compiler foundation used to build OTP against
an explicitly installed BEAM SDK. It contains no SDK implementation or VM
executable and contributes no files directly to the installed distribution.

`seeds/` contains 277 source-attested modules and one boot resource.
`recipe.term`, `boot.script` and `manifest.json` specify their sources,
generation and exact inventories. A private host linked to the selected SDK
runs these seeds to reproduce the complete foundation before a source-built
host compiles ordinary applications. An external Erlang installation and the
modern BEAM compiler are not fallbacks.

Use the build's `otp_refresh_bootstrap_seeds` target to generate reviewable
candidates. Normal builds never change checked-in seeds. Missing, extra or
altered artifacts and unreviewed source changes fail verification. See the
[build guide](../docs/build.md) for the procedure and acceptance requirements.

The previous `beam-sdk/` subdirectory has been flattened here. The unused
original upstream `bin/` and `lib/` bootstrap copies were retired; their exact
contents remain in the pinned upstream reference and source history. The
normalization preserves every seed byte and does not change the manifest format.
