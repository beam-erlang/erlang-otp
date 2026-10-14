# Debugger assembly and headless execution

Debugger 7.0 builds all 24 retained Erlang modules, including its graphical
front ends. Its application and upgrade resources, sources, source headers,
`priv/erlang_bug.png` and image license install under `lib/debugger-7.0`.
Compilation uses source-built wx headers and behavior modules through explicit
build dependencies; it neither loads the GUI nor compiles a native extension.
Graphical acceptance is deferred with [wx](wx.md). Interpreter, evaluator and
breakpoint behavior remain in scope.

The standard source directories for Kernel, STDLIB, Compiler and Parsetools now
contain the actual selected product compilation inputs, including generated
sources. This matters to Debugger's existing safety policy: it first discovers
sources beside an installed module and rejects interpreting Kernel, STDLIB and
Debugger modules by their versioned application paths. Without installed sources,
`int:interpretable(file)` followed compiler metadata back to the checkout and
incorrectly returned `true`; the unchanged `int_SUITE` exposed this omission on
both flavors. Installing the product sources fixes the layout without changing
Debugger implementation or test assertions. No checkout paths are mounted during
final isolated acceptance.

## Validation

The product probe compiles and interprets a small consumer, evaluates it, creates
and removes a breakpoint, stops interpreting, and verifies ordinary execution.
It checks the protected-application classification and installed image resource.
This runs across three boots in relocated and filesystem-isolated installations,
with a fresh debugger server after each restart. wx is not started.

Four complete upstream suites are selected, with unchanged sources and data:

| Suite | Cases |
| --- | ---: |
| `debugger_SUITE` | 5 |
| `int_SUITE` | 7 |
| `int_eval_SUITE` | 13 |
| `int_break_SUITE` | 2 |

The CMake-owned harness copies and hashes original inputs, compiles fixture BEAM
files with debug information through installed `erlc`, and runs the suites with
only the relocated product, copied inputs and system files visible. The strict
gates require all 27 cases, with zero failures and skips. All 27 pass on each
flavor, as do both relocated and isolated product checks. GUI tests and the
remaining interpreter language suites are not covered by this selection.

## Artifact checkpoint

The source checkpoint is OTP `89f619d25ad6df99f5b025156fe4f05b077b98fd` and BEAM
`2a98b2a2046f41f793bb2ef64f088649ca2fa97f`, plus the recorded uncommitted build,
harness, PCRE correction and documentation changes. This increment changes no
retained Debugger source, upstream tests, bootstrap seeds or SDK implementation.
The installed SDK identities and hashes remain those in the [PCRE repair
record](wx.md). Its full BEAM, playground and matching GLM results are carried
forward, not represented as newly executed tests.

Both installations have 32 application entries plus ERTS and 1,262 BEAM files.
All 1,238 preceding BEAM files and both installed `libbeam` binaries retain their
hashes. ET, Observer and Reltool assembly, broader compatibility and the other
recorded coverage gaps remain pending.

Reproduce the selected checks after building and installing both configurations:

```sh
ctest --test-dir build/linux-emu -R '^(initial-product|isolated-product|upstream-(debugger|int|int_eval|int_break)_SUITE)$' --output-on-failure
ctest --test-dir build/linux-jit -R '^(initial-product|isolated-product|upstream-(debugger|int|int_eval|int_break)_SUITE)$' --output-on-failure
```

Per-suite `checks/upstream/<suite>-*/result.json` records exact input hashes,
SDK identity and results. Workspace scratch records are
`tmp/debugger-{before,artifacts}.json` and `tmp/debugger-final-{emu,jit}.log`.
The initial product attempts were denied sockets/namespaces by the execution
sandbox; their failures are not VM compatibility evidence. The initial interpreter
suite results were six passes and one failure per flavor due to the missing
installed sources described above.
