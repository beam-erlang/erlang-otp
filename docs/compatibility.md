# OTP compatibility requirements

The compatibility target is Erlang/OTP 29.0 at
`550d7b7898706c7822362c42e7b93120c1d1f29a` on Linux x86-64, independently for
`linux-emu` and `linux-jit`. The product must use an explicitly selected installed
public BEAM SDK and statically linked `libbeam` as its sole VM. Full compatibility
is incomplete. This document defines requirements and interpretation; it does
not certify a source/SDK pair or substitute for executed acceptance.

## Required scope

The target includes every Linux-capable application in the OTP 29.0 version
table, including ODBC, JInterface, wx and dependent GUI functionality with their
required dependencies. Installed commands/options/environments, resources,
compiler workflows, native extensions, applicable upstream application/ERTS
suites, distributed-node interoperability, restart and release creation,
upgrades and downgrades are part of compatibility. A working shell, assembled
application count or selected passing suite cannot establish completion.

The public SDK boundary, independent bootstrap and faithful installed layout
are defined in [architecture](architecture.md). Reference installations must
match the selected upstream source, runtime flavor and configured features.
A branch name, common VM checksum or matching upstream version alone cannot
qualify different product trees. Release promotion and platform support claims
require their own owning qualification; Linux work does not certify other
platforms or an older OTP generation.

## Completion gates

Every gate requires acceptance for both Linux flavors on the selected final
source and SDK identities. Run suites as their dependencies become available;
intermediate selections do not narrow the target.

| Gate | Required behavior |
| --- | --- |
| Installed dependency foundation | Standalone SDK discovery, exact identity/flavor/capability and public-header/symbol checks, clear negative diagnostics, no sibling input or runtime fallback. |
| Working OTP product | Source-built Kernel/STDLIB/Compiler, OTP host/boot resources, standard commands and shell, compile/execute workflows, native activation, restart, required options/resources and installed/relocated/isolated execution. |
| Testing foundation | Source-built Common Test, complete native/generated fixture preparation, original selections and behavioral assertions through installed candidate commands and peers. |
| Application and installation assembly | All target applications, correct versions, generators, native/system dependencies, headers and resources; ordinary/DESTDIR tree equality and artifact-bound installed-content review. |
| Product compatibility | Applicable application/ERTS/native behavior, external OTP 29 interoperability, command/resource controls, GUI observations and standard release creation/upgrades/downgrades. |

Missing prerequisites, disabled tests and unimplemented work are incomplete
coverage, not platform exclusions. wx tests default to disabled in the build;
that default does not exclude GUI compatibility from the Linux target.
Re-enable them explicitly when executing their required acceptance. Product
assembly and installed-tree equality establish different claims from runtime
compatibility and installed-content review.

## Acceptance ownership and integration

Each behavior has one primary test owner. BEAM owns generic VM/SDK composition,
preloads, copied inputs/results, failure recovery, native admission/activation,
process lifetime and real resource cleanup. OTP owns startup, commands,
application/service behavior, native implementations and extensions, helpers,
resource discovery, networking, restart and product compatibility. The shared
VM's installed-OTP-hosted harness owns shared emulator suites; OTP retains its
own dirty-NIF selection. Preserve functional coverage when obsolete placement
or family-selector assertions disappear.

Routine edits use focused checks for affected behavior. Production changes need
a concrete implementation plan and applicable installed, relocated and isolated
acceptance on both flavors at integration. Shared VM/SDK changes also require
owning BEAM acceptance, necessary OTP adaptation and affected package acceptance.
Independent development consumers are useful feedback, but product tests own
release requirements and must not import their sources.

Use only candidate installed commands and `libbeam`, including subprocesses and
peers. Verify the actual executable/runtime/helper origins and measured resource
restoration. Preserve missing-asset failure/recovery, copied-input and repeated
lifetime coverage. Do not replace meaningful assertions with no-op checks,
alternate runtimes, narrowed selections or fallback search paths.

## Upstream tests and limitations

Preserve upstream suites, behavioral assertions, fixture contents, deadlines and
selection structure by default. Build/test orchestration may compile or generate
original fixture inputs. A test-setup correction requires reviewed rationale,
source provenance and validation of the preserved assertions; declared setup
adaptations are hash-checked in `tools/upstream-test-adaptations.json`.

A reproduced upstream defect is not an automatic correction authorization or a
passing candidate result. Assess independently owned copies in both products.
Changes to error behavior, mailbox policy, signal/lifetime semantics or public
interfaces need an explicit scoped design decision. No harness message drain,
forced descriptor cleanup or weaker assertion may conceal a defect.

Exact named upstream limitations require matching original-reference results
and candidate supplemental behavior checks. Retain raw skips and reasons;
never convert a skip into a raw pass. Unexpected skips, candidate-only failures,
missing preparation and unmatched limitation records remain nonpassing. The
[qualification reconciler](local-qualification.md) binds any allowed local
coverage treatment to precise case/context/occurrence, source, installation and
supplemental-result identities.

Report passing, failing, blocked, skipped, disabled/deferred and untested scope
separately by flavor. Keep selections, prerequisites, source/SDK identities,
commands, results and bounded diagnostics with generated run output. Do not
combine historical and focused runs into a fictional complete run. Earlier
results apply only to their captured inputs; documentation changes establish no
new execution or qualification.

## Stop rules

Stop implementation, describe the responsible boundary and obtain maintainer
direction when a confirmed VM change prevents retaining OTP behavior, when no
supported architectural route exists, or when an unresolved ownership/API choice
materially changes the design. The same applies to a proposed weaker assertion,
narrower target or bypass of the installed SDK. A previously authorized bounded
correction does not authorize unrelated behavior changes.

Report expected and observed behavior, a reproducer, source/SDK identities and
flavors, preserved raw outcomes and the decision needed. Distinguish a confirmed
incompatibility from an untested concern. Missing generic mechanisms belong in
a reviewed SDK boundary; this does not permit silently reinterpreting discovered
VM semantics. [Testing](upstream-testing.md) and
[fixture preparation](test-preparation.md) describe the runnable interfaces.
