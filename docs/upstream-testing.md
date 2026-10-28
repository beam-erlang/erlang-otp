# Upstream test execution

Selected OTP 29 suites run through this product's source-built Common Test and
installed candidate commands. CMake/Python prepare copied fixture outputs and
isolation; behavioral assertions remain upstream-owned. The complete scope and
stop rules are in [compatibility](compatibility.md). Per-subsystem dependencies,
peers, GUI and resource requirements are in [test preparation](test-preparation.md).

## Build-mode execution

```sh
ctest --preset linux-emu --output-on-failure
ctest --preset linux-jit --output-on-failure
```

Use `ctest --test-dir build/<preset> -N` to inspect the actual registered
inventory. [OTPTesting.cmake](../cmake/OTPTesting.cmake) owns selections and
labels. The inventory includes focused product/boundary/lifetime checks and
selected application/ERTS suites; registration does not imply complete upstream
coverage. Disabled tests and missing dependencies remain visible and nonpassing.
Set `OTP_ENABLE_WX_TESTS=ON` when executing GUI acceptance.

For focused work, select an owning test with `-R`, for example:

```sh
ctest --preset linux-emu -R '^upstream-dirty_nif_SUITE$' --output-on-failure
```

A focused result covers only that selection. The configured matching installed
SDK supplies every candidate VM, including peers and subprocesses. An original
OTP installation is a separately identified reference/interoperability input,
never a fallback candidate compiler or runtime.

## Explicit installed comparisons

The runner also accepts an immutable installed selection with its complete
external provenance and private work root:

```sh
python3 tools/check_upstream.py --source "$OTP_SOURCE" \
  --prefix "$OTP_PREFIX" --provenance "$OTP_PROVENANCE" \
  --work-root "$WORK_ROOT/sendfile" --suite sendfile_SUITE \
  --inet-backend socket --schedulers 2
```

Repeat with independently selected matching original/reference inputs and each
flavor/backend. `--case` supports the runner's explicit sendfile, RAM-file heavy
and ODBC Unicode selections. Repeated `--case` preserves paired order. Diagnostic
sendfile `--strace` results are labelled separately; they cannot substitute for
uninstrumented execution. Prefix mode requires provenance and work root, verifies
the selected tree and uses private copies where filesystem isolation needs them.

The ET probe can reuse an attested installation:

```sh
python3 tools/check_et_event_file.py --source "$OTP_SOURCE" \
  --prefix "$OTP_PREFIX" --provenance "$OTP_PROVENANCE" --work-root "$WORK_ROOT/et"
```

Product fixture-only changes can similarly select installed input through
`tools/check_product.py --prefix ... --provenance ... --work-root ...`, together
with the required `--source`, `--sdk`, `--flavor` and compiler settings. Add
`--bwrap` for Linux filesystem isolation. Reusing a matching attested product
for fixture work does not qualify later changed native/runtime outputs.

## Source and outcome integrity

The harness copies and hashes original suite/helper/header/data inputs before
compilation. Reviewed setup adaptations are declared in
[upstream-test-adaptations.json](../tools/upstream-test-adaptations.json), tied
to the upstream pin and checked source digests. Missing original fixture
preparation is a failure; it does not authorize altered assertions or no-op tests.

Common Test terminal events retain case identity, execution context, repetition,
raw status/reason and suite/group configuration outcomes. Start/stop markers must
be present and agree with Common Test's independent aggregate. Configuration
failure cannot disappear behind passing case totals. `otp-upstream-evidence`
tests these integrity rules; [local qualification](local-qualification.md)
describes reconciliation, source-bound limitations and command controls.

Strict selected-suite gates require complete execution with no failures or skips.
Retain raw skips, disabled entries, failed prerequisites and untested scope
separately. Named local limitations require exact matching reference/supplemental
records; they do not rewrite raw outcomes. Historical passing results cannot
mask an unexpected current failure or certify another installed tree.

## Disposable output

Runners remove copied installations, compiled fixtures, private servers/data and
build products on success, failure and catchable interruption after stopping
owned processes. Existing selected input prefixes are never cleanup targets.
Bounded text diagnostics and `cleanup.json` remain with ignored build/CI output:
at most 8 MiB per run and 1 MiB per file. Oversized structured records are omitted,
not truncated into apparently complete results.

`BEAM_TEST_KEEP_WORK=1` is an explicit debugging override. Record retained
payload size/location and remove it after investigation. Inspect available disk
and estimate peak use before large cases; serialize heavy installations and
never remove another job's inputs. Reusable dependency packages stay separate
from mutable validation work. Product source/manuals do not retain development
run reports or reference disposable consumer inventories as release gates.
