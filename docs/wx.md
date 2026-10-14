# wx assembly

## Local completion work

The [local completion direction](../../dev-documents/otp-completion.md) reopens
Linux x86-64 wx and dependent desktop acceptance. The current repair removes
`g_log_set_writer_func` from the unloadable wx NIF: GLib requires the host
program to own its single process-global writer. GTK diagnostics continue
through the program's writer or GLib's default. See the
[GLib logging contract](https://docs.gtk.org/glib/func.log_set_writer_func.html).
Both-flavor validation of this repair remains pending. Child-process ownership,
PID-namespace cleanup and guided visible acceptance remain separate work.

## Historical authorized deferral

wx compatibility work and acceptance are deferred by maintainer direction.
The existing build and artifacts remain available. CMake registers the unchanged
checks as disabled by default (`OTP_ENABLE_WX_TESTS=OFF`), with `wx` and
`deferred` labels; they are not passing acceptance. Set the option to `ON` to
run them explicitly. Native reload, GTK child-process policy and manual OpenGL
coverage remain unresolved as detailed below. No signal, sandbox or native
lifetime workaround has been applied.

Other applications continue to be assembled and tested without a GUI. Their
wx-dependent GUI coverage is deferred separately; the missing Debugger resource
belongs to Debugger assembly and remains in scope. Reopening wx needs a direction
decision about native lifetimes and the GUI dependency/child-process boundary.

## Assembly and historical validation

The BEAM-private PCRE symbol collision is corrected and both-flavor shared-runtime
acceptance passes. Three unchanged wx suites pass (28 cases per flavor), while
native restart, GTK child-process integration, one application resource and
manual OpenGL coverage remain unresolved. These gaps keep wx acceptance incomplete.

wx 2.6 uses the release archive's retained generated bindings: 236 generated
Erlang modules plus five handwritten modules, compiled together with their
matching native dispatch tables and headers. The normal upstream release build
also consumes these committed bindings; it does not regenerate them from the
host's wxWidgets headers. CMake expands `%GEN_MODS%` into the application resource
in the build tree, preserves `CAN_BUILD_DRIVER`, and installs sources, public
headers, upgrade resources, examples and the licensed logo assets.

`wxe_driver.so` and `erl_gl.so` are ordinary NIF libraries despite the former's
historical name. Both compile through the installed `BEAM::NIF` target, without
private VM headers, copied runtime implementation or an alternate VM. The first
owns wxWidgets/GLib integration; the second owns OpenGL/GLU bindings. Native
libraries install directly under `lib/wx-2.6/priv`, as the retained Erlang loader
expects. CMake preserves the GL type and GLU callback probes and the upstream
choice to omit optimization for large generated wx wrappers.

The current Linux build requires wxWidgets 3.2 with STC, XRC, HTML, XML, core,
base, OpenGL, AUI and WebView support, plus GLib and OpenGL/GLU development
dependencies. Select a nonstandard wx installation through the normal CMake
`wxWidgets_CONFIG_EXECUTABLE` dependency setting. These third-party libraries
remain explicit runtime dependencies; BEAM self-containment does not mean
bundling the operating system's GUI libraries.

## Graphical acceptance

`tools/display_server.py` starts an explicitly selected Xvfb with TCP disabled,
inside private process, user, network and filesystem namespaces. A fresh private
`/tmp` contains its display socket. Neither the user's active display nor its
session bus is inherited. Only copied fixtures, the relocated installation and
system dependencies are mounted; original SDK/source/build files outside that
work directory are unavailable. Mesa software rendering is selected explicitly.

The independent `wx-product` check creates and edits widgets, verifies show-event
delivery, renders with OpenGL and attempts three OTP boots. Its first cycle
passes; native reload after `init:restart` fails. This check remains enabled and
nonpassing. Upstream suites run in separate fresh processes under the same
isolated display wrapper, so a product restart failure does not prevent their
unchanged assertions from executing.

The harness selects all six unchanged upstream suites:

| Suite | Cases |
| --- | ---: |
| `wx_app_SUITE` | 6 |
| `wx_basic_SUITE` | 17 |
| `wx_event_SUITE` | 14 |
| `wx_class_SUITE` | 18 |
| `wx_xtra_SUITE` | 5 |
| `wx_opengl_SUITE` | 3 |

Suite/helper sources and fixtures are copied and hashed, then compiled by the
installed candidate. Original assertions, deadlines and interactive guards stay
unchanged. In particular, the OpenGL suite requires a manually supplied user
configuration; the harness does not pretend that a user is present. Its skips
remain separate from the independent automated OpenGL probe. Human interaction,
WebView behavior, other display servers and hardware rendering require further
coverage; application assembly alone does not establish full GUI compatibility.

## Reproduction

Build each flavor against its matching installed SDK and GUI dependencies.
CTest discovers Xvfb through `OTP_XVFB`; it can also be selected explicitly.

```sh
cmake -S . -B build/linux-emu -DOTP_ENABLE_WX_TESTS=ON
cmake -S . -B build/linux-jit -DOTP_ENABLE_WX_TESTS=ON
ctest --test-dir build/linux-emu -R '^(initial-product|isolated-product|wx-product|upstream-wx_(app|basic|event|class|xtra|opengl)_SUITE)$' --output-on-failure
ctest --test-dir build/linux-jit -R '^(initial-product|isolated-product|wx-product|upstream-wx_(app|basic|event|class|xtra|opengl)_SUITE)$' --output-on-failure
```

Completed runs write `checks/upstream/<suite>-*/result.json`. The original PCRE-failing
runs have `preparation.json`, `execution.log` and `xvfb.log`, but no result file:
the probe fails before Common Test executes. Do not treat absent results as skips
or successful cases.

## Original PCRE symbol-boundary blocker

Both `linux-emu` and `linux-jit` build and install 241 wx modules and the two
native libraries. The product now contains 31 of the 35 application entries
(plus the ERTS resource) and 1,238 BEAM files. All preceding 997 BEAM files retain
their hashes. Retained wx sources, tests and bootstrap are unchanged. The build
uses wxWidgets 3.2.9, GLib 2.88.0, GLU 9.0.2, Xvfb 21.1.22 and Mesa 26.0.8.

Expected behavior is ordinary GTK-backed widget creation through the public NIF
contract. The original observed behavior was SIGSEGV during `wxTextCtrl:new`, before suite
execution. Independent debugger runs for both flavors show this call chain:

```text
pcre2_match_8                     relocated OTP/lib/libbeam.so
g_match_info_next                 system libglib-2.0.so.0
g_regex_match_full
g_regex_match_simple
...                              GTK im-ibus.so
wxTextCtrl::Create                system wxWidgets
wxTextCtrl_new_3                  retained wxe_wrapper_7.cpp:1126
...                              wxe_main_loop
```

Before correction, `libbeam.so` exported its vendored `pcre2_match_8` and other PCRE symbols. GLib's
standard PCRE call resolves to this Erlang-integrated implementation.
[`ThirdParty.cmake`](../../beam-erlang/erts/emulator/cmake/ThirdParty.cmake)
builds the static PCRE library with `ERLANG_INTEGRATION`; originally its exports
were unrestricted when linked into `libbeam`. In
[`pcre2_match.c`](../../beam-erlang/erts/emulator/pcre/pcre2_match.c), the match
entry dereferences `match_data->restart_data`, which is Erlang-specific state;
the disassembly locates the fault at that dereference. Standard GLib-created
match data does not satisfy this private contract. This is a confirmed shared
library interoperability defect, not an upstream wx assertion failure.

Source HEADs are `795e3ac7fa39433cce26bc979bd8889da324d52a` for BEAM and
`72a1beb074a9fb8481d652418db80255c2962008` for OTP, with the existing uncommitted
SDK/distribution work and new wx build/harness files. No BEAM implementation was
changed for wx; the SDK artifacts are unchanged from the Diameter checkpoint.

| Flavor | SDK build identity | Installed libbeam SHA-256 |
| --- | --- | --- |
| Interpreter | `15f28180d06c73b32555c6cb5e8d48c56abcaf95b596da100f4785a881c2c3f5` | `0f47af28d46c680e346682696bb1d619823bfcd6e47d1d2600ca0bf6c1bd6caf` |
| JIT | `b3d1b04a9ec2ec723c29655afc06adcb2032008835c5371e512cab1d58f517a6` | `ccaa2368b2b07cc884561219ea44cf7d0906617c45caad52ba3c2d925ab74b2c` |

The focused reproducer from the workspace root is:

```sh
ctest --test-dir erlang-otp/build/linux-emu -R '^upstream-wx_app_SUITE$' --output-on-failure
ctest --test-dir erlang-otp/build/linux-jit -R '^upstream-wx_app_SUITE$' --output-on-failure
```

Failure work directories are `wx_app_SUITE-1791997626685792513` (interpreter)
and `wx_app_SUITE-1791997573640289302` (JIT), under each build's
`checks/upstream/`. Scratch evidence is
`tmp/otp-wx-first-check-{emu,jit}.log`, `tmp/otp-wx-gdb-{emu,jit}.log` and
`tmp/otp-wx-artifacts.json` at workspace level. Debugger exit status zero means
the debugger completed; the inferior received SIGSEGV. Neither run executed a
Common Test case. The other five suites and product regression were not run
after discovering this blocker. Prior SDK acceptance remains historical bounded
evidence and does not certify this native interoperability boundary.

The maintainer authorized a BEAM-side visibility correction. The historical
failure does not justify changing retained wx sources, suppressing upstream
assertions or altering the GUI dependency stack to avoid the collision.

## Private PCRE correction and acceptance

The PCRE static target now has `C_VISIBILITY_PRESET hidden`. This binds its
private implementation locally and prevents ELF interposition in either
direction. Both flavor dynamic symbol tables lose exactly 132 `pcre2_*` and
`_pcre2_*` symbols, with no other added or removed exports. Public runtime,
NIF, driver and matching-component symbols remain unchanged. Other vendors are
not hidden indiscriminately: some matching components consume their symbols.

A standalone installed-SDK consumer links `libbeam` before system PCRE2 10.46.
It checks provider identity and real match/nonmatch/capture results before,
during and after three bare VM lifetimes in each runtime family. It runs with
fresh and relocated prefixes. The new check rejects the old SDK's incorrect
binding and passes with the correction; ordinary OTP `re:run` is checked too.
The native-boundary test rejects any PCRE dynamic export. CI declares system
PCRE2 development files as a test dependency, not a VM runtime dependency.

Source HEADs for this correction are BEAM
`2a98b2a2046f41f793bb2ef64f088649ca2fa97f` and OTP
`89f619d25ad6df99f5b025156fe4f05b077b98fd`, plus the uncommitted visibility,
regression, test-orchestration and documentation changes. Retained wx sources,
upstream suites and bootstrap remain unchanged.

| Flavor | Corrected SDK build identity | Installed libbeam SHA-256 |
| --- | --- | --- |
| Interpreter | `61a170e9dc88248804a81439870b89004ed1e2fc445b697ea9e86c0432cb390d` | `b0b465a8cefd8bc0f7f1b714ca2d4be8ca239e068b3d4b07a41c2ec194d4fd65` |
| JIT | `681331e68b80c2a8aeafc4a850c4845b83977d8501872a88b6873c022b861a7f` | `39ebffcef270fb1e87e99e719f806158cab15ae44968aabfc79c8a6521ce113b` |

Both flavors pass all 26 BEAM CTests, including the new coexistence regression;
all 62 playground configurations and 25 relocated bundles per flavor; matching
GLM package-consumer acceptance; and the five OTP SDK/product/command checks.
Runtime-suite elapsed times are 655.16 seconds (interpreter) and 769.21 seconds
(JIT). The OTP installs contain the corrected runtime hashes above. All prior
997 application/core BEAM files retain their hashes; the full inventory remains
1,238 files and 31 application entries, plus ERTS.

Matching GLM archive hashes are
`a404d928369d2211d211c621ac4532d028ebd461c28b46fe0c918a0a96801c6f`
(interpreter) and
`2777ebe284a2f81cc0c78d7d8967597115b3babb830c4788ffccd6d3f1a3f7c4`
(JIT). Workspace scratch records are `tmp/pcre-acceptance.json`,
`tmp/pcre-export-verification.json`, `tmp/pcre-sdk-full-{emu,jit}.log`,
`tmp/pcre-sdk-playground-{emu,jit}.log`, `tmp/pcre-sdk-glm-check-{emu,jit}.log`
and `tmp/pcre-otp-product-{emu,jit}.log`. These results close the PCRE repair,
not the complete OTP product or wx acceptance.

## Remaining wx results

The corrected SDKs produce the following results with unchanged upstream suites:

| Check | Interpreter and JIT result |
| --- | --- |
| `wx_app_SUITE` | 6 passed, no failures or skips. |
| `wx_basic_SUITE` | 17 passed, no failures or skips. |
| `wx_xtra_SUITE` | 5 passed, no failures or skips. |
| `wx_event_SUITE` | Aborts during `spin_event`: GTK's Glycin image helper reports `No child processes`. No completed suite result. |
| `wx_class_SUITE` | Records a failure in `taskBarIcon` because `code:priv_dir(debugger)` returns `{error,bad_name}`; later aborts on the same GTK image-helper failure. No completed suite result. |
| `wx_opengl_SUITE` | 3 upstream user skips: the suite explicitly requires manual execution. Its strict gate remains nonpassing. |
| `wx-product` | Widget and Mesa llvmpipe/OpenGL cycle 0 succeeds, then native reload fails on restart. Its strict gate remains nonpassing. |

The class-suite resource is an explicit dependency on the not-yet-assembled
Debugger application, not permission to copy its image into a fixture or change
suite assertions. The event/class aborts and manual skips are not counted as
passing cases. Scratch logs are `tmp/pcre-wx-check-{emu,jit}.log`; completed suite
results and the independently nonpassing product result live under each build's
`checks/upstream/`. Separating the product check leaves every assertion and its
three-boot requirement intact.

### Native restart comparison

The JIT backtrace reaches a stale callback through `g_log_structured_array`,
`gtk_disable_setlocale` and `wxEntryStart` when reloading wx. The interpreter
also fails on reload; its debugger trace reaches `g_log_set_writer_func` from
`WxeApp::OnInit`. Retained `wxe_impl.cpp` installs a process-global GLib writer;
`wxe_nif.c` stops the GUI on unload without restoring that registration.
No native-lifetime or signal-policy correction was applied.

A reference-only comparison uses the original pinned OTP 29.0 runtime, the
identical CMake-built wx extension, identical probe bytecode and identical
system GUI libraries. It reproduces the first-cycle success and restart
SIGSEGV with the same GLib/GTK stack. The runtime binary is byte-verified against
`references/erlang-otp-29-artifacts/linux-amd64-glibc-base/artifacts/release-tree.tar.gz`
at pin `550d7b7898706c7822362c42e7b93120c1d1f29a`:

- Archive SHA-256: `c182aeb6306397df6b7aa9e74e154035712f546e84ab46398aecf79f896535ca`.
- Original runtime SHA-256: `2827166c079456d82f882e3a827cd2d66d8db1f28edc5b1f5b45a213239d0cdb`.

This comparison isolates VM ownership; it is not acceptance of the candidate and
not a claim that wx was built by the upstream Make recipe. The original archive
omits wx, so the identical source-built extension is supplied to the reference
VM for this diagnostic only. Evidence lives under
`tmp/pcre-wx-upstream-oracle/` (`provenance.json`, `execution.log`, `gdb.log`),
with candidate traces in `tmp/pcre-wx-gdb-{emu,jit}.log`.

### GTK child-process comparison

Both retained upstream and BEAM `erts_sys_unix_later_init` select `SIG_IGN` for
`SIGCHLD`. The system GTK image loader uses Glycin child processes and fails
with `ECHILD`. The pinned original runtime reproduces this failure in a minimal
wx spin-control diagnostic. Selecting `os:set_signal(sigchld, default)` only
in that reference diagnostic permits widget creation, but emits a Glycin
sandbox-fallback warning. This is causal evidence, not an approved production
policy or a passing security/isolation check. Neither candidate startup policy
nor GUI sandbox settings were changed. Commands and outputs are preserved as
`image*-command.json` and `image*.log` in the reference diagnostic directory.

The deferred work needs an explicit native-lifetime and GUI dependency/child
policy decision before it resumes. Preserve upstream tests and the independent
restart check for that work. Possible directions are adapting wx and public host
policy or establishing a compatible, explicitly selected GUI dependency stack.
Do not conceal the gaps by disabling sandboxing, changing image themes, copying
missing application resources, or removing restart assertions.
