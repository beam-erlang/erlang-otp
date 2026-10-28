# Source and distribution maintenance

[UPSTREAM_COMMIT](../UPSTREAM_COMMIT) records the upstream processed checkpoint
as one 40-character SHA and a newline. The initial import is OTP 29.0 at
`550d7b7898706c7822362c42e7b93120c1d1f29a`. The product retains its own
`OTP_VERSION` and `otp_versions.table`; the SDK's version, build identity and
flavor are selected independently. Source synchronization, product identity and
passing compatibility are separate facts.

## Versions and maintained lines

OTP preserves upstream application/ERTS reporting and uses an independent
Erlangsters distribution revision outside the faithful installed tree. Changed
delivered bytes, including a changed statically linked VM, require a new immutable
artifact identity and the owning revision/qualification review. BEAM identifies
its upstream ERTS base plus its own distribution revision; matching base versions
do not replace exact SDK capability and identity checks.

`master` develops the selected generation. OTP maintenance branches use
`maint-<OTP-major>`; the OTP 29 line corresponds to BEAM's ERTS 17 `maint-17`
line. Create a maintenance branch from a reviewed committed product checkpoint
when needed, before development advances to the next generation. Inspect local
changes, existing refs and divergence; do not reset, auto-commit or force-push.
A branch name establishes neither contents, upstream synchronization nor support.
Support scope/end conditions need an explicit declaration; retained artifacts
and older upstream branches do not promise maintained product lines.

The [shared upstream procedure](../../beam-erlang/release/upstream-sync.md)
owns coordinated range review. Review non-ERTS application/compiler/build/test
changes even when the ERTS version is unchanged. Assess correctness/security
fixes independently for both products; never copy them automatically.

## Import and reviewed removals

New imports use exact committed-tree exports such as `git archive`, with source
pin, modes, copyright and licenses preserved. Record the clean import separately
from product changes. Tracker/reference sources are comparison inputs, not build
inputs or alternate candidate runtimes. Tracker HEAD need not equal the selected
compatibility pin.

The initial product import is `9f719f9235cde79a8b58f4360eed70200d35b966`.
Its reviewed deletion-only commits are permanent source history:

| Commit | Reviewed scope |
| --- | --- |
| `a0fcee2718088aabca48aabbad031e4f6861f429` | Build/release and completion-comment workflows. |
| `afab7202b5aaef3b4b5faaf321eeb60a1a3df79c` | Root legacy configure/build entry points. |
| `3dceb148cd10348c51e20c4a74553c0b9094a7f6` | Selected emulator/JIT/AsmJit implementations. |
| `5dae7fb4519de0ebea1d61beaf8862a048ddf4af` | Explicit allocation/GC/process/scheduling/code-loading implementations. |
| `0d4da61f9b356ff3fb636c42fed4c578d7c4ab14` | Upstream repository infrastructure/development configuration. |
| `11a4ef0ca07982669b5fe3cc054d940bfecd7ac9` | Legacy make/xcomp/scripts/autoconf and platform build tooling. |
| `057c91214174b43eb7496a0853ffbd6912dc1575` | Remaining Make/Autoconf files and obsolete templates. |

Use the actual commit diffs and target branch, not a blanket removal mask.
Other branches do not acquire these removals automatically. Retained `.mk`
expected outputs, functional `Emakefile` fixtures, generated bindings, test data
and bootstrap inputs must not be mistaken for obsolete build machinery.

## Reviewing upstream changes

Process selected released tags/commits individually against each affected owner.
Resolve current paths and retained adaptations before applying a change. Review
legacy upstream build changes for requirements to implement in owned CMake,
rather than restoring deleted machinery. Shared VM changes need appropriate
SDK mechanisms and OTP adaptation; missing files in one product can still
contain relevant behavior fixes.

Review generated sources, compiler/debug metadata, seed attestation, public
native boundaries, resources and notices. Refresh candidates through the owning
bootstrap procedure, never by changing expected hashes to accept unexplained
outputs. Run affected both-flavor installed/relocated/isolated acceptance and
preserve raw failures/skips. A clean merge or source-preservation check is not
runtime acceptance.

When a source change is committed with authorization, preserve the upstream
subject/body/author and append `Synced-to: <40-character SHA>`. Add `Adjustment:`
for meaningful manual adaptation or omitted paths. Record dispositions once per
target branch; advance `UPSTREAM_COMMIT` only through the reviewed range. An
out-of-range selected fix is recorded separately and does not imply adoption of
a whole later release. A new major requires complete ownership/bootstrap/resource
review, rather than reapplying the OTP 29 deletion set.

## Documentation and generated output

Keep product manuals about implemented behavior, reproducible procedures,
requirements, supported limitations and permanent source provenance. Update
owning documents when paths/contracts change; facts have one primary home.
Plans, checkpoint narratives, validation receipts and development consumer
reports do not belong in product source or product-document links.

Operational manifests, test oracles and qualification schemas are functional
inputs. Preserve them and their integrity checks. Generated result/provenance/
content-review records stay in ignored build output or CI artifacts, outside
installed prefixes. Stop owned processes before cleanup and retain only bounded
diagnostics/identities needed by active downstream acceptance. Never delete
another running job's inputs. See [qualification](local-qualification.md) and
[compatibility](compatibility.md) for interpretation and integration requirements.
