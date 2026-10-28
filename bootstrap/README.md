# OTP compiler bootstrap

This directory owns the private compiler foundation used to build OTP against
an explicitly installed BEAM SDK. It contains no SDK implementation or VM
executable and contributes no files directly to the installed distribution.

`seeds/` contains 277 source-attested modules and one boot resource.
`recipe.term`, `boot.script` and `manifest.json` specify sources, generated
inputs, compiler options and exact inventories. The nine VM core modules are
excluded; the selected SDK supplies their inspection artifacts. These checked
inputs are functional bootstrap data, not validation reports.

## Host stages and verification

OTP builds a common public-SDK host implementation for seed bootstrap,
source-built tooling and installed product. Version/startup declarations precede
ordinary application generation so host construction cannot depend on the
foundation it must compile. Each host links the selected `BEAM::RuntimeStatic`
and OTP-native inventory and embeds its selected thirteen OTP preloads. The
hostname helper and verified SDK child helper are staged explicitly.

The seed host invokes `otp_build_driver` with literal arguments to generate
parser/transform tooling and compile the deterministic Kernel/STDLIB/Compiler
foundation. All seed and generated-input outputs must reproduce before the
source-built host enables ordinary application, resource and release generation.
Normal product compiler/debug metadata is distinct from deterministic foundation
metadata. `prim_eval` retains its assembly/abstract-code pairing. Compiler, QLC,
parser and transform origins must resolve to the explicit private host root.

Normal recipes never invoke `BEAM::CLI`, BEAM's private compiler or an external
Erlang installation. Product, seed and source-built hosts share OTP-private
preparation of copied composition/context inputs, without VM calls during
preparation. Missing, extra, duplicate or altered artifacts and unreviewed source
changes fail verification; a manifest is not a substitute for source reproduction.

## Candidate maintenance

Use `cmake --build build/<preset> --target otp_refresh_bootstrap_seeds` to generate
reviewable candidates in the build tree. Normal builds never change checked
seeds. Review source/generated input changes, complete module/boot inventory,
compiler metadata and deterministic output before adoption; do not weaken source
attestation to accept unexplained bytes. Follow with applicable both-flavor
bootstrap, installed product and SDK-boundary checks.

[Build guidance](../docs/build.md) owns command/dependency selection;
[architecture](../docs/architecture.md) owns host composition and
[compatibility](../docs/compatibility.md) owns integration/stop rules. Retired
upstream bootstrap copies remain recoverable from their pinned original source
and Git history; they are not fallback build inputs.
