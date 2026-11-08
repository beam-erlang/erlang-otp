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

`upstream-binary_module_SUITE` executes the complete unchanged binary-library
selection, including its reference implementation, argument diagnostics and
documentation examples. The runner copies and compiles `binref.erl`,
`random_iolist.erl` and `error_info_lib.erl`; binary-module documentation comes
from the installed product. Its 16,200-second execution limit and 16,320-second
CTest limit leave room for the original per-case timetraps without narrowing
the selection.

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

The complete collection/text acceptance selections include `lists_SUITE` (78),
`maps_SUITE` (32), `string_SUITE` (45) and `unicode_SUITE` (19). The runner stages
unchanged helpers and Unicode property/normalization data. New outer limits
preserve upstream case timetraps; these suites run serially. Unicode acceptance
also compares the native UTF-16/32 contracts with the unchanged ordinary fallback,
including nested remainders and partial sequences.

ETS acceptance registers the unchanged complete `ets_SUITE` (162 cases and
groups), `ets_tough_SUITE` (one case with the original iteration defaults) and
`ets_property_test_SUITE` (four properties). ETS stages its upstream helpers and
data, including `error_info_lib` and `erts_test_utils`, and preserves doctest
metadata and source-integrity checks. Outer/CTest limits are 43200/43320 seconds
for ETS and 600/720 for tough/property. These suites run serially. Without a
verified property framework, retain the original prerequisite skip and report
the four properties as unexecuted/nonpassing; registration is not execution.
The SDK-owned VM report separately runs both `match_spec_SUITE` trace-session
groups and its flat cases, with 46 occurrence paths and 3600/3720-second limits.

### Erl_Interface

Registered complete suites are `ei_encode_SUITE`, `ei_decode_SUITE`,
`ei_decode_encode_SUITE`, `ei_format_SUITE`, `ei_print_SUITE`,
`ei_connect_SUITE`, `ei_accept_SUITE`, `ei_tmo_SUITE`, `ei_global_SUITE`,
`erl_call_SUITE` and `port_call_SUITE`. The usual `upstream-<suite>` CTest entries
use the installed candidate and original sources/assertions. Preparation copies
and hashes native sources, runs the original `init_tc` generator through the
candidate, and builds native runners/driver against installed OTP headers and
`libei`. A private EPMD serves real candidate-node communication; no running
system service or external compiler runtime is used. `otp-ei-interop` additionally runs both standalone candidate archives against
an explicitly selected, provenance-verified original node. It sends UTF-8,
64-bit integer, binary and exported-fun values through real RPC and decodes the
returned terms. The reference identity is recorded separately.
Failures and skips retain their raw case results.

`ei_tmo_SUITE:ei_connect_unreachable_tmo` requires an explicitly selected
unreachable host. Set `OTP_EI_UNREACHABLE_HOST` (or the runner's
`--ei-unreachable-host`) to supply the original `test_host_not_reachable`
configuration. The unchanged case checks reachability before exercising the C
connection timeout. Without that prerequisite it remains auto-skipped and the
suite's qualification result remains nonpassing.
