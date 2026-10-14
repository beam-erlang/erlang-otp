# Linux OS Monitor assembly

OS Monitor 2.12 builds all eight retained Erlang modules and the Linux
`cpu_sup` and `memsup` port programs. The native programs use operating-system
headers and link only libc; they do not consume VM-private headers or build a
second runtime. `OTPOSMon.cmake` installs them under the application's
`priv/bin`, with retained source/header inputs under `src`. Application and
upgrade resources retain their upstream module inventory and dependencies.

The platform selection follows the pinned upstream Linux build: memory and
CPU helpers are included; Solaris syslog helpers and Windows event-log helpers
are not Linux build products. Their Erlang modules remain in the application.
SNMP-facing functionality still awaits SNMP application assembly and evidence.

Both products now contain 25 of 35 applications, 788 application modules and
22 preload inspection files. All preceding application bytecode remains
unchanged. No retained product, suite, fixture or bootstrap input changed,
and no SDK or VM changes were required.

## Product and upstream validation

Product acceptance starts OS Monitor and its declared dependencies, reads CPU,
memory and disk data, locates both native ports beneath the installed private
directory and stops the application. Shutdown must close the ports and remove
their operating-system processes. The checks run on initial boot and two
restarts, after relocation and with original SDK/source/build paths unavailable.

The complete unchanged Linux suite selections report:

| Suite | Cases | Interpreter | JIT |
| --- | ---: | --- | --- |
| `os_mon_SUITE` | 2 | 2 passed | 2 passed |
| `cpu_sup_SUITE` | 5 | 4 passed, 1 user skip | 4 passed, 1 user skip |
| `disksup_SUITE` | 9 | 9 passed | 9 passed |
| `memsup_SUITE` | 7 | 7 passed | 7 passed |

There are **22 passes, no failures and one user skip per flavor**. The strict
five-case CPU gate remains nonpassing. `cpu_sup_SUITE:util_values` rejects a
busy host before measuring its own workload: observed idle-period utilization
was 1.820665% on interpreter and 1.682583% on JIT, exceeding the suite's
`(100 / logical_processors_available) * 0.33` threshold. These final suites
ran sequentially across flavors. A sufficiently quiet host is still required;
the assertion and skip behavior remain unchanged.

`os_sup_SUITE:all/0` explicitly excludes Linux because the service targets
Solaris and Windows. It is not counted as passing Linux evidence. Each selected
suite and the retained Common Test hook are hashed as two unchanged inputs.
The memory suite's peer is launched through the candidate installation, with
its root and loaded `libbeam` verified before the suite starts.

The replacement harness boots the installed `start_sasl` profile because these
suites start OS Monitor themselves and require SASL's alarm service. Each suite
runs in a private process namespace with read-only host files and a writable
scratch directory. Helper-kill cases cannot inspect or kill unrelated host
processes. Neutral work paths and a file-backed Erlang launch expression keep
test names out of process command lines, so the unchanged `ps` search finds the
actual disk helper. Networking remains available to the explicit private EPMD.

Initial runs exposed preparation errors: the new product probe assumed a
three-element disk-info tuple instead of the documented four elements; suites
lacked SASL startup; a suite name in launcher arguments confused the disk
process search; and the initial interpreter memory run lacked a named node.
Those probe/harness corrections preserve upstream sources and assertions.
The final suite results above supersede those failed preparation runs.

## Reproduction and provenance

```sh
cmake -S . -B build/linux-emu \
  -DBEAM_SDK_ROOT=/absolute/installed/emu-sdk -DOTP_BEAM_FLAVOR=emu
cmake --build build/linux-emu --parallel 6
ctest --test-dir build/linux-emu --output-on-failure \
  -R '^(initial-product|isolated-product|upstream-(os_mon|cpu_sup|disksup|memsup)_SUITE)$'
```

Repeat with the matching JIT SDK and directory. `bwrap` and ordinary Linux
process/disk utilities are test prerequisites. The CPU CTest intentionally
fails its completion gate while the case is skipped.

Sources remain OTP HEAD `72a1beb074a9fb8481d652418db80255c2962008` and BEAM HEAD
`795e3ac7fa39433cce26bc979bd8889da324d52a`, with ongoing work uncommitted.
The upstream pin is `550d7b7898706c7822362c42e7b93120c1d1f29a`.
The unchanged SDK identities are interpreter
`15f28180d06c73b32555c6cb5e8d48c56abcaf95b596da100f4785a881c2c3f5`
and JIT `b3d1b04a9ec2ec723c29655afc06adcb2032008835c5371e512cab1d58f517a6`.
Their runtime hashes and accepted full SDK/playground/GLM evidence remain in
the [Diameter checkpoint](diameter.md); those checks were not repeated for
unchanged SDK artifacts.

Disposable logs use `tmp/otp-os-mon-*`; per-suite `monitor-*` directories beneath
`build/<flavor>/checks/upstream` retain exact result, provenance and CT logs.
Ten applications and the broader compatibility gates remain unfinished.
