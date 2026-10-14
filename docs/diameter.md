# Diameter assembly and inspection metadata

Diameter 2.7 builds 47 modules: 33 runtime/transport modules, six compiler
modules including the generated dictionary parser, two inspection helpers and
six generated dictionaries. `OTPDiameter.cmake` declares their inventory and
ordering. The source-built dictionary compiler uses Syntax Tools explicitly;
inherited dictionaries are generated and loaded before their dependants.

The selected upstream dictionaries are `base_rfc3588`, `base_rfc6733`,
`base_accounting`, `acct_rfc6733`, `doic_rfc7683` and `relay`. Generated sources
and headers, selected schemas, retained product sources, application/upgrade
resources, examples and the executable `diameterc` script install together.
Compiler and inspection modules remain outside the runtime `.app` module list,
following the retained resource template. The additional retained CAPUP schema
is not part of upstream's selected dictionary inventory.

Both products assemble 24 of 35 applications, with 780 application modules and
22 preload inspection files. All 802 files have identical execution chunks
between interpreter and JIT. Application files now retain ordinary source and
compiler-option metadata, including flavor-specific build paths, so only the
22 preload files remain byte-identical across flavors. No retained application,
suite, fixture or bootstrap source changed in this increment.

## Metadata ownership

The first complete `diameter_app_SUITE` run passed five cases and failed two on
each flavor. The other five selected Diameter suites passed. These failures
identified build and inspection-artifact gaps:

- `exports` inspects each module's compiler options. The replacement build's
  `deterministic` option suppressed that metadata. OTP application compilation
  now retains normal compiler options and source information; deterministic
  bootstrap/generator tools remain separate. Product acceptance reads these
  records from every application module after relocation and source isolation.
- `xref` reads the standard ERTS application directory. Eight SDK-owned core
  inputs lacked abstract code and attributes, causing the unchanged Xref
  implementation to reject them. BEAM regenerated all nine committed core
  inputs with `debug_info`, through its own bootstrap compiler. Every chunk
  retained by `make_preload` (`Code`, `AtU8`, `ImpT`, `ExpT`, `StrT`, `FunT`,
  `LitT`, `Type`) was verified identical to the previous input before replacement.
  The VM's embedded execution bytecode is unchanged.

The [SDK artifact contract](../../dev-documents/embedding-deployment.md)
continues to deploy the exact VM-owned input files. Normal BEAM builds now
verify all nine complete core artifacts against deterministic source compilation;
installed acceptance requires readable abstract code and attributes and checks
execution digests against running preloads. OTP neither compiles replacement
core modules nor imports private VM headers. No VM behavior or upstream assertion
was changed to accommodate either failure.

The corrected metadata let Xref proceed to another omitted upstream build step:
`prim_eval.S` needs abstract forms generated from `prim_eval.erl`. Compiling the
assembly with `debug_info` alone produces empty forms. The OTP preload recipe
now generates `prim_eval.abstr` with `dabstr` and runs the retained
`add_abstract_code` script, matching the upstream rule. The stub supplies only
inspection forms; executable chunks remain those of the assembly, verified
unchanged. Product acceptance checks each preload's abstract module identity.

## Acceptance

The product check compiles the installed, unchanged client/server examples and
exchanges a real accounting request and answer over TCP. It verifies success,
session identity and record number, then cleans up both services. It runs on
initial boot and two restarts, with relocation and original source/SDK paths
unavailable. A command check runs installed `diameterc` through candidate
`escript`, compiles its generated dictionary through candidate `erlc`, and
checks its identifier through candidate `erl`.

Six complete unchanged suites are selected: `diameter_app_SUITE` (7 cases),
`diameter_compiler_SUITE` (5), `diameter_codec_SUITE` (5),
`diameter_config_SUITE` (2), `diameter_sync_SUITE` (1) and
`diameter_reg_SUITE` (1). The harness hashes six original inputs per suite,
except the codec suite, which has twelve. Full Diameter transport, failover,
distributed-node and interoperability coverage remains outstanding.

All six complete selected Diameter suites pass on both flavors: **21 cases,
zero failures and zero skips**. The complete dirty-NIF, Runtime Tools tracing and
EDoc selections also pass with the current SDK (35, 22 and 10 cases respectively),
bringing this increment's unchanged-suite evidence to 88 passed cases per flavor.

The 17-check OTP regression initially passed 16 checks, with only Diameter's
Xref case failing on the empty `prim_eval` forms. After restoring the upstream
generator, both flavors pass the full seven-case application suite and fresh
initial/isolated product checks. Of the 802 rebuilt BEAM files, only
`prim_eval.beam` changes in this final correction, and its execution chunks
remain identical. This is a focused correction and rerun, not a second full
17-check run. All 17 selected contracts have passing evidence; earlier failures
remain recorded above. Wider upstream-suite coverage remains incomplete.

## Reproduction and provenance

```sh
cmake -S . -B build/linux-emu \
  -DBEAM_SDK_ROOT=/absolute/installed/emu-sdk -DOTP_BEAM_FLAVOR=emu
cmake --build build/linux-emu --parallel 6
ctest --test-dir build/linux-emu --output-on-failure \
  -R '^(initial-product|isolated-product|upstream-diameter_.*)$'
```

Repeat with the matching JIT SDK and build directory. Sources remain OTP HEAD
`72a1beb074a9fb8481d652418db80255c2962008` and BEAM HEAD
`795e3ac7fa39433cce26bc979bd8889da324d52a`, with ongoing changes uncommitted.
The upstream pin remains `550d7b7898706c7822362c42e7b93120c1d1f29a`.

| Flavor | SDK build identity | `libbeam.so` SHA-256 |
| --- | --- | --- |
| Interpreter | `15f28180d06c73b32555c6cb5e8d48c56abcaf95b596da100f4785a881c2c3f5` | `0f47af28d46c680e346682696bb1d619823bfcd6e47d1d2600ca0bf6c1bd6caf` |
| JIT | `b3d1b04a9ec2ec723c29655afc06adcb2032008835c5371e512cab1d58f517a6` | `ccaa2368b2b07cc884561219ea44cf7d0906617c45caad52ba3c2d925ab74b2c` |

Both SDK flavors pass all 26 required CTests, including complete core artifact
verification, inspection/deployment and execution-digest checks. The playground
passes 62 configurations and 25 relocated bundles per flavor: 23 projects,
124 configurations and 50 bundles in total. Both separate GLM consumers pass
with newly built matching archives:

- Interpreter: `78a638edb138f3e312671ce19a3f83e55812cffe9f3945059192f016c14643e0`.
- JIT: `abf45fd3553b207f028fe08d6b16848e7bdf05babb305d0dcd78de9db41a3f78`.

GLM builds use explicit source copies under scratch, excluding the original
`test/` tree. No source or Git history outside the owning repositories changes.

Scratch logs use `tmp/diameter-sdk-*` and `tmp/otp-diameter-metadata-*`.
Each upstream run retains SDK provenance, original input hashes, exact results
and CT logs beneath its build's `checks/upstream` directory. Earlier application
and suite results retain their own recorded SDK identities; they are not
automatically recertified by this increment. Eleven applications and the broader
compatibility gates remain unfinished.
