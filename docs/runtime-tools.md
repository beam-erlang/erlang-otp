# Runtime Tools assembly and native ownership

Runtime Tools 2.4 builds its twelve retained Erlang modules and application
resources from source. Its public headers and tracing examples are installed
with the application. This is one application in the full Linux OTP target;
the [application inventory](application-coverage.md) tracks remaining work.

## Native boundary

All three native implementations now build from this repository through the
installed public SDK. `trace_file_drv` and `trace_ip_drv` use `BEAM::Driver`;
`dyntrace` uses `BEAM::NIF` and its matching-build stamp. The IP driver uses
checked platform nonblocking socket operations instead of VM-private `sys.h`.
Configuration probes `socklen_t` locally.

Configuration queries `beam_native_trace_backend_get()` through installed
`beam/native.h` and `BEAM::RuntimeStatic`, without starting a VM. The returned backend
selects the retained dynamic-tracing implementation: none preserves unavailable
behavior, DTrace/SystemTap use public user-trace NIF calls, and LTTng requires
its declared system development package. An unavailable or unknown SDK query
fails configuration. This replaces the private VM configuration/header dependency;
it does not force an instrumented SDK to use the disabled implementation.

The libraries install directly in `lib/runtime_tools-2.4/priv/lib`. OTP no longer
acquires `nif.dyntrace` or `driver.trace_ip_drv` from the SDK. Upstream `dyntrace`
and `dbg` retain ordinary application resource lookup and native activation.
`native-components.json` records source, output and installation provenance;
the public-boundary check inspects compiler dependencies and native imports.
No BEAM source/build directory is an input to this CMake build.

Migration validation is pending. The unchanged suites, relocated/isolated product
probes and restart checks must run against the new SDK and OTP-owned outputs.
The results below describe the preceding SDK-built arrangement, not evidence
for this transfer. Instrumented tracing configurations remain unproven.

## Validation

The product probe exercises actual IP and file tracing through `dbg`, loads
the matching dynamic-tracing NIF, checks its origin, and repeats across two
`init:restart` operations. It runs from relocated installations and with the
original SDK, source and build trees inaccessible. The upstream harness also
prepares the unchanged three-case `runtime_tools_SUITE` and the 22-case
`dbg_SUITE`, including the latter's native tracer fixture and candidate peers.
Both complete suites pass on both flavors: `{3,0,{0,0}}` and
`{22,0,{0,0}}`, with no failures or skips. Two and five unchanged upstream
inputs respectively are recorded in each result manifest.

The SDK extension adds fresh/relocated selection, dependency closure, hash and
native-loading checks for both new artifacts. Shared-runtime acceptance requires
the complete BEAM CTest suite, playground matrix and separate matching GLM
checks for both flavors.

Both product modes pass on both flavors, including two restarts and mapped
NIF provenance. The first probe incorrectly stopped an already-terminated
trace client; it now monitors termination after `dbg:stop`. Its isolated origin
check uses the `/otp` mount namespace. These were new probe errors, not product
or upstream-test changes.

The first full debugger runs passed 21 cases and failed `port`: its unchanged
filename-to-atom conversion received a 285-character harness-generated path.
OTP's 255-character atom limit is unchanged in both source trees. Short unique
work-directory names and shorter peer-node names keep the generated test path
within that limit. Both complete 22-case reruns pass without assertion edits.
Use a short build root when running this upstream suite; arbitrary deep roots
can exceed its filename-to-atom limit.

Broader Runtime Tools suites and instrumented tracing remain unproven. This
checkpoint does not close the full OTP compatibility goal.

## Revisions and acceptance record

The source HEADs are BEAM `795e3ac7fa39433cce26bc979bd8889da324d52a` and OTP
`72a1beb074a9fb8481d652418db80255c2962008`, with the documented implementation
uncommitted. The upstream pin remains
`550d7b7898706c7822362c42e7b93120c1d1f29a`. OTP has fourteen application
resources, 511 application modules and thirteen external preloads: all 524
BEAM files are byte-identical between interpreter and JIT builds.

| Flavor | SDK build identity | Installed `libbeam.so` SHA-256 |
| --- | --- | --- |
| Interpreter | `d70c41d741438387d634ef5725243e98b579de46d5abd25993d06b110797e35c` | `e558e7c2837fe56ab60a2da3b23719d588fed5c2acdaf29b45bd14425132008c` |
| JIT | `47a9712a6d2b8c26ec8f0422acea6d4fece1c3a21e4993b4ab34e94d525b2c80` | `987c723c49db5e261f9c158c03b7ec3f6cef40d0baf1441ab7f00c1e1fd5f03a` |

The BEAM full regression plus focused corrected-inventory reruns passes all 26
checks per flavor. Earlier failures assumed every installed native artifact was
a boot dependency; the corrected checks require the new optional artifacts to
be installed while absent from boot mappings and boot bundles. The expanded
native boundary checks validate their owning sources, separate objects, exact
exports, permitted imports and relocatable dependencies. The first full run
used the older generated test inventory; reconfiguration and focused reruns
validate both new targets. No VM implementation or public C declaration changed
in this iteration.

The playground passes 62 configurations and 25 relocated bundles per flavor
(23 projects, 124 configurations and 50 bundles in total). Separate matching
GLM consumer checks pass, using freshly built archive SHA-256 values:

- Interpreter: `ef8c8a17bf77015467bc9766af51f70a5b9217c0852a64b5835e2a615af567bd`.
- JIT: `77bc7cfc0b94c13f21835f3ec4cdf0c7fc0afdcfb13fe12a2b72851e7a8b323f`.

The OTP 23-check regression excluding the separately completed ASN.1 suite,
combined with corrected probe/harness reruns, has 22 passing checks per flavor.
The strict Crypto engine gate remains nonpassing with 28 passed and three
upstream user skips, unchanged from the [Crypto record](crypto.md). Completed
upstream coverage with the tracing SDK totals 186 passed and three skips per
flavor. The separately completed 103-case ASN.1 suite used the preceding SDK;
its results are not relabeled as a tracing-SDK run.

Reproduce with the [build commands](build.md), the full BEAM CTest presets,
`dev-playground/tests/standalone.py` for both prefixes and the separate GLM recipe.
Focused OTP coverage is selected with
`ctest --preset linux-emu -R 'product|upstream-(runtime_tools|dbg)_SUITE'`
and the corresponding JIT preset.

Disposable workspace evidence is in `tmp/tracing-sdk-{configure,build,install,full,focused}-{emu,jit}.log`,
`tmp/tracing-sdk-playground-{emu,jit}.log`, `tmp/tracing-sdk-glm/`, and
`tmp/otp-tracing-{configure,build,install,check,product,focused}-{emu,jit}.log`.
Build-local upstream `result.json` records exact SDK/input hashes and case
counts; the shorter debugger directories are `checks/upstream/dbg-*`.
Retained OTP application, suite, fixture and bootstrap sources remain unchanged
from the import. The eight preceding retained-file adaptations remain the
seven preloads and unused-include removal in `erlexec.c`.

