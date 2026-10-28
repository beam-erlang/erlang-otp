# Local Linux qualification

The [compatibility contract](compatibility.md) targets
Linux x86-64 interpreter and JIT installations using the public installed SDK.
An inventory, a working command or a passing selected suite does not qualify the
distribution. Qualification and release promotion remain separate decisions.

## Specification and command inventory

`tools/compatibility_inventory.py` verifies an explicitly selected candidate and
matching original-build reference, then uses the installed Common Test
`ct_testspec` implementation to resolve every top-level application/ERTS `.spec`
and `.dynspec`. Dynamic specifications receive Linux/GCC bindings. The resolver
records its source hash and both installation provenance hashes. It never uses
system Erlang or changes selected installations.

```sh
python3 tools/compatibility_inventory.py \
  --source /path/to/erlang-otp \
  --prefix /path/to/candidate \
  --provenance /path/to/candidate-provenance.json \
  --reference-prefix /path/to/original-otp29 \
  --reference-provenance /path/to/reference-provenance.json \
  --output /path/to/scratch/inventory.json
```

The inventory preserves Common Test's run selectors and original skip terms,
hashes top-level suite sources, assigns a primary owner and records installed
commands/helpers/templates and command-manual controls. Benchmark and alternative
specification labels describe inputs, not passing exclusions. Alternative
selections still require an evidenced coverage relationship. Sources nested
inside test data are not independent qualification suites; parent suites retain
their preparation and execution ownership.

Whole-suite benchmark exclusions are retained as structured upstream selections,
including their exact reasons; they do not become invented passing suites.
The reconciler reruns the specification resolver through a selected installed
candidate and rejects omitted/reclassified specifications, changed suite owners,
missing resolved suite selections and stale source or command-manual inventories.
Coverage annotations alone cannot close command entries: each flavor needs
matching installed evidence naming the control IDs and source manual hashes.

Shared emulator behavior belongs to the BEAM installed-OTP-hosted harness.
OTP's existing dirty-NIF coverage keeps its ownership; system thread/printing
tests likewise retain their BEAM owner. Product commands, application behavior,
native implementations and installation tests belong here.

Case expansion remains pending until each suite's actual fixture preparation is
available. Command controls likewise require observable behavior checks. An
inventory with unexpanded selections cannot establish completion.

## Case evidence and strict suite outcomes

The existing upstream runner records Common Test terminal events through
`tools/fixtures/otp_ct_event.erl`, without replacing suite callbacks. Results
retain case identity, context, repetition occurrence, raw outcome and reason,
plus suite/group configuration outcomes. Event recording must have both start
and stop markers and agree with Common Test's independent aggregate. Missing or
conflicting evidence fails acceptance. Configuration failures cannot be hidden
by passing case totals. `otp-upstream-evidence` exercises these integrity rules.

Existing strict suite gates still require complete selected execution without
skips. `tools/qualify_local.py` reconciles explicitly selected result files against
one complete installation provenance per flavor. Matching VM bytes alone cannot
qualify different application or resource trees. Instrumented diagnostic runs,
partial selections, changed source hashes and missing or reordered case events
cannot cover a complete suite. Group/repetition selections remain uncovered
until their execution-context reconciliation is implemented.

The reconciler retains raw completeness separately from local coverage. An
inventory limitation must name one exact case/context/occurrence, flavor, source
hash, skip status and raw reason. It must bind a complete original-reference
selection and reference installation by hash, with the same skip, plus passing
candidate supplemental evidence under `gate: limitation:<id>`. Each entry also
records its rationale. A failed case, changed reason, missing original result
or supplemental check from another installation remains nonpassing. The integrity
tests exercise the reconciliation protocol independently of product results.

```sh
python3 tools/qualify_local.py --source /path/to/erlang-otp \
  --inventory /path/to/inventory.json \
  --candidate-provenance /path/to/emu-provenance.json \
  --candidate-provenance /path/to/jit-provenance.json \
  --reference-provenance /path/to/original-emu-provenance.json \
  --reference-provenance /path/to/original-jit-provenance.json \
  --result /path/to/selected-result.json --output /path/to/qualification.json
```

Repeat `--result` for every deliberately selected current run and supplement.
Unexpected outcomes in any selected complete-suite run block that suite; a
passing historical run cannot mask them. The report lists uncovered suites,
missing behavior gates and pending command controls and remains nonqualifying
while any required evidence is absent. Publication eligibility is separate.

The unchanged RAM-file suite creates a marker in `large_file_light` that skips
`large_file_heavy`. The separate `upstream-ram_file-heavy` check selects that
one case unchanged in fresh private state, preserving its two-GiB workload and
five-minute case deadline. It supplements the raw full-suite skip.

## Dependencies and output

Select verified cached service inputs through the existing vsftpd executable
and OpenLDAP/PostgreSQL CMake variables. Servers run only in private test
namespaces. Cache manifests retain versions, package URLs and SHA-256 hashes;
mutable server data belongs in disposable work. Runners retain bounded evidence
and remove disposable payloads on completion, failure and catchable interruption.
Final qualification requires fresh both-flavor installed, relocated and isolated
acceptance, GUI observations, interoperability and release lifecycle evidence
for the final recorded source/SDK pairs.

## Installation structure and content

`tools/installation_inventory.py` verifies complete selected bytes against
external provenance and compares matching-flavor paths, kinds, modes and literal
symlink targets, including the installation root. Ordinary and DESTDIR installs
need their own faithful finalization. Source/build/SDK attestation remains outside
the installed tree; see [build instructions](build.md#installation-and-external-provenance).

`tools/review_installed_contents.py` separately reviews every changed regular
file. Decisions bind an exact relative path and both artifact hashes to its
producer/source, rationale, disposition and validation. Stale or missing decisions
cannot pass; filename classes/patterns do not waive review. The tool rejects an
installation changed since capture and writes only outside installed prefixes.

```sh
python3 tools/review_installed_contents.py \
  --candidate "$OTP_PROVENANCE" --reference "$REFERENCE_PROVENANCE" \
  --decisions "$REVIEW_DECISIONS" --output "$CONTENT_REVIEW"
```

Optional paired `--candidate-beams`/`--reference-beams` records come from
`tools/inspect_installed_beams.escript` run by each selected installed `escript`.
They retain interfaces, attributes, compiler options, abstract-code hashes and
raw literal tables. Source-path normalization is limited to compiler/include and
abstract-file metadata; the logger-literal comparison changes only its `file`
field. Native reports preserve dependency/export evidence and archives preserve
member evidence. Raw differences remain available.

`tools/compare_asn1_generated.escript` compares generated function bodies/exports
while removing source annotations and consistently identifying internal generated
helpers. This is not a blanket equivalence rule for ASN.1 output. Keep raw
source/interface/executable differences, matching producer toolchains and exact
hash-bound review decisions. Structural equality, reviewed content and runtime
compatibility are independent gates.
