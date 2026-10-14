# ODBC assembly

## Current local completion evidence (2026-10-27)

The restored PostgreSQL/psqlODBC cache supports the complete four-suite matrix
on candidate and pinned original OTP 29.0, independently on both flavors. The
initial repeated result is 91 passed, zero failed and 17 user skips on each
installation, matching the historical breakdown below. Explicit installed
selections now receive verified private copies before filesystem isolation;
the harness no longer assumes their original prefix is mounted in the namespace.

The Unicode group formerly inferred an old PostgreSQL driver from a 64-bit word
size. A test-setup correction now uses `SQLGetInfo(SQL_DRIVER_VER)` on the actual
private DSN. The selected driver reports `17.00.0007`; driver-manager and driver
hashes are retained. Unidentified drivers retain the legacy guard. All case
assertions and SQL Server-only `nchar`/`nvarchar` guards remain unchanged.

After this correction the complete data-type suite records 28 passed, zero
failed and 12 user skips on all four installations. UTF-8 parameter insertion
and retrieval pass; the two SQL Server-specific cases retain their own driver
skips. Combined with the separately recorded startup, connection and query
selections, each installation has 92 passes and 16 skips. This describes the
explicit selected runs, not a new broad product qualification result.

The [service evidence](evidence/otp-completion-20261027/services.json.gz) retains
the original matrix, independent unchanged Unicode selections, full corrected
data-type runs, raw reasons, preparation identities and cleanup. Query and type
strict gates remain nonpassing. Remaining driver/fixture restrictions require
individual classification and supplemental checks before local qualification.

## Historical assembly checkpoint

ODBC 2.17 builds its three retained product modules, application/upgrade resources
and public header. `odbc_debug` remains a retained development input, outside the
upstream product module inventory. The unchanged `odbcserver` port program links
the source-built Erlang Interface library and the system ODBC driver manager
selected by `find_package(ODBC REQUIRED)`. It uses no VM-private headers or symbols
and installs under `lib/odbc-2.17/priv/bin`; its C sources remain installed alongside
the application. The VM remains the selected SDK's sole `libbeam` implementation.

CMake probes `struct sockaddr_in6.sin6_addr` and supplies the corresponding
capability define. The retained helper tries IPv6 loopback before IPv4, matching
the Erlang side's listener selection. Omitting this probe initially produced
`connection_closed` before database communication; restoring the build definition
requires no source change. The product probe uses the public extended-error option
to check the driver manager's typed `IM002` missing-DSN diagnostic.

## Database acceptance environment

Building requires ODBC development headers and libraries. Database-backed testing
additionally requires an explicitly selected PostgreSQL 18 and psqlODBC package
root, configured with `OTP_POSTGRES_ROOT`. Tests do not install packages or change
host services. `tools/postgres_server.py` initializes and shuts down a disposable
cluster inside private user, process, network and filesystem namespaces. Only
system files, the selected database dependency, copied fixtures and the relocated
OTP installation are visible; SDK/source/build trees outside that work directory
are unavailable. No loader-path override is supplied to the candidate.

The Linux 64-bit DSNs expected by the unchanged PostgreSQL callback are provided
in a private `.odbc.ini`. Trust authentication and port 5432 are confined to the
private network namespace. The selected driver is `psqlodbcw.so`. The native
helper's unixODBC dependency remains an explicit system requirement of the product;
the acceptance database is not bundled into OTP.

Before each suite, an independent installed-product probe checks parameterized
insertion, selection, commit, rollback, disconnection and application shutdown.
It repeats over three OTP boots for each of the `inet` and `socket` backends.
The regular relocated/isolated product checks also exercise ODBC startup, native
helper discovery and missing-DSN diagnostics across restart.

## Upstream suite selection

All suite sources, helpers and assertions remain unchanged. The harness copies
and hashes the retained PostgreSQL callback, test library and headers, compiles
them with the installed candidate, and preserves original deadlines and selection.
The complete Linux selections are:

| Suite | Cases |
| --- | ---: |
| `odbc_start_SUITE` | 4 |
| `odbc_connect_SUITE` | 20 |
| `odbc_query_SUITE` | 44 |
| `odbc_data_type_SUITE` | 40 |

