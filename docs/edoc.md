# EDoc and installed preload inspection

EDoc 1.5 adds 21 source-built modules, its Yecc parser, retained source/header
inputs and private HTML/DTD/image resources. Parser generation uses the selected
installed BEAM compiler host and OTP-owned parser tools. Xmerl is an explicit
build dependency. EDoc compilation keeps upstream's `no_docs` option; it can
subsequently generate HTML and EEP-48 chunks from installed product sources.
Syntax Tools installs its selected product sources for EDoc discovery, excluding
its test module. All retained application and suite sources remain unchanged.

The product now assembles 22 of the 35 application entries. Its 731 application
modules, thirteen OTP-owned preloads and nine SDK-owned core copies total 753
BEAM files, byte-identical between interpreter and JIT. All 710 application
modules from the preceding SSH checkpoint remain unchanged. ERTS has its own
resource in addition to the 22 application resources; it is not an additional
entry in the 35-application target.

## ERTS installation and SDK ownership

The unchanged `edoc_SUITE:infer_module_app_test` exposed missing installation
assets: tooling maps preloaded modules to `code:lib_dir(erts)/ebin`, while the
initial product placed only thirteen external preloads under the root ERTS
command directory and had no discoverable ERTS application directory.

The product now installs all 22 preload files under `lib/erts-17.0/ebin` and
generates `erts.app` from the retained template with its version and socket
module substitutions. Host acquisition uses that same directory. Command and
native header directories remain under root `erts-17.0` as before.

BEAM exports the full bytecode inputs of its nine embedded core modules through
`core.<module>` artifacts and `beam_install_core_modules`. The consumer does not
compile replacement core modules or read sibling VM sources. Configuration and
installation verify matching SDK hashes. The upstream-derived embedding
generator strips non-execution metadata; SDK inspection files retain it.
This is an installation contract, with no change to VM initialization,
composition, native admission or preload semantics. See the
[public artifact contract](../../dev-documents/embedding-deployment.md).

## Acceptance and remaining gaps

Both flavors pass product checks that generate HTML and EEP-48 chunks, validate
the generated documentation, and locate every preload file through the standard
ERTS application directory. These run through relocated installations and with
source/build/SDK trees inaccessible, across initial boot and two restarts.

| Complete unchanged suite | Interpreter | JIT | Preserved inputs |
| --- | --- | --- | --- |
| `edoc_SUITE` | 10 passed, no failures/skips | 10 passed, no failures/skips | 15 |
| `eep48_SUITE` | 40 passed, 0 failed, 4 user skips | 40 passed, 0 failed, 4 user skips | 8 |

The EEP-48 suite explicitly marks `type_since_tag`, `type_deprecated_tag`,
`cb_since_tag` and `cb_deprecated_tag` as unsupported and skips them in
`init_per_testcase`. The exact-44 gate remains nonpassing; these skips are not
passing compatibility evidence. No test assertions, fixtures or skip policy
were changed. Earlier Crypto engine and FTP/TLS coverage gaps remain open.

The initial EDoc run had nine passes and the installation failure above on each
flavor. The initial EEP-48 run had 39 passes, one failure and four skips: its
private output path exceeded the 255-character atom limit during `beam_lib`
filename handling. The harness now uses a shorter temporary directory for this
suite, as already required for the tracing suite. The corrected complete runs
have the results shown above.

The new SDK digest fixture initially compared full-file and embedded digests
directly. Corrected acceptance applies the existing generator's chunk selection
before comparing against running preloaded modules. The pinned upstream
`erts/emulator/utils/make_preload` has the same stripping behavior; no runtime
correction or upstream assertion change was required.

## Provenance and reproduction

Source HEADs remain OTP `72a1beb074a9fb8481d652418db80255c2962008` and BEAM
`795e3ac7fa39433cce26bc979bd8889da324d52a`, with the documented implementation
uncommitted. Upstream inputs remain pinned to
`550d7b7898706c7822362c42e7b93120c1d1f29a`. No additional retained product files
changed; the existing seven preload adaptations and command include cleanup
remain the only eight retained-file changes relative to the removal checkpoint.

| Flavor | SDK build identity | `libbeam.so` SHA-256 |
| --- | --- | --- |
| Interpreter | `7ec11acdc06e4c126af69283d3d1b50aa1899f65138181bcba26a9bbbaf5b0e1` | `9944c6ad693db11d135de0b7165dd90fe0153299b252a5dbaf1ca071e3f72c16` |
| JIT | `2c3cefd4ff8c7224aebc9b8ba6335460886b6004cf2e0a8242791d0de9b6088f` | `bbc1f214028e5755dc7f98bc99ebc3a09e8ee782fa62a913e938ee75b633e98c` |

Configure/build/install each SDK and OTP product using their corresponding
`linux-emu` or `linux-jit` build directories and explicit installed SDK selection.
The focused OTP selection is:

```sh
ctest --test-dir build/linux-emu --output-on-failure \
  -R '^(initial-product|isolated-product|upstream-edoc_SUITE|upstream-eep48_SUITE)$'
```

Repeat for JIT. EEP-48's strict incomplete gate returns failure as documented.
Each suite's `result.json` records hashes of unchanged inputs, SDK identity,
selection and exact counts. Disposable logs are
`tmp/otp-edoc-core-{configure,build,install,check,regression}-{emu,jit}.log`.

Both playground matrices pass: 23 projects, 124 configurations and 50 relocated
bundles in total. Separate GLM acceptance passes with newly built matching
archives `f90f39c5fc5725371d1b50b1426d7e6433329ba8bd452269b15b4c347bd0c1e6`
(interpreter) and
`f69a8b41a5d321ba53e4d0d812f8d26662a8b1b09171b15e46dcaba5f7588c8c` (JIT).
Logs are `tmp/core-sdk-playground-{emu,jit}.log` and `tmp/core-sdk-glm/`.
The eight focused OTP regression checks also pass on both flavors: SDK smoke
and public boundaries, source-built compiler, ASN.1 value generation, command
policy, the complete dirty-NIF suite (35 cases) and tracing suite (22 cases).
Together with the four EDoc/product checks, eleven selected CTests pass and the
EEP-48 gate remains incomplete. The current SDK therefore has 107 passing cases
and four skips in these four unchanged upstream suites; other suite results
retain their previously recorded SDK provenance.

The full 26-check BEAM CTest suite was executed for each flavor. Each initial
run passed 25 checks and failed only the newly added digest fixture described
above. The corrected complete `installed-runtime-artifacts` check passes on
both flavors, including fresh/relocated acquisition, VM digest correspondence,
modified-core rejection and install-time drift checks. Thus all 26 acceptance
contracts have passing results on the recorded SDKs; no runtime changes followed
the full runs. Logs are `tmp/core-sdk-full-{emu,jit}.log` and
`tmp/core-sdk-artifacts-corrected-{emu,jit}.log`.

These results establish EDoc assembly and bounded tooling behavior. Complete
application assembly, documentation coverage, release workflows and broad OTP
compatibility remain unfinished.
