# ET event files and sendfile comparison

## Local completion correction in progress

The [increment evidence](evidence/otp-completion-20261027/README.md#saved-sendfile-handle)
retains current runs separately from the historical comparison.

The 2026-10-27 completion direction authorizes the narrow saved-handle fix below.
Both independent native implementations now close the saved local handle in
`essio_fin_close`. Fresh OTP-linked hosts on interpreter and JIT pass all five
standalone crash-during repetitions, the crash case in the paired selection and
the crash case in the full suite, with unchanged descriptor assertions. The
modern network copy still requires its owning rebuild and acceptance.

On each candidate flavor the complete `inet` suite passes 14 cases. The complete
`socket` suite improves to 13 passes and one close-during failure; all five
standalone close-during repetitions still fail. No errno or mailbox behavior
has changed. Some close-during runs abort on partial `econnreset`; others reach
the empty-mailbox assertion with `tcp_closed`. When the case aborts before its
explicit `gen_tcp:close`, a client socket can remain open during its end callback.
The inspected descriptor difference is a socket, with no retained duplicated
`sendfile_big.html` handle. This is separate from the corrected saved-handle bug.

An independent close-notification probe on candidate and pinned original,
interpreter and JIT, observes the same backend difference: after a peer FIN,
legacy `gen_tcp:close` removes its own queued `tcp_closed`, whereas the socket
adapter leaves it queued. An unrelated marker and a notification for another
socket remain in all eight runs. `inet:tcp_close/1` implements the former policy
explicitly. Separately, ordinary socket-adapter sends use `handle_send_error`
and `curated_error_reason`, while its sendfile adapter bypasses that TCP policy.
The public `show_econnreset` option defaults to false; direct socket sendfile
still retains its own lower-level error contract.

The proposed OTP-only follow-up would route TCP sendfile failures through the
existing TCP error policy, preserving partial byte counts, and make TCP close
consume only its own close notification after synchronized server shutdown.
Direct `socket:sendfile` errors, unrelated messages and notifications for other
sockets would remain unchanged. Validate active/passive sockets, both
`show_econnreset` values, peer FIN/RST, repeated close and ownership shutdown,
then repeat the unchanged sendfile matrix. This changes queued-message behavior
and needs an explicit resolution of the completion plan's restriction on
message suppression before implementation. Harness drains, broader errno
remapping and forced descriptor cleanup remain excluded.

## Historical comparison

The 2026-10-21 comparison uses original-build OTP 29.0 at
`550d7b7898706c7822362c42e7b93120c1d1f29a` and the verified stable candidate
installations on both Linux flavors. ET needed corrections to the product
fixture. Socket sendfile reproduces upstream failures and remains blocked on a
decision about a deliberate upstream bug fix. No runtime, SDK, application or
native implementation was changed. wx acceptance and release upgrades remain
deferred.

## Inputs and comparison boundary

The stable candidates and all selected SDK artifact hashes were verified against
their external provenance. Their source inventories belong to the preceding
[assembly checkpoint](evidence/otp-fidelity-20261020/README.md); current checkout
identities and fixture hashes are recorded separately. Stable installations and
shell selectors were not replaced.

Fresh original interpreter and JIT references were built sequentially through
`erlang-otp-artifacts/scripts/build-linux-otp-distribution.sh`, including upstream
release and `Install -minimal`. All 11,816 original source-file hashes remained
unchanged after each build. Both finalized trees contain 3,680 entries and match
the corresponding candidate's complete paths, entry types, permissions and
literal symlink targets. This is structural equality, not binary equality.

The [machine-readable evidence](evidence/et-sendfile-20261021.json.gz) retains
commands, source/SDK/executable identities, reference recipe provenance,
per-run results, descriptor snapshots and diagnostic syscall excerpts. Scratch
paths identify the actual runs under `tmp/et-sendfile-20261021/`; they are not
build dependencies. The preceding installed-content review remains applicable
to the unchanged candidate artifacts.

`check_upstream.py` now accepts an explicit installed prefix and provenance for
ET, primitive-file and sendfile comparisons. It verifies all installed bytes
before execution and checks runtime identity separately from suite behavior.
Candidate and reference use the same copied pinned fixtures and assertions.
Sendfile runs use `+S2 +A1`, an explicit backend and sanitized environment.
Permission failures are prerequisites that must be resolved, never skips.

## ET fixture correction

The unchanged collector's `write` mode first renames an existing file to `.OLD`.
The previous probe supplied a fresh path, causing `file_open` to fail with
`{error,enoent}`. It subsequently attempted the private, unexported
`load_event_file/2`, which gives `undef`. Both original references reproduce
these behaviors. The historical failures remain in the evidence; no placeholder
file or ET implementation change conceals them.

The single product-owned `otp_product_probe:event_collection/1` now:

1. Creates a new directory, with a distinct directory on every product boot.
2. Reports two events and preserves their complete records.
3. Saves with `[existing, append, keep]`, checking creation and retained events.
4. Saves with `[existing, write, clear]`, checking an empty table and exact
   previous bytes in `.OLD`.
5. Reloads through public `start_trace_client(Collector, event_file, File)`,
   checking `{ok,0}`, table size two and exact record restoration.
6. Monitors collector shutdown and reader-owner exit, then checks that open
   disk logs return to their baseline with bounded waits. Abnormal exits retain
   their original cause. wx must never start.

The focused CTest `otp-et-event-file` compiles this same fixture. It passes on
both candidate and reference flavors, as does the unchanged two-case `et_SUITE`.
The 41-case `prim_file_SUITE` also passes on all four installations without skips.

Passing ET exposed a second project-probe mistake on the next boot: expecting
empty native taints after `init:restart()`. A minimal Crypto load/restart
comparison confirms that all four runtimes retain taints. The product fixture
now requires an empty initial list and exact retention of the previous boot's
list. It does not clear or ignore taints.

After both fixture corrections, all four complete product checks pass:
interpreter and JIT, each relocated and filesystem-isolated, with all three boots.
These runs retain installed native-extension, helper/module-origin, shell,
application and restart assertions. Isolation hides the original installation,
SDK and source trees. The final focused ET reruns also pass on all four runtimes.

## Sendfile results and decision

Each row below applies independently to candidate/interpreter, candidate/JIT,
upstream/interpreter and upstream/JIT. Each repetition starts a fresh VM.

| Uninstrumented selection | `inet` | `socket` |
| --- | --- | --- |
| Complete unchanged suite | 14 passed | 12 passed, 2 failed |
| Close-during, five standalone runs | 5 passed | 5 failed |
| Crash-during, five standalone runs | 5 passed | 5 failed |
| Close/crash together in suite order | 2 passed | 2 failed |

There are no skipped cases. All 96 uninstrumented runs are retained. Eight
additional diagnostic runs are separate: crash-during fails under syscall
tracing on all four runtimes, while close-during passes when traced. That timing
effect does not replace the failing uninstrumented acceptance.

Crash-during leaves the duplicated `sendfile_big.html` descriptor open. All four
traces show descriptor 25 duplicated to 26, sendfile activity on 26, closure of
the original file handle, then `close(-1) = EBADF`; no close of descriptor 26
occurs. The unchanged suite observes its retained descriptor after its own wait.

The responsible close function, `essio_fin_close` in
`erts/emulator/nifs/unix/unix_socket_syncio.c`, is identical to the pinned
upstream function. It saves `descP->sendfileHandle`, sets that field to
`INVALID_HANDLE`, then closes the invalidated field rather than the saved handle.
The file NIF's dynamic resource call duplicates the original file handle into
socket sendfile state; closing the original file therefore cannot close that
duplicate. Socket close/owner cleanup must release it. Both builds enable the
Linux sendfile path; this evidence does not indicate a missing candidate probe
or a different native registration.

Close-during has additional observations that must remain separate: partial
`{error,{econnreset,Bytes}}` results violate the unchanged accepted-result cases;
some runs instead fail the empty-mailbox assertion on `tcp_closed`. Both also
occur upstream. Descriptor failures can accompany the earlier error. Fixing the
saved-handle leak alone is not evidence that these other observations pass.

**Correction stopped:** authorize a deliberate OTP-owned fix of the proven
saved-handle close defect, followed by investigation of the remaining close-during
result/mailbox failures under unchanged assertions. No errno remapping, message
draining, forced collection, longer suite waits, harness descriptor closure or
ordinary-send substitution is accepted. Any shared-VM or public-boundary issue
requires its own scoped decision. The modern networking implementation must be
assessed independently if a native correction is authorized.

## Reproduction

For either selected candidate or original reference:

```sh
python3 tools/check_et_event_file.py --source "$OTP_SOURCE" \
  --prefix "$OTP_PREFIX" --provenance "$OTP_PROVENANCE" --work-root "$WORK/et"
python3 tools/check_upstream.py --source "$PINNED_SOURCE" \
  --prefix "$OTP_PREFIX" --provenance "$OTP_PROVENANCE" \
  --work-root "$WORK/sendfile" --suite sendfile_SUITE \
  --inet-backend socket --schedulers 2
```

Use `--case t_sendfile_closeduring` or `--case t_sendfile_crashduring` for
standalone cases; supply both in that order for the paired run. Use a fresh work
root for each repetition. `--strace /usr/bin/strace` explicitly marks a separate
diagnostic run. Repeat the uninstrumented matrix with `--inet-backend inet`.
Upstream return-value, mailbox, cleanup and descriptor assertions remain intact.

Product acceptance can reuse an attested candidate for fixture-only changes:

```sh
python3 tools/check_product.py --source "$OTP_SOURCE" --sdk "$BEAM_PREFIX" \
  --prefix "$OTP_PREFIX" --provenance "$OTP_PROVENANCE" \
  --work-root "$WORK/product" --flavor emu --cc /usr/bin/cc
```

Repeat with `--bwrap /usr/bin/bwrap` for filesystem isolation and with the matching
JIT inputs. Existing CMake build-mode tests remain available. No product rebuild
or promotion is required for these fixture-only corrections; broad BEAM/package/
playground integration must be rerun for a later product or runtime correction.