These 108 cases include native-helper loss, process ownership, transactions,
timeouts, cursor behavior, parameters and SQL types. Skips and external driver
limitations remain explicit coverage gaps; they do not pass the strict gate.
Other database/driver combinations and broader OTP compatibility remain unproven.

Both flavors report **91 passed, zero failed and 17 user-skipped cases**:
startup `{4,0,{0,0}}`, connection `{20,0,{0,0}}`, query `{40,0,{4,0}}` and
data types `{27,0,{13,0}}`. Both relocated/isolated product checks pass, as do
the database probes on both networking backends across three boots. Initial
product/startup runs failed before the IPv6 build correction described above;
the final matrix uses the rebuilt helper.

The query suite skips three multiple-result-set cases because its support
predicate accepts only SQL Server, and one PostgreSQL `tinyint` case. The
data-type suite skips four upper-bound cases marked “Limit unknown,” two
resource-heavy text-bound cases, two PostgreSQL `tinyint` cases, two bit cases
and three Unicode cases. Its Unicode guard checks the Unix word size and still
skips 64-bit runs with an old-driver explanation; it does not inspect the selected
17.00.0007 driver's version. These results do not establish that the modern
driver lacks Unicode support. Group setup/cleanup skip records are additional
log entries, not additional cases in the total of 17.

The strict query and data-type gates remain nonpassing. No source, fixture,
assertion, case deadline or platform predicate has been changed to suppress
these gaps. At this checkpoint, stage 4 and
[compatibility gates 2–5](../../dev-documents/otp-compatibility.md#completion-gates)
remained in progress.

## Source and artifact checkpoint

Sources are OTP `72a1beb074a9fb8481d652418db80255c2962008` and BEAM
`795e3ac7fa39433cce26bc979bd8889da324d52a`, with the recorded uncommitted work.
SDK identities and runtime hashes remain those in [Diameter evidence](diameter.md).
This increment changes no retained ODBC implementation, upstream test inputs,
bootstrap seeds or VM/SDK implementation.

Both installations contain 30 application entries and 997 BEAM files. All 994
preceding files remain byte-identical; all execution-chunk sets match across
flavors. The native helper imports no private VM symbols and has no `libbeam`
link dependency: its communication with Erlang uses sockets and ordinary ports.
Shared-runtime, playground and matching GLM acceptance is carried forward from
the unchanged SDK checkpoint, not represented as newly executed validation.
Five application entries and broader compatibility remain pending.

The driver manager is unixODBC 2.3.14. Database acceptance uses PostgreSQL 18.6
and psqlODBC 17.00.0007, extracted into scratch from these packages:

| Package | SHA-256 |
| --- | --- |
| `postgresql-18_18.6-0ubuntu0.26.04.1_amd64.deb` | `0536716204dee9152dee758c252936ba41c93b7330395f8abb0c5b86558aa658` |
| `postgresql-client-18_18.6-0ubuntu0.26.04.1_amd64.deb` | `c46d1ace8f7d84a9648c63b566fff799b7ee3281db46ef6e7b99baf0fd7bd2e4` |
| `odbc-postgresql_17.00.0007-1_amd64.deb` (epoch 1) | `cde7e08cfddaad84c7924c3cbc57b8a63604a1d89c3ed7aca2696100395f6e5a` |

No package maintainer scripts or system service installation are executed.
The CMake project contains no scratch-path default.

## Reproduction

Configure both flavors with their matching installed SDK and the explicit
database package root, then build and run:

```sh
ctest --test-dir build/linux-emu -R '^(initial-product|isolated-product|upstream-odbc_(start|connect|query|data_type)_SUITE)$' --output-on-failure
ctest --test-dir build/linux-jit -R '^(initial-product|isolated-product|upstream-odbc_(start|connect|query|data_type)_SUITE)$' --output-on-failure
```

Per-run `checks/upstream/<suite>-*/result.json` records exact inputs, SDK and
database dependency identities, case results and skip reasons. The database
setup/server logs remain with that run. Workspace scratch evidence uses
`tmp/otp-odbc-{build,check}-{emu,jit}.log` and `tmp/otp-odbc-artifacts.json`.
