# Historical qualification records

[Linux amd64 Stage 8](linux-amd64-stage8.md) records the current Emu Release
qualification attempt: all four distribution checks pass. Original `ct_run` and
verified writable copies corrected the first two controller-interference
failures. A later global EPMD override and cancellation gap were corrected;
unchanged case proofs pass on candidate and reference, and all 75 controller
checks pass. A fresh 39-component campaign is running. Stage 7's deferred
prerequisites remain visible and do not become passing coverage.

[Linux amd64 Stage 7](linux-amd64-stage7.md) records the prerequisite inventory,
Linux ownership implementation and bounded execution evidence. Stage 7 resumed
with original sources and tests unchanged. The original runner reproduces the
FTPS setup skip on both builds; earlier source-patch proposals are withdrawn.
Older-release provisioning follows the original environment recipe, with actual
OTP 27/28 inputs explicitly deferred by the user. The user closed the Stage 7
checkpoint on 2026-11-17 with an explicit deferred-work table. OpenSSH PTY,
service/endpoint readiness and other unresolved coverage remain technically
open; private display/Emacs and native-input checks do not establish acceptance.

[Linux amd64 Stage 6](linux-amd64-stage6.md) records the completed payload audit,
candidate/original DSS and revised project-fixture checks, and passing installed,
staged, relocated and isolated checks. Documentation generation is unsupported;
full original-corpus and other-configuration qualification remain later work.

[Linux amd64 Stage 5](linux-amd64-stage5.md) records recipe alignment, bounded
Release evidence and the unfinished validation checklist explicitly deferred
when the user moved work to Stage 6.

[Linux amd64 Stage 4](linux-amd64-stage4.md) records the granular controller,
final bounded execution evidence, remaining limitations and review stop.

[Tests directory audit — 2026-11-16](tests-audit-2026-11-16.md) records the
purpose of each reviewed test file, cleanup findings and the remaining Stage 4
work. It is a review snapshot; its recommendations are not implemented changes
or execution inputs.

[upstream-adaptations.json](upstream-adaptations.json) preserves the former
`tests/upstream/adaptations.json` record unchanged. Its policy text, source hashes,
implementation claims, validation results and evidence paths describe the former
recording scheme and individual historical attempts. They are not current
instructions, proof that a change is present, or qualification of this checkout.
Referenced temporary evidence may no longer be available.

Builds, preparation, execution and result classification must not read this
record. Current source and transformation contracts belong in project code and
the operational test inventory; each run records the inputs and outputs it
actually used. See the [source differences](../source-differences.md) and
[OTP testing guide](../otp-tests.md) for current behavior and limits.

The former operational manifest also contained eight OCSP refusal rules bound
to a prior Darwin OpenSSL 3.6.3 binary and an earlier modified SSL helper. Those
rules have been removed from current execution data. Their historical outcomes
do not authorize a responder or explain a new failure; unsupported SSL lifecycle
setup remains blocked, and unrecognized events remain nonpassing.

The former EI recipe record also reported a preparation failure for the absent
`all_SUITE_data/runner.c`. The current recipe correction retains its exact
before/after text and hashes: only the unused `runner.o` aggregate goal is
removed, while active EI links continue using `ei_runner.o` and `my_ussi.o`.
The historical failure text is not an execution input.
