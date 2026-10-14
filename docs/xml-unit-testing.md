# EUnit and Xmerl assembly

EUnit 2.11 builds thirteen unchanged product modules, including its shipped
`eunit_tests` module. The build orders `eunit_autoexport` before consumers and
`eunit_listener` before its implementations, then uses the source-built transform
from the explicit product output directory. Installed public headers support
ordinary consumers using `include_lib("eunit/include/eunit.hrl")`; retained
sources and examples accompany the application.

Xmerl 2.2 builds 35 modules. Three retained Yecc grammars generate the XPath,
Base64 and XML Schema regular-expression parsers through the installed SDK
compiler host and source-built parser tools. Five SAX modules concatenate each
encoding-specific fragment with the retained common implementation, byte for
byte. Generation stays in the build tree. Product installation includes the
public/internal headers, retained sources, grammars and generated Erlang sources.
Neither application requires a new native artifact or VM mechanism.

Both flavors contain eighteen application resources, 653 application modules
and thirteen external preloads: 666 byte-identical BEAM files. The
[application inventory](application-coverage.md) records the remaining scope.
No retained application, upstream test or bootstrap source is modified.

## Acceptance design

The installed-product probe parses XML through DOM, XPath and SAX APIs, then
compiles and executes an EUnit consumer using the installed header and parse
transform. It repeats after two OTP restarts and runs from relocated and
filesystem-isolated installations. Original SDK/source/build directories are
unavailable in the isolated variant.

The unchanged `eunit_SUITE` has fifteen cases, including its internal tests,
peer-node startup, timeout handling and XML reports parsed by source-built
Xmerl. The harness copies its five helper modules and two example inputs
without editing them. EUnit's command test splits `ct:get_progname()` on spaces,
so this suite uses a product path without spaces. Separate product acceptance
continues to cover paths containing spaces. A private HOME cookie matches the
parent's explicit cookie, and candidate peer provenance is checked before tests.

The unchanged `xmerl_sax_SUITE` covers twelve cases. The unchanged
`xmerl_sax_stream_SUITE` covers four cases over loopback TCP. Its fixed port
requires serial execution across interpreter and JIT runs. This selection does
not establish full XML conformance. The complete 46-case main suite adds XPath,
DOM parsing and application metadata coverage; the 85-case XML Schema suite
adds types, facets, validation and regression cases. Both pass on both flavors.
The first Schema run passed 79 cases and failed six because test preparation
omitted `xmerl_test_lib`; compiling that retained helper produces a complete
85-case pass without assertion edits.

## Completed evidence

| Unchanged selection | Passed per flavor | Hashed inputs |
| --- | ---: | ---: |
| `eunit_SUITE` | 15 | 9 |
| `xmerl_sax_SUITE` | 12 | 10 |
| `xmerl_sax_stream_SUITE` | 4 | 5 |
| `xmerl_SUITE` | 46 | 26 |
| `xmerl_xsd_SUITE` | 85 | 83 |

All five selections pass on both flavors without skips: 162 additional cases.
The 29-check regression has 28 passes and the existing nonpassing Crypto engine
gate per flavor. Adding the separately run stream, main and corrected Schema
selections gives 31 passing checks across 32 selections, excluding the
separately accepted full ASN.1 suite. Current-SDK upstream totals are 385 passed
and three engine user skips per flavor. The earlier 103-case ASN.1 results
retain their preceding SDK provenance; no new ASN.1 execution is claimed.

Relocated and isolated product checks pass on both flavors, including the new
consumer compilation and XML/EUnit execution across two restarts. All 605
preceding application modules remain byte-identical to the database/HTTP
checkpoint. Every generated SAX output equals the exact concatenation of its
two retained source fragments. Python syntax, local links, retained-source
preservation and `git diff --check` pass. The build and tests introduce no new
retained-product adaptation or VM implementation change.

## Reproduction and provenance

Use the [build guide](build.md). Run the regular regression with
`ctest --test-dir build/linux-emu --output-on-failure -E '^upstream-(asn1_SUITE|xmerl_sax_stream_SUITE)$'`
and its JIT counterpart. Run the stream suite separately, serially across flavors,
with `-R '^upstream-xmerl_sax_stream_SUITE$'`. The full ASN.1 suite retains its
separately recorded acceptance; the Crypto engine gate remains nonpassing
because of its recorded upstream skips.

BEAM and OTP source HEADs and installed SDK identities remain those in the
[Runtime Tools record](runtime-tools.md#revisions-and-acceptance-record), with
implementation uncommitted. No shared-runtime changes are made in this iteration;
its full BEAM/playground/GLM acceptance is carried forward. Disposable workspace
logs use `tmp/otp-xml-{configure,reconfigure,build,install,check,stream,main,xsd,xsd-corrected}-{emu,jit}.log`.
Build-local upstream results retain SDK and source hashes and exact case counts.
