# Erlang/OTP repository guidance

Read [architecture](docs/architecture.md), [compatibility](docs/compatibility.md)
and the owning implementation before changes. This repository owns the OTP
product over an explicitly selected installed public BEAM SDK. Keep guidance
about current rules; do not add development plans, checkpoint narratives or
run reports to product source or link product guidance to them.

## Runtime and installed boundary

`libbeam` is the sole VM. Product, seed and source-built compiler hosts link
`BEAM::RuntimeStatic`, embed thirteen OTP-owned preloads and explicitly compose
OTP's linked native implementations. The SDK supplies exactly nine core Erlang
modules; preserve OTP's 22 preloaded/sticky modules and restart semantics.
Modern BEAM commands/components are separately owned. Removed runtime-family
selectors, locks, OTP boot adapters and BEAM-side OTP ownership stay removed.

Select exact SDK version, flavor, build identity and required capabilities.
Use public installed headers/symbols/CMake targets; never copy private VM headers,
use sibling source/build dependencies or introduce an alternate runtime. A missing
mechanism requires a reviewed public SDK boundary or an OTP-owned implementation.
Generic admission, activation, rollback and cleanup belong to the VM; OTP owns
native names, startup, commands, resources and distribution policy.

The host statically embeds the VM/preloads/built-ins. Preserve native-origin and
single-runtime checks. Standard application extensions remain at upstream paths.
Do not promise a stable preview C ABI, third-party component-provider interface,
hot native rebinding or complete returning teardown of OTP. Sequential fresh
VMs remain supported; concurrent VMs remain unsupported.

## Bootstrap and assembly

[bootstrap/](bootstrap/README.md) owns the complete source-attested deterministic
compiler foundation. Normal builds verify inventories, source/generated hashes,
compiler metadata and reproduced seed outputs before ordinary compilation.
Candidate refresh writes only to build output and needs reviewed adoption.
System Erlang, the BEAM command and BEAM's private compiler are never fallbacks.
Product/seed/source-built hosts share OTP-private preparation and native/preload
inventories. Preserve copied inputs, preparation failure/recovery and literal
build arguments.

[Application assembly](docs/application-build.md) owns generators, native/system
dependencies, metadata and resources. Versions come from `OTP_VERSION` and
`otp_versions.table`; explicit CMake inventories own module selection. Preserve
normal application source/compiler-option metadata, complete core inspection
artifacts and `prim_eval` assembly/abstract-code pairing. Generated sources stay
in the build tree. Native modules use public `BEAM::NIF`/`BEAM::Driver` targets
and matching SDK descriptors; private compression/PCRE symbols stay isolated.
Runtime Tools selects tracing through the public capability query without forcing
unavailable or unknown backends off. Preserve retained GUI bindings/resources
and required dependency probes.

Installation reproduces the pinned original tree for equivalent features:
paths, entry kinds, permissions and literal symlink targets. Content review is
separate from tree equality. Preserve ordinary/DESTDIR finalization and upstream
resource lookup. Install no VM shared library/development archive, startup wrapper
library, extra runtime directory or validation manifest. Keep source/SDK/install
provenance external; public native headers come from verified SDK deployment.

## Acceptance and upstream preservation

The initial full target remains OTP 29.0 on Linux x86-64 interpreter and JIT,
including every target application, optional integrations and wx-dependent GUI
behavior. [Compatibility](docs/compatibility.md) owns gates and stop rules;
[qualification](docs/local-qualification.md) owns reconciliation. Assembly,
registration, selected suites and ownership completion do not establish full
compatibility. Disabled wx tests remain untested, not an exclusion from target.

Production changes require concrete plans and applicable both-flavor installed,
relocated and isolated integration. Shared VM/SDK changes require owning BEAM
acceptance, necessary OTP adaptation and affected package checks. One behavior
has one primary test owner; preserve functional/lifecycle/integrity coverage when
retiring obsolete placement assertions. Independent product fixtures own product
release acceptance; development examples are not release inputs or gates.

Preserve upstream sources, fixtures, assertions, deadlines and selections by
default. Reviewed setup adaptations live in `tools/upstream-test-adaptations.json`
and retain source hashes/rationale and behavioral assertions. Building/generating
original fixture inputs does not authorize changed expected behavior. Reproduced
upstream defects need scoped correction decisions. Named limitations bind exact
case/context/source/flavor/reference/supplemental results and retain raw skips.
Unexpected skips, missing prerequisites and candidate-only failures remain
nonpassing. Never drain messages, force descriptors closed or weaken assertions
to conceal an incompatibility.

Stop for maintainer direction on confirmed VM incompatibility, an unsupported
architectural route, a material unresolved ownership/API choice or a proposed
weaker/narrower/bypassed acceptance boundary. Respect an already authorized
bounded correction without extending it to unrelated semantics. Report expected
versus observed behavior, reproducer, source/SDK/flavors, raw outcomes and needed
decision. Record passes/failures/skips/blocked/disabled/untested coverage separately;
never combine selected historical runs into a new complete result.

## Test inputs and cleanup

[Build](docs/build.md), [upstream testing](docs/upstream-testing.md) and
[test preparation](docs/test-preparation.md) own runnable procedures. Candidate
commands/peers always use the selected installed VM. Identified original builds
may be comparison/interoperability endpoints. Preserve exact native/helper
origins, copied-input and missing-asset recovery, terminal restoration, restart
and actual resource measurements without loader/prefix fallback.

Use explicitly selected system or verified reusable dependencies. Builds never
fetch missing inputs automatically. Service tests use private namespaces and
disposable databases/configuration; never change a running system service.
Inspect reusable dependency manifests before declaring a prerequisite absent.
GUI checks preserve attendance guards, display isolation, signal/process policy
and native lifetime; no unsandboxed retry is permitted.

Build/install only under ignored `build/<preset>` and `install/<preset>` or the
workspace's authorized scratch locations. Estimate peak disk before heavy runs
and bound concurrent installations. Runners stop owned processes and remove
payloads on success/failure/catchable interruption, retaining bounded diagnostics
and exact identities in ignored output or CI artifacts. `BEAM_TEST_KEEP_WORK=1`
is a temporary debugging override; record size/location and remove it afterward.
Never prune another running job's inputs or selected development installations.

Keep functional manifests, test oracles, fixtures and qualification interfaces.
Generated provenance/results/content-review decisions are external acceptance
inputs, not committed reports or installed assets. Do not rename/delete them
based on the word evidence. Documentation-only edits need focused link/content/
whitespace checks, not invented product execution claims.

## Source maintenance

[Maintenance](docs/maintenance.md) owns source pins, reviewed removal history,
version/release distinctions and propagation. Inspect the actual target branch;
never reapply an obsolete blanket OTP removal mask or change the reference tree.
Preserve copyright/license notices and upstream author/provenance conventions.
Keep implementation/commits independent of interactive sessions. Preserve
unrelated incomplete changes. Work in the main checkout for distribution work;
no commits, pushes or publication are implied by an implementation request.
