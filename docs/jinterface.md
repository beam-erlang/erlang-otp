# JInterface assembly and interoperability

JInterface 1.16 is built from the 57 retained Java sources listed in
`lib/jinterface/java_src/com/ericsson/otp/erlang/java_files`. CMake discovers a
normal JDK with `find_package(Java REQUIRED COMPONENTS Development Runtime)`;
`Java_JAVA_EXECUTABLE`, `Java_JAVAC_EXECUTABLE` and `Java_JAR_EXECUTABLE` select
its tools. Compilation follows the upstream UTF-8 and lint options. No VM
implementation, private header or native library is required by this application.

The installation contains `lib/jinterface-1.16/priv/OtpErlang.jar`, application
and upgrade resources under `ebin`, and the selected sources under
`java_src/com/ericsson/otp/erlang`. The application has no Erlang modules.
The JAR contains 65 classes, including inner classes. Java bytecode follows the
selected JDK's default target, as in the upstream build; this checkpoint does
not establish compatibility with older Java runtimes.

## Validation checkpoint

Both Linux flavors use OpenJDK 17.0.20.1, build
`17.0.20.1+1-1-26.04-Ubuntu`. Source revisions remain OTP
`72a1beb074a9fb8481d652418db80255c2962008` and BEAM
`795e3ac7fa39433cce26bc979bd8889da324d52a`, with the recorded uncommitted
implementation work. The SDK identities and runtime hashes remain those in
[Diameter evidence](diameter.md). No SDK, VM, retained product source,
upstream suite, fixture or bootstrap changes are needed for this increment.

Assembly now covers 26 of 35 applications. Existing application bytecode and
preload artifacts are unchanged. There remain 810 installed BEAM files; the
new application contributes Java classes instead. JAR entry contents match
between flavors; archive timestamps differ and byte-identical archives are
not claimed.

| Complete suite selection | Interpreter | JIT |
| --- | --- | --- |
| `nc_SUITE` | 21 passed, no failures or skips | 21 passed, no failures or skips |
| `jinterface_SUITE` | 34 passed, no failures, 2 user skips | 34 passed, no failures, 2 user skips |

The two skipped cases, `kill_mbox` and `kill_mbox_from_erlang`, explicitly
return `Not yet implemented` in the retained upstream suite. The strict
36-case gate remains nonpassing. Do not replace these assertions, count the
skips as passes, or claim full JInterface certification.

The harness copies and hashes unchanged suites, helpers and fixtures (17 inputs
for `jinterface_SUITE`, five for `nc_SUITE`). It compiles Java fixtures against
the installed JAR and Erlang fixtures with the candidate `erlc`. Execution uses
a relocated installation, private EPMD and cookie, and private process/mount
namespaces. Only system/JDK paths and the copied test directory are mounted;
the original SDK and source/build trees are unavailable. A candidate Erlang
peer independently verifies its root and loaded `libbeam` origin. Java's
`user.home` points to the private cookie directory through `JAVA_TOOL_OPTIONS`.
Normal local host naming is used for both languages: an initial explicit
`@localhost` test launcher disagreed with Java's ordinary machine hostname.
Correcting that launcher removed the initial node-name failure without changing
any assertion or product behavior.

Relocated and isolated product checks pass on both flavors, including JAR
resource lookup and class-file inspection on all three boots. Existing native,
application and restart checks remain included. The unchanged SDK's full
runtime, playground and GLM acceptance is carried forward from the Diameter
checkpoint; it is not represented as newly executed validation.

## Reproduction and evidence

After building against each selected installed SDK:

```sh
ctest --test-dir build/linux-emu -R '^upstream-(jinterface|nc)_SUITE$' --output-on-failure
ctest --test-dir build/linux-jit -R '^upstream-(jinterface|nc)_SUITE$' --output-on-failure
ctest --test-dir build/linux-emu -R '^(initial-product|isolated-product)$' --output-on-failure
ctest --test-dir build/linux-jit -R '^(initial-product|isolated-product)$' --output-on-failure
```

The first two commands intentionally report a nonpassing strict gate for the
two upstream skips. Per-run `checks/upstream/<suite>-*/result.json` records
source hashes, selected Java executables and versions, JAR hash, SDK identity,
case counts and skip reasons. Workspace scratch retains
`tmp/otp-java-{suites,final,product}-{emu,jit}.log` and
`tmp/otp-java-artifacts.json`. Initial suite logs include the corrected hostname
setup failure; `final` logs contain the final 34/0/2 node-suite results.

Broader JDK coverage, the nine remaining applications and outstanding product
compatibility gates remain work in progress.
