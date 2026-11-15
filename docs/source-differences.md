# Differences from pinned original OTP

The source baseline is OTP 29.0, commit
`550d7b7898706c7822362c42e7b93120c1d1f29a`. The
[architecture guide](architecture.md) describes the installed public BEAM SDK
boundary. This record explains the following approved source
adaptations and release-layout decisions; it is not complete four-configuration
qualification or a claim of byte-identical binaries.

## Portable release and public SDK payloads

The installation prefix is the OTP root, matching the original portable release:
`bin`, `erts-17.0`, `lib`, `releases` and `usr` are siblings.
Conventional original `make install` places this root below its installation
prefix (normally `lib/erlang`) and publishes commands/manpages outside that root.
This distribution keeps commands inside the relocatable OTP root. `DESTDIR`
still stages the logical prefix through the original `Install -cross -minimal`
finalization.

The runtime comes exclusively from the installed public BEAM SDK. The portable
release therefore omits the original 53 VM-private payload files: private
headers/Make support, `liberts_internal.a`, `liberts_internal_r.a`, `libethread.a`
and their README. They describe implementation details of the separately built
VM and cannot be reconstructed as matching SDK artifacts here. Public driver,
NIF and EI headers/libraries remain installed. The original `mtx`, `ethread` and
`erl_print` native suites are explicitly excluded under the agreed public SDK
boundary; this does not count them as passing coverage.

EI ships its original public source release and Makefiles. Its generated
`eidefs.mk` records the thread and linker settings actually selected by CMake.
On the current Linux/glibc host, `_REENTRANT` and the selected Threads interface
replace the original configure recipe's additional thread macros and explicit
`-lpthread`. The selected interface needs no separate pthread library on this
host. This is a recorded compiler-argument difference, not evidence that all EI
thread behavior has been qualified.

The original `start_all_example.rel` recipe substitutes an undefined
`SNMPEA_VSN`, producing an empty SNMP version in the reference. This distribution
uses the actual SNMP application version from the release table in that example.
The original template is unchanged.

Installed executable libraries use mode 0755 and data/source files use 0644.
Directories use 0755; the reference's group-writable directories/version-list
mode reflect its build environment and are not a distribution requirement.
Common Test retains four additional license/vendor provenance files alongside
the unchanged third-party web assets. The empty `.otp-publish.lock` is an
additional installation coordination file: retaining its inode allows
concurrent publishers to serialize safely. Removing it after unlocking could
let a later publisher bypass an existing waiter.

The SDK's `erts.app` module ordering and generated integer-size header comments
differ from the original release. Their module sets and six integer-size values
match; the SDK assets remain unchanged. The OTP-generated `wx.app` has formatting
differences. Application versions and dependency/module inventories must be
compared structurally, rather than treating whitespace or ordering as an ABI
change.

## Generated documentation omission

Documentation generation is outside the supported product scope. Installations,
`otp_release` trees and Windows installers omit the original generated HTML,
Markdown, EPUB, man pages, standalone EDoc chunks and Jinterface Javadoc. The
Windows installer uses the unchanged original NSIS script with its documentation
component disabled. Documentation parity with pinned original OTP remains unmet.

Original content, assets, index/deprecation generators and core documentation
tools/configuration remain at their original paths. The retained `make/` inputs
are `ex_doc.exs`, `ex_doc_vsn`, `ex_doc_link`, `ex_doc.sha256sum`,
`markdown_to_man.escript`, `fixup_doc_links.sh` and
`get_ex_doc_formats_no_epub.sh`. They are dormant source inputs, without a
maintained full-corpus generation or installation workflow. The experimental
CMake/Make documentation context and source-URL bridge have been removed.

The [Stage 6 record](records/linux-amd64-stage6.md) preserves that attempt and the
subsequent scope decision. Its representative Compiler result does not establish
documentation parity for all 38 original contexts.

## Build recipes and single-configuration prefixes

Linux amd64 uses the original component-specific optimization, warning,
hardening and Debug definitions. Compiler-default language dialects are retained.
CMake can emit redundant defaults such as `-O3 -DNDEBUG` before the final
component settings; the later optimization option and `-UNDEBUG` restore the
original effective settings. Out-of-source generation and public SDK headers
also give build/include/debug paths different locations. These differences do
not establish byte-identical native binaries.

