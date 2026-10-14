# Mnesia and Inets assembly

Mnesia 4.26 and Inets 9.7 build from unchanged retained application sources.
Mnesia adds 31 modules; Inets adds 63 across its service, HTTP library, client
and server directories. The build preserves nested source/header paths for
`include_lib`, orders behavior modules before consumers, and locates Inets
application resources in `src/inets_app`. It supplies upstream's `app_vsn`
attribute and HTTP server identity through compiler options. No VM, public SDK
or retained application implementation changes are required.

Both flavors produce sixteen application resources, 605 application modules
and thirteen external preloads: 618 byte-identical BEAM files. All 511 preceding
application modules remain byte-identical to the Runtime Tools checkpoint.
The [full application inventory](application-coverage.md) keeps remaining work
explicit; assembly does not certify every application's behavior.

## Product and upstream evidence

Relocated and filesystem-isolated product checks pass on both flavors. They
create a disk-backed Mnesia schema, verify committed and rolled-back transactions,
write a backup, restart Mnesia and verify persistence across two `init:restart`
operations. An actual Inets server and client exercise GET, HEAD, missing-resource
status and the `inets/9.7` server identity on a private loopback endpoint.
These checks execute the candidate commands and sole `libbeam` with the original
SDK, source and build directories unavailable in the isolated variant.

| Unchanged upstream selection | Cases passed per flavor | Hashed inputs |
| --- | ---: | ---: |
| `mnesia_install_test` | 3 | 7 |
| `inets_SUITE` | 6 | 3 |
| `http_format_SUITE` | 18 | 3 |
| `httpc_cookie_SUITE` | 10 | 2 |

All four selections finish without failures or skips. Mnesia's selection is
its complete installation sub-suite, not the full `mnesia_SUITE` hierarchy.
The harness supplies the existing Common Test hook with two node names and
checks peer provenance. Its first run passed durability but failed the two
peer cases: parent and peers used different cookies. A private, mode-0600
cookie file in the isolated test HOME now matches the parent's explicit cookie.
Both complete reruns pass without changes to suite sources or assertions.
The user's HOME is not used or modified.

The 27-check OTP regression excluding the separately completed full ASN.1 suite,
combined with the corrected Mnesia reruns, has 26 passing checks per flavor.
The Crypto engine gate remains nonpassing with its three recorded upstream
skips. Completed upstream coverage on this SDK totals 223 passed and three
skips per flavor. The earlier full ASN.1 result adds 103 passing cases per
flavor on its recorded preceding SDK; it is not a new run of that suite.
Broader database/HTTP suites, external interoperability and full product
compatibility remain unproven.

## Provenance and reproduction

Source HEADs remain BEAM `795e3ac7fa39433cce26bc979bd8889da324d52a` and OTP
`72a1beb074a9fb8481d652418db80255c2962008`, with implementation uncommitted.
The upstream pin remains `550d7b7898706c7822362c42e7b93120c1d1f29a`.
SDK identities and `libbeam.so` hashes are unchanged from the
[Runtime Tools record](runtime-tools.md#revisions-and-acceptance-record).
Shared-runtime, playground and GLM acceptance is carried forward from that
checkpoint; this iteration changes only OTP build, probe and harness code.
Retained application, suite, fixture and bootstrap inputs remain unchanged.

Use the [build commands](build.md), then run from the OTP checkout:

```sh
ctest --test-dir build/linux-emu --output-on-failure -E '^upstream-asn1_SUITE$'
ctest --test-dir build/linux-jit --output-on-failure -E '^upstream-asn1_SUITE$'
```

The engine skip gate is expected to remain nonpassing until its separately
recorded coverage gaps are resolved. Focused database/HTTP checks use
`-R 'product|upstream-(mnesia_install_test|inets_SUITE|http_format_SUITE|httpc_cookie_SUITE)$'`.
Disposable logs are workspace `tmp/otp-database-http-{configure,build,install,check}-{emu,jit}.log`
and `tmp/otp-mnesia-install-{emu,jit}.log`. Build-local `checks/upstream/`
results record exact SDK provenance, input SHA-256 values and case outcomes.
