# Tests

CTest runs a named command and records whether it passes or fails. A CTest
entry can run one small check or an entire collection of Common Test suites.
For example, `otp-erts-emulator` is one CTest entry that runs the ordered
emulator test collection.

There are two main groups:

- **Project checks** test our CMake build, SDK integration, installation and
  test controller.
- **Original OTP tests** exercise application and runtime behavior using the
  original specifications, suites and helpers.

These cover different things. An installed runtime can pass the emulator tests
while a build-directory launcher selects the wrong compiler or a relocated
installation fails to start.

## Routine project checks

The normal configuration registers these ten CTest entries:

| CTest name | What it checks |
| --- | --- |
| `otp-build-tree` | The build directory works: product/bootstrap launchers select the intended VM and compiler, application outputs are consistent, and selected native libraries load. Also checks build-command handling and cleanup of owned outputs. |
| `otp-installed` | A fresh installation made by our installer has the expected contents and passes bounded command, application and native-extension checks. |
| `otp-destdir` | Installation into a packaging staging directory produces the expected layout and usable product. |
| `otp-relocated` | The installation still works after moving it to a different path, including spaces and Unicode. |
| `otp-isolated` | The installed product works with access to its producer source, build and SDK directories denied. |
| `otp-original-cases` | A small selection of unchanged Compiler, time, timer and `erl_call` cases provides early feedback. |
| `otp-sdk-selection` | Configuration accepts valid installed SDK selections and rejects missing, conflicting or malformed selections. |
| `otp-native-architecture` | Configuration detects incompatible host, compiler and SDK architecture choices and unsupported build configurations. |
| `otp-atomic-install` | Installation publication, replacement and failure handling preserve the intended installation and output ownership. |
| `otp-test-controller` | Our OTP test adapter detects failures, callback errors, invalid selections, missing generated suites and incomplete or inconsistent evidence. |

Windows also registers `install.windows-publication` for its installation
publication mechanism.

The installation checks deliberately repeat some functionality under different
conditions. Their purpose is to test delivery of the product. `otp-original-cases`
overlaps the complete original suites; its distinct value is quick feedback.
Passing these routine checks does not establish complete OTP test coverage.

Python orchestrates the build/installation/configuration checks. The OTP test
controller uses Erlang and Common Test. These are project-owned checks of the
machinery we introduce; they are not additions to the original OTP suites.

## Original OTP tests

These entries are optional because they can be expensive and require additional
inputs and services:

| CTest name | Scope |
| --- | --- |
| `otp-app-<application>` | Complete original main specification for one of the 35 applications; for example, `otp-app-kernel`. |
| `otp-erts-emulator` | Complete ordered emulator collection in one controller VM, preserving cross-suite state. |
| `otp-erts-system` | Complete system collection, including its final cleanup suite. |
| `otp-erts-epmd` | Supplemental original EPMD tests. |
| `otp-erts-yielding-c-fun` | The original ordinary yielding-C shell regression driver. |
| `otp-suite-<domain>-<suite>` | One independently selected suite; for example, `otp-suite-compiler-andor_SUITE`. |

Configuration options control registration:

| Option | Registers |
| --- | --- |
| `OTP_ENABLE_TEST_SUITES=ON` | All 35 application entries, four ERTS entries, and full-run bookkeeping. |
| `OTP_ENABLE_ERTS_TESTS=ON` | The four ERTS entries independently of the application collection. |
| `OTP_ENABLE_INDIVIDUAL_SUITES=ON` | Individual `otp-suite-*` entries, including generated variants. |

All three options default to `OFF`. Enabling both application and ERTS options
registers each ERTS component once. Registration does not supply prerequisites
or establish that a test has passed.

Two additional CTest entries support the complete run:

- `otp-tests-start` creates the current test session.
- `otp-tests-reconcile` checks that all 39 component reports belong to that
  session and contain complete, consistent evidence.

Selecting one application automatically runs session setup when required; it
does not run all other applications or reconcile a partial run. Individual
suite execution is for diagnosis and cannot substitute for a complete run.

## Running and selecting tests

Run commands from the repository root after building and installing the
selected configuration. There is one public test preset per build configuration.
The preset selects routine checks and excludes the optional full and individual
suite entries.

```sh
# Routine checks for this configuration.
ctest --preset linux-x86_64-emu

# One routine check.
ctest --preset linux-x86_64-emu -R '^otp-build-tree$'
```

For optional entries, use the configured build directory directly. The examples
assume the corresponding registration options and required inputs are present:

```sh
build_dir=/absolute/path/to/configured-build

# List registered tests without executing them.
ctest --test-dir "$build_dir" -N

# One application, the emulator collection, or one individual suite.
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error -R '^otp-app-eunit$'
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error -R '^otp-erts-emulator$'
ctest --test-dir "$build_dir" --output-on-failure --no-tests=error -R '^otp-suite-compiler-andor_SUITE$'

# All 39 original OTP components and report reconciliation.
cmake --build "$build_dir" --target otp-tests
```

`otp-tests` is a build target that invokes CTest, not another CTest test name.
The `full` label selects complete-run entries; `erts` selects ERTS entries;
`suite` selects individual suites. The routine preset excludes these labels,
so adding `-L full` to that preset does not enable the full run.

Execution is currently serial. Keep experimental configurations and disposable
test output in workspace `tmp/`; maintained builds and installations stay in
their supported preset directories.

## Results and further reading

Missing prerequisites, permission failures, unexplained skips and callback
failures remain nonpassing. Read the relevant logs and reports rather than
treating a registered test or a partial successful run as complete acceptance.
Each host, architecture, Emu/JIT flavor and Release/Debug build needs its own
execution evidence.

- [Distribution checks](../docs/testing.md): detailed coverage, isolation and logs.
- [OTP test controller](../docs/otp-tests.md): source/SDK selection, preparation,
  group/case selection, reports and current execution limits.
- [Test prerequisites](../docs/test-prerequisites.md): required tools, services,
  historical releases and graphical environments.

CTest registration is defined in [CMakeLists.txt](CMakeLists.txt) and
[OTPTests.cmake](../cmake/OTPTests.cmake). Original application and ERTS suites
remain in their source-local `lib/**/test` and `erts/**/test` directories.