Each prefix contains one selected VM configuration. Linux Debug installs the
canonical `beam.debug.smp` with ordinary and selected-flavor relative aliases,
so plain commands and explicit Debug selection reach that same VM. An ordinary
`beam.smp` lookup, including explicit `-emu_type opt`, also reaches the selected
Debug VM. The prefix does not contain a separate Release runtime. Runtime Tools
keeps its original typed Debug native filenames with ordinary aliases because
its unchanged Erlang loaders request ordinary names. Crypto's loaders already
select its typed Debug native files.

ASN.1 generation retains `noobj` followed by the application's explicit Erlang
compilation, allowing generated sources and bytecode to occupy separate build
directories. This differs from recipes that let ASN.1 compile the result itself;
generator and compiler metadata must be compared separately from codec behavior.

The original ASN.1 generator also reuses compatible import databases from its
output directory. Warm databases can change the numbers assigned to generated
internal object-set helpers. The unchanged reference generator reproduced the
candidate names when given the same databases. Across the three affected
Public Key codecs, a bijective helper-name mapping preserves every function
body and export declaration; the generated family has no external or indirect
references to those numbered helpers. Their raw code/export tables and helper
names still differ. Keep this original cache behavior and record database state
when comparing generated outputs; a clean and an incremental build need not
produce identical helper numbering.

## Runtime Tools native headers

Upstream builds these extensions with private VM headers from its source tree.
This distribution builds them against the installed public NIF/driver headers.
Its current SDK selection requires dynamic tracing to be disabled.

- `lib/runtime_tools/c_src/dyntrace.c` includes `sys.h` and `dtrace-wrapper.h`
  only when `USE_DYNAMIC_TRACE` or `USE_LTTNG` is defined. With neither defined,
  the original OTP implementation uses public NIF APIs, retains the same functions
  and reports tracing as unavailable. Tracing-enabled branches are unchanged;
  this adaptation does not qualify or enable them.
- `lib/runtime_tools/c_src/trace_ip_drv.c` replaces its private
  `SET_NONBLOCKING` macro dependency with the same supported-platform operations:
  `ioctlsocket(FIONBIO)` on Windows and the existing flags combined with
  `O_NONBLOCK` through `fcntl` on Linux/macOS. The function still ignores the
  operation's result and returns zero, preserving original OTP error handling.

Both native modules remain distribution components. No VM-private headers,
libraries or interfaces are added to the public SDK. Native compilation and
bounded runtime checks do not establish full original OTP suite qualification;
other platforms and dynamic-tracing configurations require separate evidence.

On 2026-11-16, Linux amd64 Emu Release compilation passed for both modules.
Using both the selected SDK-backed bootstrap VM and the installed candidate,
`dyntrace:available/0` returned `false`, `dyntrace:user_trace_s1/1` returned
`error`, and the trace IP driver loaded and unloaded successfully. These bounded
native checks do not establish TCP tracing or full-suite qualification.

## SNMP converter and modern Perl

`lib/snmp/bin/snmp-v2tov1.pl` no longer assigns a nonzero Perl array base, which
modern Perl rejects. Instead, an unused element is prepended to each split field
array. This indexing adaptation preserves the existing one-based field references,
loop bounds, hash keys and translation rules.

An additional guard prevents quotes in a whole-line comment from opening string
state. The MIB's quoted Apache license text previously left the converter inside
a string, so it skipped `MODULE-IDENTITY` conversion. Comment-looking lines inside
an existing multiline string retain the original quote updates and subsequent
comment return. The MIB source and its copyright/license text are unchanged.

The original OTP wrapper pipes the converter into `sed` without preserving
the converter's failure status. On the selected Perl, the unmodified reference
build exits successfully but installs an empty `OTP-SNMPEA-MIB.mib.v1`. The CMake
build checks the converter and filter separately and reports this failure. The
two script adaptations restore generation and correct this comment-state defect;
they intentionally differ from the failing reference output.

Focused checks with Perl 5.40.1 covered all 24 production MIB inputs: the original
`sed` pass and project filter matched, and copyright blocks were preserved. Five
job-only fixtures covered comment quotes and genuine multiline-string behavior.
The corrected SNMPEA v1 resource is 18,717 bytes and compiles with the installed
`snmpc`, alongside unchanged SMIv1 and original SNMPEA SMIv2 controls. The four
obsolete SEQUENCE warnings also occur for the original v2 source. These checks
establish resource parse/compile validity, not SNMP agent, protocol or full-suite
qualification.
