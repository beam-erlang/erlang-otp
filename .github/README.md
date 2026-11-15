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
Release installer. Linux JIT Release also packages source and documentation.
Failure diagnostics include CMake/CTest logs and the SDK selection receipt.

The CI scope includes required Windows presets and `otp_windows_installer`,
plus `otp_docs` producing `doc/html/` and `doc/man/` in the build directory.
Those product interfaces remain follow-up implementation work; missing support
fails its workflow. The installer target produces
`packages/erlang-otp-<OTP_VERSION>-windows-amd64.exe` in the build directory.

`upstream-full.yml` retains the separate manual, explicitly provisioned upstream
qualification campaign. Normal CI uses the bounded distribution checks and
does not claim full upstream compatibility.
