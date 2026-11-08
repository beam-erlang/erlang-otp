# STDLIB regular expressions

STDLIB supplies the public `re` module and an ordinary resident NIF under
`lib/stdlib/c_src/re/`. Product, seed and source-built hosts register the same
native entry. The module attaches it through `on_load` and
`erlang:load_nif("re", re)`. No separate `re.so` is installed. The existing
22 preloads and STDLIB installation paths are unchanged.

Terminal initialization leaves its ANSI pattern uncompiled. The first cooked
terminal request compiles and caches the unchanged pattern; raw requests and
direct standard-error writes need no regex activation. Reinitialization preserves
an existing cache. This keeps early standard error available before boot on-load
handlers finish, without changing Kernel child order.

The native boundary uses installed public SDK interfaces, resource types,
binary APIs and the public CRC API. OTP owns its adapted PCRE2 10.47 copy and
declares `pcre2` as included through public composition. Backend symbols use
`otp_re_backend_` and hidden visibility. The VM contains no PCRE implementation.
The independent BEAM/Erlang regex package is a reviewed implementation reference,
not a source or build dependency; exact provenance is recorded beside the glue.

Public Erlang wrappers retain global matching, splitting, replacement, Unicode
conversion and `erl_stdlib_errors` diagnostics. Native compilation, import and
export run on dirty CPU schedulers with operation-local contexts. Compilation
requires a known scheduler stack bound and a 10 KiB reserve through
`beam_native_stack_has_space`; insufficient or unavailable space produces the
usual PCRE stack-check error. Entry, stack checkpoints and exit check caller
liveness and VM stop. Dirty work can finish after its caller dies; unpublished
results are released when that native work finishes.

Matching uses regular scheduled NIF continuations with at most 64,000 backend
loop-cost units per invocation, preserving patched long-scan and Unicode
validation interruption points. Consumed work is charged with
`enif_consume_timeslice`. This is scheduling policy, not exact reduction-count
compatibility. Compiled patterns and suspended matches own resources and subject
data; persistent state never retains a callback environment.

Exported patterns contain native bytecode and are trusted cache inputs. Checksums
detect corruption, not authenticity or arbitrary malicious bytecode. Version
and byte-order incompatibility trigger recompilation from the retained pattern
text. Serialized exports provide interchange with legacy BIF implementations;
live legacy pattern resources do not.

Ordinary wrapper-module upgrades reuse the resident backend. The upgrade callback
checks load information and the private-state ABI, stages takeover of both
resource types and publishes a new atomic module owner only on success. Failed
upgrades leave the old owner intact. Shared state is freed after the final owner
unloads. Active old calls retain ordinary busy-purge behavior: finish those calls
before purging old code. Native binary replacement and resource-ABI migration are
outside this contract.

`upstream-re_SUITE` retains all 37 pinned cases, three-minute case deadlines,
the Unicode minimum-yield assertion, killed-match assertions and all 56 patched
yield points. An excluded acceptance host substitutes the same-source
instrumented implementation and adds a private control NIF. Its control fixture
explicitly loads ordinary `re` before setting matcher budgets, independently of
terminal initialization. `otp-regex` owns
upgrade, rollback and acknowledged native-lifetime checks. Production activation
checks run separately; installed products contain no test controls.

`tools/benchmark_regex.py` compares explicitly identified preserved BIF and final
NIF installations. Select both SDKs, both OTP prefixes, the candidate build, and
separate runtime source digests. It retains the eight reference workloads and
adds filelib, shell documentation, release hybrid-boot generation, Common Test
specification processing and Xmerl XSD pattern checks. The default is five
alternating pairs per workload with two warmups, using one normal, dirty CPU and
dirty I/O scheduler. CPU/wall clocks bracket warmed operations; competing-process
gaps and backend allocation/retention snapshots are reported separately.
Backend counters exclude ordinary Erlang storage and are unavailable for the BIF
baseline. Post-GC snapshots can include pending reclamation; lifetime acceptance
owns cleanup assertions. Performance has no parity threshold. Sources differ
after physical VM deletion, so matching SDK metadata does not establish source
equivalence.

For backend updates, retain notices and review the upstream interruption patches,
generator outputs, symbol namespace, stack/cancellation checks and serialization.
`cmake/OTPRegex.cmake` owns the source inventory; do not restore upstream VM
makefile ownership from the retained vendor maintenance notes. Bootstrap wrapper
changes require candidate refresh, reviewed adoption and deterministic
reproduction as described in [bootstrap maintenance](../bootstrap/README.md).
