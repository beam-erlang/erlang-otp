# Linux amd64 Stage 3: original-helper pilot

On 2026-11-16, the representative preparation/execution proof passed on the
installed project Emu Release distribution and the unchanged upstream Emu
Release reference. At that review, Stage 3 was complete and Stage 4 had not started. This is bounded
evidence, not full application/emulator/system or four-configuration qualification.
Stage 4 retired the four pilot implementation files and their separate guide.
Their implementation remains in Git commit `e87929d82224d221877b8881b721b31d0cd2bf4f`.
The [current testing guide](../otp-tests.md) describes their maintained successor.
This record is documentation and is never an executable harness input.

## Identities and environment

The original input pin is OTP 29.0 commit
`550d7b7898706c7822362c42e7b93120c1d1f29a`. Both executions used the same Git
archive inputs and the same three normally generated upstream Make inputs.
Each verified that all 1,083 original extracted input files retained their
contents. Normal upstream generation produced the additional test sources,
Emakefiles and fixture outputs. No upstream-origin source, suite or recipe was
manually modified.

The candidate uses SDK 17.0, Emu Release, with these identities:

| Identity | Value |
| --- | --- |
| SDK source | `fc45b1dba20033afebee1fa282d442d2dce1c8c4d42ad70ddc48e112147c518b` |
| SDK build | `d1dee3abf93914a1867abfd5da707940be93fdcaeb26745fc3d2a69dbc4ddbe2` |
| SDK toolchain | `21257f2875b9c46260561276e5313041cd7be4d463fefec85a00e8415184aea2` |
| Candidate VM SHA-256 | `2626627bc5c77867796a7ba5aaa3e17bbf8c1c4011a26cf34c7915dc271ec1b2` |

All 65 declared artifacts of the selected installed SDK were rechecked against
its manifest. The installed `erl_driver.h` and `erl_drv_nif.h` used by the
native proof match their public SDK inputs exactly. No SDK files or BEAM/Erlang
sources changed.

The native host was Ubuntu 26.04.1 LTS, Linux `7.0.0-43-generic`, x86-64.
Selected tools included GCC `15.2.0-16ubuntu1`, GNU Make 4.4.1, Binutils 2.46,
and Javac 17.0.21.0.3. Artifact hashes and resolved tool paths are in the run
evidence. No other distribution, older glibc, JIT, Debug, macOS or Windows
qualification is inferred.

## Executed and measured coverage

| Selection | Candidate | Upstream reference |
| --- | ---: | ---: |
| Complete original EUnit specification | 15 passed | 15 passed |
| Crypto engine loading/registering and listing | 2 passed | 2 passed |
| Kernel public-driver sequence-trace controls | 2 passed | 2 passed |
| Compiler `andor` base and three generated variants | 12 passed | 12 passed |
| Compiler `lfe_andor` from Core | 3 passed | 3 passed |
| Emulator `bs_bincomp` base and two generated variants | 9 passed | 9 passed |
| Total | 43 passed | 43 passed |

Both successful runs had zero failed cases, skipped cases, callback failures,
selection discrepancies or incomplete event logs. The focused Compiler group
retained its original parallel behavior; raw event order remains recorded.
Matching outcome multiplicities do not impose a new serial order on that group.
The emulator selections are diagnostics, not the canonical ordered corpus.

Original packaging generated all 275 Compiler and 17 emulator variants. Their
generated source bytes match the pinned inputs under the original module-renaming
recipe, with Core inputs retained unchanged. The released EUnit, Compiler and
emulator Emakefiles are byte-identical between the two runs. Eight selected BEAM
outputs match their original recipe options and CT additions through an
in-memory compiler metadata oracle. Their candidate/reference metadata also
matches after replacing only the known installation/work prefixes. This is not
semantic execution coverage for all generated variants or BEAM byte identity.

Crypto has no native data-directory recipe at this pin. Its engine check uses
the installed product component. Kernel's unchanged `echo_drv` recipe supplies
the public-SDK native preparation proof instead.

Original `ts:install` and `ts:compile_datadirs` build that driver successfully on
both installations. Compiler/link commands match after installation/work prefix
substitution and use only installed public headers. No private VM header, EI
archive or SDK runtime archive is consumed. Driver load, echo, close and unload
checks pass. Both outputs are x86-64 ELF64 shared objects, mode `0775` in this
execution envelope. Their `.text` dumps, dynamic symbols, dynamic tables and
compiler comment sections match exactly. Full binary hashes differ; recorded
DWARF paths and build IDs differ. No full binary identity is claimed.

## Strictness and lifecycle evidence

The result adapter passed nine positive/negative self-checks and two additional
reader mismatch checks. In particular, an original CT result of
`{1,0,{0,0}}` accompanied by a failing cleanup callback is rejected. Explicit
failure, skips, zero tests, empty selections, invalid expectations, truncated
events, false statistics and incorrect selected-case identities cannot pass.
The nine existing harness CTests also pass. The existing preparation/execution
path remains available and was not retired or reworked.

The first executed pilot attempt preserved one EUnit peer timeout and two
rejected multi-suite/case requests as failures. Project adapter corrections
made EPMD reachable through this host's `127.0.1.1` name and issued one focused
CT request per suite. No upstream assertion, callback or deadline changed.
The successful runs used a task-owned EPMD on nondefault port 43691, bound only
to `127.0.0.1` and `127.0.1.1`; distribution also used loopback. Its registry
was empty after both runs and the foreground listener was stopped normally.

## Differences and next review

The original helper route replaces recipe interpretation with the original Make,
Erlang and CT implementations. The pilot still owns explicit selection, staging,
environment setup, evidence checks and measurement code. It does not reproduce
the complete `ts:run` child-controller/preinitialization workflow. No new Python
core or CMake logic was added.

Two existing differences remain open for migration review:

- Legacy Python preparation adds `compressed` to emulator variants whose
  original Emakefile omits it.
- The CMake fixture translator uses different flags, definitions, include paths
  and link policy from the observed original native recipe. In this driver
  example, upstream uses configure-derived `-g -O2`, PIC and thread definitions,
  and links with `gcc -shared` without explicit libraries.

These findings are not exemptions. Stage 4 must review the retained unchanged
support closure and generalize the proven path before replacing legacy duties.
Linux SSL/OS_Mon lifecycles and the absent Diameter `Makefile.ca` remain later
work. `mtx_SUITE`, `ethread_SUITE` and `erl_print_SUITE` remain intentionally
unexecuted under the agreed Linux scope; no private fixture package is required.

Per-run inputs, reports, commands, raw CT logs and paired comparisons are retained
for review under workspace `tmp/otp-stage3-pilot-9T1ZH5/`. Successful executions
are `candidate-2/` and `reference-1/`; `candidate-1/` retains the failed attempt.
Controller probes are under `tmp/otp-stage3-pilot-ct-check-QOjb6c/`. These are
temporary evidence locations, not build or test dependencies.
