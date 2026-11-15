# Testing the core distribution

The product and pinned acceptance inventory both contain 35 applications.
The complete original OTP selection has 39 components: those applications, the
ordered emulator and system corpora, EPMD, and yielding-C. Every platform uses
the same [Erlang preparation and controller](otp-tests.md). Registration
does not establish executed coverage; the default distribution checks below
cannot satisfy full acceptance.

Run `ctest --preset <preset-name>`, for example `linux-x86_64-emu`, after building
and installing the candidate. There is one public test preset per build
configuration; it selects distribution and controller checks. Upstream corpus
and diagnostic selections use the explicit entry points below.
Tests install into private
workspace `tmp/otp-*` roots, execute from unrelated working directories, sanitize
runtime/loader overrides and remove their own payloads and process groups. Logs
are bounded under `build/<preset-name>/tests/logs/` and CTest's `Testing/Temporary/`.
Loopback sockets are required for TCP, private EPMD and peer coverage. Permission
failures are failures, not skips.

Configuration checks the actual C and C++ compiler targets against the native
host and selected SDK on every configure, whether or not a preset is used. Use
the standard preset matching the host for maintained build and install outputs.
Both Release and Debug are supported for EMU/JIT. Run the corresponding
`-debug` preset for Debug; standard output directories remain separate. Runtime
identity checks cover the bootstrap and product VM, the installed/staged/moved
product, restart, and a peer. They require Release `{opt,false,false}` or Debug
`{debug,true,true}` for `{build_type,debug_compiled,lock_checking}` and verify
Debug's relative child-helper alias.

| CTest owner | Scope |
| --- | --- |
| `otp-build-tree` | Local and bootstrap launcher/compiler selection, unversioned application inventory, SDK preload inspection and architecture-specific native loading |
| `otp-installed` | All 35 application declarations/module files, bounded nine-application checks, installed command/identity checks, piped shell evaluation, `erlc` and installed source recompilation, literal escript arguments, EUnit, Common Test, file/zlib/Crypto/TCP, native hostname helper, child exit status, supervised worker replacement, NIF/driver loading and the RuntimeTools file driver, `init:restart`, two-node RPC and a generated boot script |
| `otp-destdir` | Staged installation followed by all-application identity, bounded nine-application, command and escript checks |
| `otp-relocated` | Move the complete private prefix to a path with spaces/Unicode, remove its original path, then repeat installed functionality |
| `otp-isolated` | Deny/hide producer source/build/SDK directories with an OS sandbox, verify those inputs cannot be read, then repeat installed functionality |
| `otp-original-cases` | The unchanged selected compiler, clock-mode, timer and native node-start cases below |
| `otp-sdk-selection` | Select the requested flavor/build type from individual or combined SDKs, accept the exact release independently of provenance, and reject unavailable choices, conflicting selectors, malformed metadata, unsafe runtime architecture metadata, and wrong releases before compilation |
| `otp-native-architecture` | Configure against the installed SDK without presets; probe Release/Debug C and C++ targets, reject incompatible flags on reconfigure, SDK/host architecture mismatches, cross-compiling, and unsupported multi-config/custom build configurations |

The bounded additions exercise a private Dialyzer PLT and command versions,
EDoc HTML/CSS generation and command, ELDAP ASN.1 controls, Diameter startup and
a generated dictionary, Megaco text/BER codecs, headless Reltool configuration,
a private loopback TFTP transfer, the ODBC manager's specific missing-DSN error,
and a Java ETF roundtrip through the installed Jinterface JAR. They require no
LDAP, Diameter, Megaco or database service. JDK tools are explicitly selected;
Java fixtures compile against installed artifacts before producer isolation and
execute afterward. These checks run in installed, DESTDIR, relocation and
isolation modes. They do not establish complete protocol, database, Java-node
interoperability or GUI coverage.

