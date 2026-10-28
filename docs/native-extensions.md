# Native extensions

OTP deploys the selected SDK's public NIF/driver header closure under both
`usr/include` and `erts-<version>/include`. CMake requires `BEAM::NIF`,
`BEAM::Driver` and `beam_install_native_headers`; absent capabilities fail
configuration. The SDK owns generated integer-size headers, their dependency
inventory and matching hashes. Configuration/installation verify the header
closure without private VM includes or sibling source paths.

## Native ownership and linkage

OTP owns built-in terminal, compression, RAM-file, tracing, inet, socket and
resolver implementations. The product/private hosts explicitly compose their
linked native inventory against `BEAM::RuntimeStatic`; ordinary application NIFs
and drivers retain their upstream dynamic install locations.
`native-components.json` is generated build metadata describing source/output/
installation provenance, not an installed validation file or public plugin ABI.

Ordinary native extensions use `erl_nif.h` or `erl_driver.h` and resolve public
VM symbols through the running OTP host. Product composition explicitly admits
native loading. No extension may introduce another VM through direct/transitive
linkage or import private runtime symbols. Native SDK stamps and headers must
match the selected host. [Architecture](architecture.md) and the
[SDK deployment guide](../../beam-erlang/docs/c-api/deployment.md) describe that
boundary; [application assembly](application-build.md) describes owned libraries.

## Installed compilation and execution checks

```sh
ctest --preset linux-emu -R '^(initial-product|isolated-product)$' --output-on-failure
ctest --preset linux-jit -R '^(initial-product|isolated-product)$' --output-on-failure
```

These checks install/relocate a private product and copy the original upstream
NIF inputs `nif_mod.1.c`, `nif_mod.c`, `nif_mod.h`, `nif_mod.erl` from
`erts/emulator/test/nif_SUITE_data`, plus the dirty-NIF suite's `echo_drv.c`.
The NIF uses installed common headers; the driver uses versioned ERTS headers.
Installed `erlc` compiles the Erlang fixture with installed Common Test headers.
Installed `erl` loads/calls the NIF and driver, checks binary/term round trips,
closes ports and unloads before later lifecycle checks.

The isolated variant exposes only system directories, copied fixture work and
the relocated product. Original SDK/source/build prefixes must be absent; no
loader override may conceal a missing asset. Source-input hashes, native imports,
actual image origins and measured lifetime cleanup remain part of acceptance.
Windows has an independent installed NIF consumer in its native development
check. These smoke fixtures are distinct from complete `nif_SUITE` or
`dirty_nif_SUITE` acquisition; see [fixture preparation](test-preparation.md).

Changes to native lifetime, linked composition or public interfaces require the
owning both-flavor installed/relocated/isolated checks and necessary cross-product
adaptation. Do not work around missing public mechanisms with copied private
headers, implicit registration, alternate runtimes or weaker fixture assertions.
