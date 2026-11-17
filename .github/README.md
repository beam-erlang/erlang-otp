# GitHub Actions

`linux.yml`, `macos.yml` and `windows.yml` run independently on pushes and pull
requests to `master`, and by manual dispatch. Each uses its native runner and
four presets: EMU/JIT in Release/Debug.

Each workflow checks out OTP normally and BEAM/Erlang at `sdk-bootstrap-dirty`,
builds and installs the selected SDK, then configures OTP through
`BEAM_SDK_ROOT`. It builds, runs the default CTests, installs, packages the full
installed distribution, and smoke-tests the extracted package. Build and
validation output stays under workspace `tmp/`.

Downloads are Actions artifacts: versioned Unix `.tar.gz` distributions,
Windows `.zip` distributions, SHA-256 checksums, and the primary Windows JIT
Release installer. Linux JIT Release also packages source.
Failure diagnostics include CMake/CTest logs and the SDK selection receipt.

The Windows Release installer uses `otp_installer` and omits the optional
documentation component. It produces `packages/otp_win64_<OTP_VERSION>.exe`
in the build directory. Generating the complete original OTP documentation is
unsupported; CI does not build or publish generated documentation archives.

`otp-tests.yml` manually tests one explicitly selected native configuration on a
provisioned self-hosted runner. Supply its preset, matching runner labels,
installed public SDK, original OTP Git repository, matching configured source,
prerequisite/service input profile and native CMake executable. The
`cmake_selectors` JSON object supplies literal CMake cache values for dependencies
and tools: `CMAKE_C_COMPILER`, `CMAKE_CXX_COMPILER`, `PERL_EXECUTABLE`,
`OTP_TEST_MAKE`, `OTP_TEST_GIT`, `OTP_TEST_TAR`, `OTP_TEST_CLANG` and
`OTP_TEST_BASH` require absolute installed executable paths. Select OpenSSL, wx,
Java, Flex and ODBC through the product's native dependency selectors. Pipeline
configuration, output and test-selection settings are managed by the workflow.
Linux also needs bubblewrap, util-linux namespaces, iproute2 and OpenSSH
client/server/key tools. Select `OTP_TEST_BWRAP`, `OTP_TEST_UNSHARE` and
`OTP_TEST_IP` explicitly when the default installed paths are unsuitable.
The runner must permit the required private namespaces; CI does not disable host
security policy to obtain that capability. Full service/image and historical
inputs remain explicit prerequisites, not shared host-daemon fallbacks.

The job builds and installs that candidate, runs routine checks, then invokes
`otp-tests` for all 39 components and local report reconciliation. Missing inputs,
blocked tests, failures and empty selections fail the job. No dependencies or
services are installed implicitly. A successful invocation covers only its
selected configuration; it does not establish a platform/configuration matrix.
Native Linux, macOS and Windows executions need separate evidence.

The artifact contains the current reports and an archive of raw Common Test
events/logs, preparation/selection records, command logs, test-server variables
and CMake/CTest diagnostics. It excludes the copied source archives and released
test payloads. Linux requires explicitly selected GNU tar to retain raw filenames
and sparse CT fixtures inside the archive. Normal CI remains the bounded
distribution campaign and does not claim full original OTP compatibility.
Successful owned outputs are removed after artifact publication; failed work
remains on the selected self-hosted runner for diagnosis.