Installed-source probes recompile selected Stdlib and Compiler sources and the
installed Public Key `DSS.erl`. The original release omits the generated
`DSS.hrl`, so the check first uses the installed ASN.1 compiler and `DSS.asn1`
with the original `-bber +der +noobj +asn1config` options in fresh temporary
space. It then compiles the unchanged installed Erlang source using that header.
Input/output hashes and the compiled source path are recorded; inspection
outputs stay outside the runtime code path. This checks those selected sources,
not the prerequisite closure of every installed codec.

For the distribution refactor, run:

```sh
ctest --test-dir build/macos-arm64-emu --output-on-failure \
  -R '^otp-(build-tree|installed|destdir|relocated|isolated|sdk-selection|native-architecture|atomic-install)$'
```

The separate `otp-original-cases` owner is a bounded original-case selection.
`OTP_ENABLE_TEST_SUITES=ON` registers one `otp-app-<application>` CTest per
application, four ERTS components, and the session/reconciliation checks.
`otp-tests` runs that complete original OTP selection once. Together with
distribution checks, those reports are inputs to acceptance of each
Emu/JIT and Release/Debug configuration independently.

`OTP_ENABLE_ERTS_TESTS=ON` separately registers `otp-erts-emulator`,
`otp-erts-system`, `otp-erts-epmd` and `otp-erts-yielding-c-fun`. The
`otp-erts-prepare` and `otp-erts-check` build targets prepare and check this
retained corpus using installed candidates and public SDK interfaces.
See [the CTest interfaces](otp-tests.md#ctest-interfaces) for setup
and the explicit blocking prerequisites. A partial ERTS run is not green and
cannot establish complete acceptance.

Build-graph validation belongs in a task-owned workspace `tmp/` source/build
copy: verify an unchanged second build executes no compiler/generator jobs,
a leaf application edit preserves unaffected bootstrap/application outputs,
a missing generated source or final BEAM is recovered, and adding/removing an
explicit module updates build and installed contents. Verify that each build
record names the supplied bootstrap compiler, changing the final Compiler does
not rebuild unrelated applications, and hostile inherited runtime/compiler
settings cannot redirect compilation. Record source/SDK
identities and compare application/module/resource inventories, modes and
compiler metadata with the baseline. Keep temporary variants out of maintained
preset directories. This is a validation procedure, not a claim of a completed
run.

`tests/build_graph.py` runs these cases against the real 35-application build.
It copies source without Git/build/install output into workspace `tmp/`, uses
explicit dependency selectors, writes a JSON report, and removes its successful
disposable build. Failed work remains for diagnosis; `--keep-work` also retains
successful logs and outputs. For the configured macOS dependencies:

```sh
python3 tests/build_graph.py --source "$PWD" --preset macos-arm64-emu \
  --sdk "$BEAM_SDK_ROOT" --openssl "$OPENSSL_ROOT_DIR" \
  --wx-config "$OTP_WX_CONFIG" --java-home "$JAVA_HOME" \
  --odbc-config "$ODBC_CONFIG" --flex "$FLEX_EXECUTABLE"
```

To reuse a completed task-owned copy, supply `--scratch-source` and
`--scratch-build`, both under workspace `tmp/`, plus `--reuse-build`. The report
then records a supplied baseline instead of claiming another clean build. The
harness rejects tracked source directories and maintained builds. It installs
the added/removed-module cases into separate fresh private prefixes; this checks
the current install selection rather than asserting removal of obsolete files
from an earlier installation. This expensive check is manually invoked, not a
default CTest.

`otp-atomic-install` checks installation publication directly.
`otp-test-controller` checks adapter selections, Common Test event accounting and
report validation. Full report reconciliation belongs to the optional
`otp-tests-reconcile` entry. These machinery checks do not substitute for
executing the selected original OTP specifications.

Installed tests inspect emulator dependencies, reject a shared `libbeam` or
source/build/SDK loader dependency, reject symlinks escaping the installed root,
and verify application/code paths belong to the private installed product or
test fixtures. The build-tree mirror retains the complete selected SDK preload
assets. Installed preload bytecode matches the SDK, while installed sources
follow the original 23-file release inventory; every shipped byte is checked
against the SDK. Its additional `add_abstract_code`, `erts.app.src` and
`zip_internal.hrl` inputs remain in the SDK and build-tree mirror. Runtime
checks inspect all 22 preload modules for xref's abstract-code, attributes and
documentation request, logical documentation source paths and deployed sources,
and confirm that execution still uses the VM's embedded preloads. These checks
also run after relocation and producer isolation; DESTDIR checks cover the same
metadata through the installed identity check.
Native fixtures compile using only installed public headers,
without linking a VM. This proves the checked installed acquisition boundary;
`otp-isolated` separately uses macOS `sandbox-exec` or a Linux filesystem sandbox
to make producer source/build/SDK inputs unavailable. Linux first probes
Landlock in a child process, including actual ruleset enforcement. Its launcher
allows system files read-only, the `/dev/null` output sink, and the unique private
work directory read/write, without granting access to producer directories. When Landlock is unavailable,
the runner can use explicitly installed bubblewrap with usable user/mount
namespaces. Every backend must pass actual producer-read denial probes before
product checks run. A policy setup or command failure is a failure; it never
triggers a weaker retry. The sandbox preserves loopback access and does not
bundle the explicitly selected OpenSSL dependency.

The Linux private work directory needs a backing filesystem that supports the
selected Landlock policy, including reading and executing explicitly allowed
work files. For Docker Desktop validation, a private container tmpfs is suitable
scratch storage when a host-shared worktree denies those allowed accesses. For
example, mount `--tmpfs /workspace/tmp:rw,exec,nosuid,nodev,size=512m` for that
workspace layout. Keep producer source, build and SDK directories outside the
private scratch mount. This changes storage without adding capabilities or
widening the policy; a failed restricted launch still remains a failure.

On Linux, `python3 tests/test_landlock.py` independently checks producer-read
denial, read-only system files, private-work writes/renames, inherited policy
and ordinary command exit status. `otp-isolated` owns the complete installed
product check using that policy.

Source usability checks compile installed `stdlib/src/ms_transform.erl`,
`compiler/src/beam_opcodes.erl` and `public_key/src/DSS.erl`, covering ordinary
source headers, generated compiler headers and generated ASN.1 headers. Their
outputs stay in private `source-check/` output and never shadow product modules
on the runtime code path.

The installed EUnit fixture checks the real Stdlib stack filename and tests
compiler warning filtering separately from warning-as-error handling, matching
the pinned compiler's coverage. It checks installed SSH/Crypto module origins,
the public SSH default algorithm list, and fixed public Crypto X25519 vectors,
including a leading-zero secret, exact length and reciprocal equality. This is
public API and native-library delivery coverage; it does not establish hybrid
SSH key-exchange conformance. These checks run through the existing installation,
relocation and isolation owners without adding services or private-function
proxies.

## Selected original original OTP cases

The runner copies each original suite and its data into private writable output,
compiles the original helper modules with the installed compiler, and uses the
installed Common Test harness. Sources, assertions, case bodies and deadlines
remain unchanged. It records original suite SHA-256 values, rejects changed
inputs, and requires zero failures and zero skips for these exact selections:

- `compile_SUITE`: `file_1`, `forms_2`, `binary`, `makedep`.
- `time_SUITE`: `time_warp_modes` (including its original peer emulator flags).
- `timer_simple_SUITE`: `send_after1`, `send_after_invalid_args`, `cancel1`.
- `erl_call_SUITE`: `smoke`, `unresolvable_hostname`, including native same-host
  startup and the original forced-localhost fallback test flag.

Original `ts_install_cth`, compiler `test_lib` and `erts_test_utils` are retained
helpers, not replacement assertions. A selected-case pass establishes only that
case/context. The full original OTP suite corpus, unsupported applications, other
platforms and flavors remain untested until their own runs are recorded.

For individual-suite work, use `ctest --test-dir build/macos-arm64-emu -R '^otp-original OTP$'
--output-on-failure`, replacing the directory/test name as appropriate. Report
failures, raw skips and unexecuted checks separately. Do not weaken an original OTP
assertion, substitute a system runtime, or turn missing prerequisites into a pass.
