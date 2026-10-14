# ELDAP assembly and interoperability

## Current local completion evidence (2026-10-27)

The complete 116-case selection now passes without failures or skips on
candidate and pinned original OTP 29.0, independently on interpreter and JIT.
The test setup accepts an explicit generated CA for discovery, LDAPS and
STARTTLS while preserving peer verification and all behavioral assertions.
TLS options are supplied only to SSL connections because `sslopts` implicitly
enables TLS in `eldap:open`; plain and STARTTLS setup retain their intended modes.

The [service evidence](evidence/otp-completion-20261027/services.json.gz) binds
these runs and earlier failures to their exact suite, dependency and installed
runtime identities. The verified OpenLDAP package now lives in the reusable
workspace cache. Each server/MDB directory remains disposable and private.
The earlier TLS skips below describe the historical setup, not these new runs.

## Historical assembly checkpoint

ELDAP 1.3 builds its retained `eldap.erl` and generates `ELDAPv3` from
`asn1/ELDAPv3.asn1` using the source-built ASN.1 compiler on the installed BEAM
host. Generation retains upstream's BER encoding and `legacy_erlang_types`
option. The generated record header installs in the application's `ebin`
directory, as expected by upstream consumers and tests. Public headers, schema,
application/upgrade resources and product source are installed together.

The distribution now assembles 23 of 35 applications, with 733 application
modules and 22 preload inspection files. All 755 installed BEAM files are
byte-identical between interpreter and JIT. All 753 preceding bytecode files
remain unchanged. No retained application, suite or bootstrap input changed;
there is no additional VM or public SDK change in this increment.

## Product and upstream evidence

Both flavors pass relocated and isolated product checks, including LDAP BER
encoding/decoding with legacy string representation across initial boot and two
restarts. A separate product probe runs through a relocated candidate against
OpenLDAP in private process/network namespaces. It verifies rejected credentials,
correct binding, add/search/modify/delete, LDAPS and STARTTLS with `verify_peer`
and an explicit generated CA trust anchor. No candidate loader overrides or
external Erlang runtime are used.

The complete unchanged `eldap_basic_SUITE` selects 116 cases, including both
IPv4 and IPv6 connection groups. Both flavors report **56 passed, 0 failed,
30 user skips and 30 automatic skips**: `{56,0,{30,30}}`. The exact-116 gate
remains nonpassing. Six source inputs are hashed: the suite, unchanged certificate
helper, Common Test hook, two retained data files and the independent product
probe. The upstream lab-machine reporting suite is not required or compiled.

The TLS gaps are test setup, not an identified VM regression:

- `find_first_server/2` tries STARTTLS with empty TLS options and LDAPS without
  a CA option. Retained SSL defaults reject this with
  `{options,incompatible,[{verify,verify_peer},{cacerts,undefined}]}`.
- Plain discovery retains the local server as its fallback. The 29 plain API
  cases, connection tests and other initial groups run successfully.
- LDAPS discovery cannot return a server, so its 30 cases receive user skips.
- The STARTTLS group supplies only a client key file, with no trusted CA option;
  its setup fails and its 30 cases receive automatic skips.

The independent verified-TLS probe passes before Common Test starts, establishing
that the candidate and server can negotiate with explicit trust. That result
does not convert the skipped upstream cases into passing evidence. Test sources,
assertions and SSL verification defaults remain unchanged. Resolving the suite
setup requires a separately reviewed test adaptation; broader compatibility
remains open.

The first product probe used a self-signed endpoint certificate and failed
verification before Common Test began. The corrected harness generates a
separate CA and a CA-signed server certificate with DNS/IP subject alternative
names. It preserves certificate verification. Full suite reruns then produced
the results above on both flavors.

## External dependency and isolation

`OTP_LDAP_ROOT` explicitly selects an extracted OpenLDAP package containing
`usr/sbin/slapd`, the MDB backend, `libslapi` and the core schema. Missing files
or unavailable namespace support fail preparation. The dependency is not part
of the OTP installation and no host service, account or system configuration is
installed or changed.

Recorded dependency: Ubuntu `slapd` **2.6.10+dfsg-1ubuntu5**, downloaded through
the configured package archive and extracted under workspace scratch.

| Input | SHA-256 |
| --- | --- |
| `slapd_2.6.10+dfsg-1ubuntu5_amd64.deb` | `609e338d736bceefa3590c6ca3e5339f07d4a5f9c17d552227552c133462494f` |
| `usr/sbin/slapd` | `e7fc219b088546ac9cea1d7d7ee7639d0c24985834e99287a37db8d431bb0adb` |
| `usr/lib/ldap/back_mdb.so` | `1637917e625ded96fbce2c8f299f4ffaebead8dd7d3b556dcb8a87a3156a6f64` |
| `usr/lib/x86_64-linux-gnu/libslapi.so.2` | `60b7ed03b1e6ecefcea254983712ee11d37aae297f6148d606241555cb1ff8dc` |
| `etc/ldap/schema/core.schema` | `bdee2e65292ba62732efccf368557c13021303fd5a6d2780943d7a629aac5092` |

The server uses the retained suite's base DN, administrator credentials and
access policy with a disposable MDB database. Fixed suite ports 9876/9877 and
its own listener ports stay inside private network namespaces, allowing both
flavors to run independently. Generated Common Test configuration enables IPv6
for the current hostname. Original files remain read-only; only the private work
directory is writable. The wrapper terminates and reaps its daemon on completion.
Only the external daemon receives the library path needed by its extracted
`libslapi`; the candidate runtime and its children receive no loader override.

## Reproduction and provenance

```sh
cmake -S . -B build/linux-emu \
  -DBEAM_SDK_ROOT=/absolute/installed/emu-sdk -DOTP_BEAM_FLAVOR=emu \
  -DOTP_LDAP_ROOT=/absolute/extracted/openldap-root
cmake --build build/linux-emu --parallel 6
ctest --test-dir build/linux-emu --output-on-failure \
  -R '^(initial-product|isolated-product|upstream-eldap_basic_SUITE)$'
```

Repeat with `linux-jit`, `OTP_BEAM_FLAVOR=jit` and the matching installed SDK.
OpenSSL command-line tools and `bwrap` are test dependencies. The upstream CTest
returns failure for the documented incomplete coverage gate. Its preparation
and result records include SDK identity, dependency hashes, unchanged input
hashes, exact counts and skip reasons.

Sources remain OTP HEAD `72a1beb074a9fb8481d652418db80255c2962008` and BEAM HEAD
`795e3ac7fa39433cce26bc979bd8889da324d52a`, with ongoing implementation
uncommitted. The upstream source pin remains
`550d7b7898706c7822362c42e7b93120c1d1f29a`.

The unchanged SDK identities are interpreter
`7ec11acdc06e4c126af69283d3d1b50aa1899f65138181bcba26a9bbbaf5b0e1`
and JIT `2c3cefd4ff8c7224aebc9b8ba6335460886b6004cf2e0a8242791d0de9b6088f`.
Their runtime hashes and accepted full runtime/playground/GLM evidence remain
in the [EDoc checkpoint](edoc.md); those suites were not rerun for unchanged
SDK artifacts. Earlier upstream suite results retain their recorded provenance.

Disposable logs are `tmp/otp-eldap-{configure,build,install,check,suite}-{emu,jit}.log`.
Each suite's `checks/upstream/eldap_basic_SUITE-*/` directory preserves its
result JSON, execution/CT logs and external-server logs. All 35 applications and
the full compatibility objective remain required; twelve applications still
await assembly.
