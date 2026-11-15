# Linux amd64 Stage 6: release contents and documentation

Stage 6 began on 2026-11-16 after the user explicitly closed Stage 5 with
[pending validation](linux-amd64-stage5.md). The initial read-only audit below
identified two review gates. The user approved the one-line SNMP guard and an
attempt to reuse the original Make documentation rules. The later decision to
make documentation generation unsupported supersedes that attempt; see the
[latest decision](#latest-decision-documentation-generation-unsupported).
Stage 6 is complete under the revised documentation scope and stops for review.
The payload audit, candidate/original installed-source and revised project-fixture
checks, and installed/DESTDIR/relocated/isolated integration checks pass. The
final section records the explicit project-test contract revision; the earlier
failed expectations are preserved as historical evidence. Documentation
generation remains unsupported. Stage 7 has not started, and the separate
Stage 5 checklist remains pending. This is not full original-corpus or
four-configuration qualification.

The original pin remains OTP 29.0,
`550d7b7898706c7822362c42e7b93120c1d1f29a`. Evidence is in workspace
`tmp/otp-stage6-linux-amd64-WC6uwf/`; builds/tests do not consume this record.

## Initial release-content audit

All 3,443 entries in the original portable-release manifest were verified
against their recorded bytes, types, modes and links. Including directories,
the reference has 3,679 entries and the current candidate 3,558.

| Initial comparison | Count / scope |
| --- | --- |
| Missing reference entries | 164 files and 29 directories |
| Additional candidate entries | 68 files, one alias and three directories |
| Common regular files | 3,278 |
| Raw content-hash differences | 1,459; includes BEAM/native metadata, not blanket failures |
| Shape/mode differences | 35 file modes and 57 directory modes |

The 164 missing files split into 53 VM-internal payload entries requiring an
explicit SDK-boundary disposition, 96 EI source/configuration payloads, and
15 other OTP-owned files. This classification is not acceptance of every
omission. Of the EI payloads, 93 source/README files are already retained;
original Makefile inputs and generated `eidefs.mk` still need restoration and
mapping to the selected public EI build.

The other payload gaps are mapped to original recipe lines: ASN1 native/app
sources, Common Test's two `proper_ext` BEAMs and sources, the Diameter parser
location, OS Mon's `memsup.hrl`, SNMP's `snmpc.src`, Xmerl application sources,
and three release boot/example files. All 14 common boot/rel/script files are
byte-identical; the missing paths are `releases/29/start_all_example.rel`,
`start.boot` and `start.script`.

All 35 application versions match. Common `.appup` files are byte-identical.
`wx.app` differs in formatting; `erts.app` has the same modules with different
ordering. Eleven native shared objects have mode 0644 rather than reference
0755; `erl_gl.so` itself is byte-identical. Twenty-three SDK preload source
files and the installed version list have other mode differences. Extras such
as the persistent publication lock still require individual disposition.

Detailed job files are `release-inventory-before.json`,
`release-inventory-initial-assessment.json`, `reference-inventory.json` and
`candidate-inventory.json`. These are an initial map, not completed release
qualification or a final manifest reconciliation.

## Approved proposal 1: additional SNMP converter adaptation

The current SNMPEA v1 output is 18,576 bytes and remains invalid. The converter
updates its quoted-string state before skipping whole-line comments. The
original license line containing `"AS IS" BASIS,` falsely opens that state,
which then prevents removal of `MODULE-IDENTITY`. The subsequent unchanged
filter converts `MAX-ACCESS` to `ACCESS`, leaving mixed v2/v1 syntax. The
earlier installed compiler diagnostic fails at `ACCESS` on line 111.

The concrete proposed change is **one condition** in
`lib/snmp/bin/snmp-v2tov1.pl`:

```diff
-    if (/\"/) {
+    if (/\"/ && (!/^--/ || $str == 1)) {
```

Outside-string comment quotes cannot open string state. Genuine multiline
strings retain the original quote updates, closing-field check and subsequent
comment return. The existing two-line array-index compatibility adaptation is
preserved; no translation rule, input MIB or license text is rewritten.

The first proposed block reorder was reviewed and rejected before application:
it could change handling of a closing string line beginning `--`. That
superseded proposal is preserved explicitly; only the guarded opening test is
recommended for approval. This paragraph records the pre-implementation review.

Alternatives are inferior here: retaining the invalid/empty artifact fails
resource validity, input masking alters source/comment treatment, and a second
SMI-aware repair filter duplicates translator semantics. The one-line original
adaptation was the smallest reviewed proposal and was subsequently approved.

After approval: generate only into task scratch with selected Perl and the
unchanged original filter; compare comment/input preservation and output
differences; compile with installed `snmpc`; retain the unchanged SMIv1/SMIv2
controls and exercise quoted comments plus genuine multiline descriptions.
Stop for review if another translation defect appears.

The exact proposed patch and hashes are in `proposed-snmp-comment-state.patch`
and `snmp-v1-audit.json`. The unchanged modern-Perl reference's empty file is a
known masked tool failure, not a valid parity target.

## Approved proposal 2: documentation orchestration rework (superseded)

At the initial review, the 165-line documentation template forced HTML and
manually duplicated original guide/index preparation and HTML-link fixup. It
generated no manual pages. Extending that translation with Make's manpage
selection/naming and formatter policy would cross the agreed CMake complexity
gate.

The original workflow has 38 documentation contexts: 35 applications, ERTS,
system documentation and the top index. Default outputs include manual
sections 1/3/4/6/7 and ExDoc's selected formats. EPUB-disable policy varies by
context; HTML/Markdown remain selected where EPUB is disabled. EDoc chunks and
assets, Syntax Tools' demo asset and Jinterface Javadoc also belong to the
original rules. The existing portable reference has no generated manual/HTML
corpus, so absence there cannot establish documentation parity.

The approved replacement attempt was a thin staging/execution adapter:

1. Retain the exact original documentation Makefiles/helpers, support includes
   and version inputs at the selected pin; do not modify their rules.
2. Stage a source-shaped documentation view of original/generated sources,
   candidate BEAM directories, headers, MIBs, Java inputs and assets.
3. Provide one bounded doc-only Make configuration selecting the distribution's
   own runtime, target, JDK, pinned ExDoc and release destination. Preflight the
   selected ExDoc instead of allowing implicit acquisition or an external
   Erlang runtime fallback.
4. Invoke original `docs` and `release_docs` in original top-level order.
   Original Make owns inventories, sections, formatter defaults, preparation
   and link rewriting; CMake owns staging, invocation, dependencies and install.
5. Keep an explicit documentation/release step and the portable OTP-root layout;
   validate complete outputs, installed links and source preservation.

This replaced existing build-script orchestration, so implementation waited
for the user's explicit approval under the script-rework gate. Original Make
interpreted its rules in that attempt; CMake did not duplicate that interpreter.

Required unchanged inputs include the 38 doc Makefiles, `make/doc.mk`, ExDoc
wrapper/check/format scripts, original link-fixup/install helpers and Make
support/version files, EDoc's source inventory and Jinterface's Java inventory.
The five already retained documentation assets remain exact pinned inputs.
The tool pin is ExDoc v0.40.1, SHA-256
`1addd95c8b3679580ec9f368c973955e6cf7b4456a30f2ec0f68e51982913495`.
The initial audit had no binary selected. The exact official escript was then
downloaded to workspace `downloads/ex-doc-v0.40.1/ex_doc_otp_27` and verified
against that hash before execution. GNU Make, Bash, shell utilities and Javadoc are selected along
with the existing product runtime. System package installation remains gated.

## Implementation and validation

The approved guard is applied. All 24 production MIB inputs produce identical
results through the original second-pass `sed` and the project filter. Five
job-only string/comment fixtures pass. The corrected 18,717-byte SNMPEA v1
resource and unchanged v1/v2 controls compile with installed `snmpc` (3/3).
Only three MIB inputs change relative to the old array-index adaptation; every
changed first-pass line is exactly its original text prefixed by `-- `.
The original empty reference resource is a masked tool failure, not a valid
acceptance target. See `snmp-guard-validation/summary.json`.

Project-owned declarations restore the 111 mapped OTP/EI payload files, narrow
installation to the original source/resource lists, and correct all eleven
native library install modes. The 23 released public SDK preload source files
match the reference bytes exactly. No private SDK implementation payload is
fabricated; the documented 53-file omission is an architectural difference.
Four Common Test license/vendor records, the selected VM alias and the
publication lock remain justified additions. Source/build input files are
retained even when the original release does not install them.

The original `start_all_example.rel` recipe leaves its SNMP version empty through
an undefined Make variable. Project generation uses the actual release-table
SNMP version, with the original template unchanged. EI source-release metadata
truthfully records the currently selected thread/link flags rather than
pretending the CMake target used the original configure argv.

The source audit checks 10,481 retained original files and links against the
pinned Git blobs. All 6,756 retained original test files/links are unchanged.
Outside project-owned root metadata, only the three previously approved
Runtime Tools/SNMP source adaptations differ. The test inventory digest is
`3bae8543b1253177c3ad065819eb7b608fd16ac0d16d235149b65a1b2a234f47`.
See `source-preservation.json`, `release-content-owned-implementation.json`
and `root-release-content-review.json`.

At this checkpoint, the maintained Emu Release application build had completed
after these changes. Documentation, installation and final manifest
reconciliation remained in progress. No other configuration had been built or
qualified in this stage.

The task had made no commit, push, publication, SDK alteration or original-test
edit. Stage 6 remained incomplete.

## Layout correction after review

The user stopped Stage 6 and requested that restored documentation inputs return
to their original repository locations. The 92-file mirrored tree under
`cmake/upstream/documentation/upstream/` and five older original assets under
`cmake/upstream/documentation/` have been consolidated into the original layout.
This moves 96 files; the remaining Jinterface `java_files` was already present
at its original path with identical contents, so its mirrored duplicate was
removed. All 97 destination contents match the selected pin. The original
executable bit is restored on `make/markdown_to_man.escript`.

CMake staging/dependencies and public documentation references now use these
original locations. The obsolete asset-directory README and empty mirrored
directories are removed. The accepted EI files remain at their original paths.
This is a bounded layout correction; documentation generation, broader Stage 6
validation and the separate pending Stage 5 work remain stopped.

Relocation validation passed: the maintained Emu Release CMake configuration
regenerated successfully; all 97 inputs stage with identical contents and are
declared documentation build dependencies; their contents and executable bits
match the pin. All 6,756 retained original test files/links still match the
previous test inventory digest. `git diff --check` passes. Evidence is in
workspace `tmp/otp-stage6-doc-relocation-5trMkc/verification.json` and its
configure/dependency logs. The temporary staging copy was removed after these
checks. No application/documentation build or installation ran for this
relocation; the incomplete Stage 6 installation remains unrefreshed.

## Latest decision: documentation generation unsupported

After resuming the adapter work and reviewing its costs, the user explicitly
selected unsupported documentation generation. This supersedes proposal 2 and
the earlier requirement that `otp_release` include generated documentation.
The CMake documentation module, staging template, source-URL bridge, options and
targets are removed. Windows installers are built without the original NSIS
documentation component and its documentation shortcuts.

Current builds, installations and release trees omit the generated HTML,
Markdown, EPUB, man pages, standalone EDoc chunks and Jinterface Javadoc corpus.
Original content/assets and the existing index/deprecation generators remain.
The retained core `make/` inputs stay unchanged at their original paths:

- `ex_doc.exs`, `ex_doc_vsn`, `ex_doc_link` and `ex_doc.sha256sum`;
- `markdown_to_man.escript`, `fixup_doc_links.sh` and
  `get_ex_doc_formats_no_epub.sh`.

The documentation-only Make scaffolding restored for the experiment is removed;
the retained core tools have no maintained full documentation workflow. No claim
of parity for generated documentation or the complete original release follows
from this support decision.

The withdrawn attempt did establish a bounded Compiler result. Its original
`docs` and `release_docs` targets passed with strict warnings, producing HTML,
Markdown, EPUB and four man pages. All 353 examined source links resolved to an
existing pinned file and an in-range line. The 1,298 copied candidate application
BEAMs remained unchanged; only the isolated documentation view gained the
build-only `erl_id_trans.beam` helper. The helper used its original Make target;
`lib/stdlib/src/Makefile` and `make/dep.mk` were restored unchanged for that step
and are now removed with the experimental scaffolding.

The maintained full documentation run was interrupted. The Compiler result did
not validate all 38 original contexts, complete installed links or a full
reference comparison. Its proof and the original-input/adapter hashes remain in
`tmp/otp-stage6-linux-amd64-WC6uwf/compiler-docs/representative-validation.json`;
earlier failed logs and proposal evidence remain historical records.

Stage 6 acceptance is revised to permit packaging without generated
documentation. **Documentation parity remains unmet and outside supported scope**. This record
does not claim full Stage 6 completion or close the separate pending Stage 5
Release/Debug and configuration-validation checklist. The bounded refresh and
validation below do not establish full distribution qualification.

## Documentation-support removal: validation and remaining work

The cleanup removes 91 original Make-only inputs selected for the documentation
experiment and three project-owned implementation files. Seven original core
`make/` files remain; the pre-existing Jinterface source inventory, accepted EI
release inputs and original test Makefiles remain unchanged. CI no longer
downloads ExDoc, selects documentation options or invokes documentation targets
or archive production. The 16 public test presets and all build presets are
unchanged. The retained inputs, EI files and original NSIS script match the pin.

The maintained Linux amd64 Emu Release configuration and build pass without any
documentation cache options or target. `otp_release` assembles successfully.
A fresh `DESTDIR` installation starts from its physical staged root, reports
OTP 29 / ERTS 17.0, validates all 35 application terms plus ERTS, and exercises
Crypto. That fresh tree replaces the maintained installation; the previous
installation is preserved in the task job. Both maintained install and release
omit generated documentation. Runnable wx examples retain their original
`doc/examples` location; they are product examples, not generated documentation.
The Windows package filter preserves those examples while removing generated
documentation and leaving `HAVE_DOCS` undefined. Native Windows packaging has
not been executed.

The source audit still verifies all 6,756 retained original test files/links
against the same inventory digest. `git diff --check` passes. Evidence for this
cleanup is workspace `tmp/otp-stage6-doc-unsupported-lh8faU/`, including
`verification.json`, configure/build/release/install logs, `staged-smoke.log`,
the exact removal/retention lists and `installation-refresh.json`.

`otp-build-tree` passes. The installed, DESTDIR, relocated and isolated checks
initially fail because their project-owned assertion expects every SDK source
asset. The release instead selects the original 23 preload source files; its
build-tree mirror retains all 26 SDK inputs. The existing Python filesystem
check now verifies these distinct inventories and every selected byte against
the SDK. Its first retry exposed an incorrect helper basename in the assertion;
that is corrected to `add_abstract_code`. No Python workflow is added to product
generation or the original Common Test preparation/execution/reporting path.

The subsequent `otp-installed` run passes that assertion, then fails compiling
installed `public_key/src/DSS.erl`: it includes `DSS.hrl`, which the release does
not ship. This follows the earlier Stage 6 removal of 30 generated source-header
extras. The immutable original portable release has the same missing header;
the current candidate build has the generated 344-byte header. This is review
evidence, not an exemption or a passing source-usability result. The other three
full installed checks have not been rerun after the inventory correction.

Resume Stage 6 with an explicit disposition for installed ASN.1 source usability:
retain generated source headers as justified additions, or validate the required
generation prerequisites using only installed schemas/tools in temporary space.
Do not silently skip the compile check or use build-tree headers. Full schema
import closure is not established by the single DSS example. Final payload
reconciliation and complete installed/relocated/isolated checks remain pending;
the independent Stage 5 checklist also remains pending.

## Final payload review, DSS verification and qualification gate

The user approved the installed-only DSS generation prerequisite and resumed
Stage 6. The project-owned check now generates `DSS.hrl` from the installed
`public_key/asn1/DSS.asn1` using the installed `erlc` and the original
`-bber +der +noobj +asn1config` options. It compiles the unchanged installed
`DSS.erl` with only that temporary include directory. It checks the output
BEAM's compile-info source path, hashes the tools, inputs, header and output,
and verifies the installed inputs remain unchanged. Generated source and
inspection bytecode never enter the runtime code path. Ordinary source probes
retain their strict compilation checks; no automatic header fallback is added.

The same frozen method passes against the maintained candidate and unchanged
original portable distribution. Both generate the same header SHA-256:
`001f14643b38d5a7cdfe6acd84bca550abf07f34f3bee70500541cd528cb7bf6`.
The schema SHA-256 is
`f1f98246610d901749efee24086863ed35195e55158b6e3f34a5e47414ed195c`.
The checked `tests/installed.py` SHA-256 is
`613a6d4e28629a93468768244c4c39b8f597cb12cfe08125220048da187829f9`.
Evidence is `dss-source-check-HEna51/{candidate,original}/` under the Stage 6
job. This proves selected installed-source regeneration/recompilation, not every
ASN.1 codec's import closure or full protocol behavior.

The final content audit passes 1,547 checks with no unclassified differences.
Three additional project-owned directory declarations reproduce the original
empty Mnesia/SSH include directories and ODBC `priv/obj`. Normal maintained
build, installation and explicit release assembly have been refreshed.

| Final portable-release comparison | Result |
| --- | --- |
| Reference / candidate entries, including directories | 3,679 / 3,617 |
| Recovered OTP/EI file gaps | 111: 106 byte-identical and five explained below |
| Remaining missing regular files | 53 VM-private payloads, omitted at the public SDK boundary |
| Remaining missing directories | 13 ancestors of private payloads and two empty unsupported documentation/man directories |
| Additional candidate entries | Six: publication lock, selected VM alias and four Common Test license/vendor records |
| Remaining mode differences | 58: 57 directory modes and the version-list file's reference group-write bit |
| Raw content differences | 1,464, each classified in the final matrix; no binary identity claim |

The five newly comparable differences are the two `proper_ext` BEAMs, relocated
Diameter parser, EI metadata and release example. The extension sources,
exports and compile-option multisets match the reference; compiler path metadata
differs. All 88 changed Diameter parser lines are original filename directives.
EI metadata records actual selected thread/link flags. The example uses the
installed SNMP version rather than upstream's undefined variable/empty string.
Every previously installed candidate byte is unchanged from the initial Stage 6
comparison except the separately approved corrected SNMPv1 resource.

All 36 application terms, both extension-module checks and selected EI consumer
checks pass. The EI consumer uses only installed public headers and the selected
archive/flags and completes a 28-byte ETF roundtrip. Ninety-four public headers
retain the original bytes or matching generated size values; 95 static EI source
payloads match exactly. Sixteen boot/release files match exactly, with only the
documented SNMP example difference. All 23 preload source files match the
reference bytes and mode 0644; all eleven native library modes are 0755.
Selected SDK/common/package artifacts are rehashed against the SDK manifest.
Stage 5's ASN.1 helper-renaming proof is bound to current installed/reference
source hashes; its unfinished Debug and broader native validation is unchanged.

The matrix and manifests are in
`tmp/otp-stage6-doc-unsupported-lh8faU/final-payload/`:
`manifest-final.json`, `verification-final.json` and `differences-final.json`.
The independent `final-source-output-audit.json` under the Stage 6 job verifies
all 6,756 original tests unchanged, all approved source differences, intact
reference/source snapshots, retained core/EI/NSIS inputs and unchanged 16 test
presets. Generated documentation remains absent, with runnable wx examples
preserved. No original source/test or SDK modification is introduced by this
DSS change or the directory declarations.

### Earlier qualification gate, resolved by the approved fixture revision below

| Check | Result before the approved fixture revision |
| --- | --- |
| Candidate/original installed-source probes | Both pass |
| Build-tree check | Pass |
| `otp-destdir` | Pass |
| `otp-installed`, `otp-relocated`, `otp-isolated` | Source/identity/DSS checks pass; each later fails two project EUnit assertions |
| Original installation, same unchanged project EUnit fixture | Four pass, two fail, zero skipped |

`filtered_warnings_as_errors_test` expects `nowarn_nomatch` to suppress the
diagnostic before `warnings_as_errors`; both installations return an error
containing the `sys_core_fold` no-clause warning. `ssh_hybrid_raw_secret_test`
expects the leading-zero boundary digest beginning `59c40f2b`; both return the
value beginning `507620c2`. The fixture is project-owned and unchanged since
commit `3342fcb`; these are not modified original OTP tests.

Raw candidate results are `final-distribution-checks.log`; the independent
original fixture commands, identities and raw outcomes are in
`original-project-eunit-jZrTwQ/`. **Matching upstream failures are evidence for
review, not automatic exemptions.** At that checkpoint the fixture remained
unchanged and no upstream behavior was patched. The full installed, relocated
and isolated checks remained nonpassing, and later portions of those controllers
were then unexecuted.

The payload/DSS work was complete, but the stage could not close until these
qualification expectations received a disposition. Work stopped for that review.
Stage 7 had not started. Documentation generation stays outside
supported scope, and the independent Stage 5 pending checklist is preserved.
Only Linux amd64 Emu Release is maintained here; JIT, Debug, macOS, Windows and
other host/toolchain qualification are not inferred. The native host is Linux
7.0.0-43-generic x86_64 with GCC 15.2.0, CMake 4.2.3 and OpenJDK 17.0.21.0.3.
No commit, push or publication was performed.

## Stage 6 completion after the approved project-test revision

The user selected preservation of pinned upstream behavior, reviewed the proposed
project-test contract, and explicitly approved both replacements. Only the
project-owned fixture and its documentation changed in this closing step;
original product sources, original suites, installed SDK and runtime payload
remain unchanged. This is a reviewed delivery-test contract change, not a fix
to the observed upstream behaviors or an automatic waiver of failed cases.

`compiler_warning_options_test` now verifies filtering without combining the
filtered-success case with `warnings_as_errors`. It retains executable-chunk
equality, checks clean source succeeds with warnings as errors, requires an
actual unrelated unused-function diagnostic to fail, and preserves the
syntax-error negative control. These checks follow the pinned compiler's
separate option coverage.

`ssh_crypto_public_api_test` verifies installed SSH/Crypto module origins, a
nonempty public SSH key-exchange algorithm list and both fixed public Crypto
X25519 vectors. Exact public keys, 32-byte secrets, reciprocal equality and the
leading-zero boundary remain strict. The private AST proxy, three proxy helpers
and hybrid digest expectations are removed. This is public API/native-library
delivery coverage; it does not claim SSH hybrid key-exchange conformance or the
previous combined warning-filter/error behavior. No skipped/expected-failure
branches or compatibility aliases are added; six EUnit cases remain.

The frozen fixture SHA-256 is
`fe5e24468315faa598d3f5bf03bb81d669ad00e8edadb516fa5146c5de29cd65`.
Candidate and original installations each compile it and pass all six cases,
with zero failures/skips. Complete command environments, input/tool/output hashes
and raw logs are in `public-api-project-eunit-2VVRBP/direct-summary.json` and the
two `direct/result.json` receipts under the Stage 6 job. The original failed
fixture and outcomes remain in the earlier Git revision and job evidence.

| Closing check | Result |
| --- | --- |
| Maintained normal build | Pass; unchanged build has no work |
| Candidate/original revised EUnit fixture | Both six passed, zero failed/skipped |
| Candidate/original installed DSS/source probes | Both pass; matching generated header |
| `otp-installed` | Pass, 16.15 seconds |
| `otp-destdir` | Pass, 10.72 seconds |
| `otp-relocated` | Pass, 14.16 seconds |
| `otp-isolated` | Pass, 16.02 seconds |
| Final payload audit | 1,547 checks passed; no unclassified differences |
| Original test/source preservation | All 6,756 tests and retained-source identities unchanged |

The four integrated CTests complete in 57.05 seconds with zero failures. The
previously blocked Common Test, native/process, restart, peer and generated-boot
portions of those controllers now execute successfully. Raw output is
`closing-distribution-checks.log`; the project keeps the corresponding per-mode
logs under the maintained build's `tests/logs/` directory. Earlier failures are
preserved and superseded, not rewritten as successful executions.

The closing source audit `closing-source-audit.json` binds the frozen fixture,
helper and live project inputs to HEAD
`0a2dd6cd03a479eae9145633e3dcfe6cf77c65d7` plus the recorded working-tree hashes.
All original-source/test and reference identities remain stable. The original
Stage 2 source/reference inputs are preserved. Retired task-owned documentation
working copies were removed after checks; logs, proposals and receipts remain,
as recorded in `retired-doc-work-cleanup.json`.

The maintained Linux amd64 Emu Release build, installation and portable release
are current. This stage changed no SDK variant; selected SDK hashes are verified.
There are no
other maintained OTP builds/installations here to refresh; no JIT/Debug,
macOS/Windows, older-glibc or other-distribution qualification is inferred.
Full original application/emulator/system qualification belongs to the later
stages. The approved private-fixture exclusions and all Stage 5 pending work
remain in force. Documentation generation stays outside supported scope.
Stage 6 stops here for review; Stage 7 has not started. No commit, push or
publication was performed.
