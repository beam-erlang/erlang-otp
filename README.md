# Erlangsters - Erlang/OTP

An experimental Erlang/OTP distribution built from OTP 29.0 sources around the
VM supplied by [BEAM/Erlang](https://github.com/beam-erlang/beam-erlang).
This repository owns OTP applications, commands, startup policy, native services,
resources and installation. It consumes an explicitly selected installed SDK;
`libbeam` is its sole VM, linked statically into the standard OTP host.

The product builds the complete target application inventory, including Observer,
Reltool and wx. Full OTP 29.0 compatibility remains incomplete. A configured
platform, assembled application or selected passing test does not establish
upstream equivalence or release qualification. The
[compatibility contract](docs/compatibility.md) defines the Linux interpreter/JIT
target, installed-SDK boundary, required gates and treatment of unsupported,
skipped, disabled and untested scope. [UPSTREAM_COMMIT](UPSTREAM_COMMIT) records
source provenance separately from product/SDK identity.

## Build

Obtain a matching installed SDK and explicitly selected build dependencies first.
OTP owns its source-attested compiler bootstrap; it does not require an existing
Erlang installation or the modern BEAM command. Follow the
[build guide](docs/build.md) for Linux, native macOS, Windows MSVC and Windows
UCRT64 configurations, dependencies and acceptance inputs.

```sh
cmake --preset linux-emu \
  -DBEAM_SDK_ROOT="$BEAM_PREFIX" \
  -DOTP_BEAM_SDK_VERSION="$EXPECTED_BEAM_VERSION" \
  -DOTP_BEAM_SDK_BUILD_ID="$EXPECTED_BEAM_BUILD_ID"
cmake --build --preset linux-emu
cmake --install build/linux-emu
```

Use `linux-jit` with its matching SDK for JIT. SDK version/build identity must
come from the verified producer record independently of the prefix under test.
Builds and installations stay in ignored `build/<preset>` and `install/<preset>`.
Missing capabilities fail explicitly without a sibling build or runtime fallback.

The installed host embeds its VM, thirteen OTP preloads and built-in native
implementations. Application extensions, commands, development headers/libraries
and resources retain upstream locations. System/third-party dependencies remain
explicit. No SDK runtime library, extra runtime directory or validation manifest
is installed. [Architecture](docs/architecture.md) describes composition and
faithful installation; [maintenance](docs/maintenance.md) describes versions and
upstream propagation.

## Use

```sh
install/linux-emu/bin/erl
```

Enter `q().` to exit. The installation supplies `erl`, `erlc`, `escript` and
`ct_run`. For a compiler example:

```sh
mkdir -p build/example
install/linux-emu/bin/erlc -o build/example tools/fixtures/otp_compiler_probe.erl
install/linux-emu/bin/erl -noshell -pa build/example \
  -eval 'io:format("~p~n", [otp_compiler_probe:run()]), halt().'
```

This prints `42`. Replace the flavor with the installed selection you intend
to use. [Commands](docs/commands.md) describes launch policy and option handling;
unsupported emulator policies fail rather than implying complete command coverage.
Retained upstream application and command manuals remain under `lib/*/doc` and
`erts/doc`.

## Test

```sh
ctest --preset linux-emu --output-on-failure
ctest --preset linux-jit --output-on-failure
```

Supply matching original-reference provenance, the pinned release tool and
explicit service dependencies as required by each test. Linux isolation needs
bubblewrap/private namespaces, loopback networking and POSIX terminals. wx tests
require Xvfb and explicit `OTP_ENABLE_WX_TESTS=ON`; guarded interactive checks
require real attendance. Disabled entries and missing prerequisites are not
passes. Registered selections do not cover the complete compatibility target.

[Upstream testing](docs/upstream-testing.md) explains invocation and raw result
semantics. [Fixture preparation](docs/test-preparation.md) owns subsystem/platform
requirements. [Local qualification](docs/local-qualification.md) binds inventories,
case/command observations, installation/content review and exact source/SDK
identities without replacing raw outcomes. Generated results stay in ignored
build output or CI artifacts; these manuals establish no captured validation run.

## Engineering documentation

- [Architecture and installed SDK boundary](docs/architecture.md)
- [Build and bootstrap maintenance](docs/build.md)
- [Application assembly](docs/application-build.md)
- [Commands and launch policy](docs/commands.md)
- [Native extensions](docs/native-extensions.md)
- [Upstream testing](docs/upstream-testing.md)
- [Fixture and platform preparation](docs/test-preparation.md)
- [Qualification interfaces](docs/local-qualification.md)
- [Compatibility requirements and stop rules](docs/compatibility.md)
- [Source and distribution maintenance](docs/maintenance.md)
