# Application assembly

The application set and versions come from [OTP_VERSION](../OTP_VERSION) and
[otp_versions.table](../otp_versions.table). The OTP 29.0 row contains 35
applications plus ERTS. [OTPApplications.cmake](../cmake/OTPApplications.cmake)
owns the explicit source/resource inventory and dependency ordering. All target
applications must be assembled; a module count or `.app` file does not establish
acceptance. [Compatibility](compatibility.md) owns that distinction.

Generators execute through OTP's source-built private compiler host and
`OTP_BUILD_COMMAND`. They do not invoke the BEAM command, a sibling compiler or
system Erlang. Build-only generators and temporary transform seeds remain in
the build tree. Application compilation preserves upstream metadata and profile
options; deterministic bootstrap verification remains separate. Installation
includes the original selected sources, generated sources/headers, development
resources, examples and licenses where required by upstream layout.

## Foundation, commands and metadata

Kernel, STDLIB, Compiler, Parsetools and SASL establish ordinary application and
release generation. Syntax Tools orders `merl_transform` through its bootstrap
form before compiling the final transform. Common Test installs its logging
resources and original hooks/headers. EI and command front ends are built from
OTP-owned sources; [commands](commands.md) describes launch policy.

The ERTS application tree combines SDK-provided core inspection files with
OTP preloads. `prim_eval` executes assembly bytecode while its abstract forms
come from `prim_eval.erl` through the retained `add_abstract_code` rule. Merely
compiling assembly with `debug_info` does not produce those forms. Core artifacts
must retain attributes, abstract code and matching execution chunks; OTP must
not compile substitute SDK core modules. Inspection is used by EDoc, Xref,
Debugger and other standard tools.

## ASN.1, Tools and Public Key

[OTPASN1.cmake](../cmake/OTPASN1.cmake) builds runtime-template modules, invokes
`prepare_templates.erl` in separate host jobs and generates `asn1ct_rtt.erl`
then `asn1ct_eval_ext.erl`. Generator-only modules are excluded from the product
inventory. The ordinary ASN.1 NIF compiles through `BEAM::NIF` and uses public
`enif_*` imports. The compiler version comes from the product version table.

Tools generates its Xref parser through source-built Parsetools.
[OTPPublicKey.cmake](../cmake/OTPPublicKey.cmake) generates Public Key codecs
from its explicit ASN.1 schemas/configurations using BER, DER and the retained
options. Information-object-only schemas do not acquire invented header outputs.
The generated public header and selected schemas install at upstream paths.
The retained `convert.escript` produces Diffie-Hellman constants. A byte-identical
build copy of `pubkey_ssh.erl` makes local include lookup use that generated
header without editing retained source. Preserve upstream `app_vsn` attributes.

ASN.1's personnel-record example has a pinned PER/UPER generated-value ordering
limitation. `asn1-value-generation` preserves its specific expected behavior and
exact generated-output hashes in the [test oracle](../tools/fixtures/asn1-value-reference.json).
It is distinct from general codec round-trip acceptance; do not erase that oracle
as a generated report.

## Crypto, SSL and SSH

[OTPCrypto.cmake](../cmake/OTPCrypto.cmake) builds Crypto through `BEAM::NIF` and
OpenSSL. The callback remains a separate library for shared OpenSSL; static
OpenSSL uses the retained main-NIF arrangement. Keep declaration/link probes,
upstream version definitions and explicit provider/system dependencies. Private
VM imports and SDK build-path RPATHs are forbidden. A declared OpenSSL branch
or capability is not proof that every configuration was qualified.

SSL has explicit source-built Public Key code/header dependencies, including
the generated public header. SSH orders behavior modules before consumers and
uses Public Key's generated headers. Both retain ordinary application resources,
source headers and version reporting. Product tests must retain certificate/host
verification defaults; local fixture trust is not a product policy change.

## Data, HTTP, XML and documentation

Mnesia and Inets retain ordinary application attributes, source/header resources
and private data assets. Application lookup must work against the installed
tree after relocation. Database persistence and client/server workflows need
behavioral acceptance beyond assembly.

EUnit orders `eunit_autoexport` and listener behaviors before consumers and
installs the public header/transform closure for `include_lib` consumers. Its
upstream product inventory includes its shipped internal test module.
[OTPXmerl.cmake](../cmake/OTPXmerl.cmake) generates the retained Yecc grammars
and concatenates SAX encoding fragments with their common implementation
byte-for-byte. Generated outputs stay under the build directory and install
alongside their upstream source/header resources.

EDoc generates its parser through OTP-owned tools, depends explicitly on Xmerl
and keeps its upstream `no_docs` compilation option. Install its HTML, image and
DTD resources and the product sources needed for EEP-48 generation. Standard
ERTS inspection files are an SDK/product installation responsibility, not an
EDoc-specific replacement module set.

## FTP, TFTP and ELDAP

FTP/TFTP use source-owned ordinary application assembly. Their server fixtures
are test dependencies rather than installed OTP assets.

ELDAP generates `ELDAPv3` from the retained schema with BER and
`legacy_erlang_types`. The generated record header belongs in the upstream
application's `ebin` location; retained public headers, schema, sources and
application/upgrade resources install together. TLS setup and explicit CA
selection are described in [test preparation](test-preparation.md#external-services).

## Diameter

[OTPDiameter.cmake](../cmake/OTPDiameter.cmake) owns parser generation, compiler
ordering and the selected dictionaries. Generate inherited dictionaries before
dependants and use source-built Syntax Tools explicitly. Compiler/inspection
helpers follow the upstream application resource's module selection; retained
schemas outside the selected dictionary inventory must not become invented
product outputs. Install generated headers/sources, selected schemas, examples
and `diameterc` together. Ordinary compiler/source metadata and complete preload
abstract forms are necessary for its Xref and export inspection.

## OS Monitor and Java

[OTPOSMon.cmake](../cmake/OTPOSMon.cmake) builds the selected platform helpers
against operating-system interfaces and libc, without VM-private dependencies.
Keep CPU/memory/disk helper installation and resource discovery platform-owned.

[OTPJInterface.cmake](../cmake/OTPJInterface.cmake) uses the retained Java source
inventory and explicitly selected Java, Javac and Jar tools. JInterface has no
Erlang product modules or native VM library. Install its JAR and selected Java
sources at upstream application paths. Bytecode uses the selected JDK target;
use matching JDK inputs for reference content comparison rather than treating
different compiler outputs as equivalent automatically.

## Dialyzer, Typer and SNMP

Dialyzer compiles its analysis modules with upstream version definitions and
installs the retained native `dialyzer`/`typer` front ends, sources and headers.
PLTs must be built by the selected installed product and use its actual files;
removing default base applications to obtain a pass changes the workload.

[OTPSNMP.cmake](../cmake/OTPSNMP.cmake) generates the Yecc parser, BER codec,
MIB compiler seed, standard MIBs and public headers in dependency order before
ordinary application compilation. Preserve the explicit upstream module list,
behavior ordering, version/`app_vsn` metadata and compiler defaults. Install MIBs,
SMI schemas, instrumentation mappings, templates, generated sources and `snmpc`.
The retained SNMPv1 converter pads its field array to preserve one-based indexing
without Perl's removed nonzero `$[` feature; comment handling precedes string
tracking so license text cannot corrupt conversion state.

## Megaco and ODBC

[OTPMegaco.cmake](../cmake/OTPMegaco.cmake) generates the Yecc parsers and
BER/PER codecs for protocol versions 1–3, preserving selective decoding,
`legacy_erlang_types`, behavior ordering and parser inlining. Both standard and
reentrant Flex scanners use line-number tracking and `BEAM::Driver`. Preserve
their public-driver boundary, native install paths and original scanner semantics,
including lowercasing quoted text. ET's header is a build input, not proof of
GUI tracing behavior.

[OTPODBC.cmake](../cmake/OTPODBC.cmake) builds `odbcserver` against OTP's EI and
the selected system driver manager. The helper installs under the ordinary ODBC
`priv/bin` location and communicates with Erlang through sockets/ports, without
linking a VM. Preserve its IPv6 capability probe and explicit ODBC dependency.
`odbc_debug` is a development source outside the product module list.

## Runtime Tools, ET and desktop tools

[OTPRuntimeTools.cmake](../cmake/OTPRuntimeTools.cmake) builds IP/file trace
drivers through `BEAM::Driver` and `dyntrace` through `BEAM::NIF`. Query
`beam_native_trace_backend_get()` through the installed public SDK to select the
retained tracing backend. Do not replace a missing/unknown query with forced
tracing disablement or copy private VM configuration. Instrumented backends need
their declared system dependencies and their own execution acceptance.

ET uses ordinary collector/event-file APIs and its installed resources.
Debugger installs retained interpreter/GUI modules and image assets; protected
application inspection requires installed standard sources. Observer preserves
its upstream module inventory, wx/ET headers, logo and executable Etop/crash-dump
scripts. Its documentation-only `multitrace` input is not an ordinary installed
module. Reltool keeps its module/resource inventory and `app_vsn` metadata and
generates targets through standard public APIs, without runtime overlays.

## wx bindings and native dependencies

[OTPWx.cmake](../cmake/OTPWx.cmake) consumes upstream's committed generated
bindings and matching native dispatch tables. It does not regenerate bindings
from whichever wx headers happen to be installed. Preserve resource substitution,
licensed logos, sources/headers/examples, GL/GLU probes and upstream optimization
choices for large wrappers. `wxe_driver` and `erl_gl` are ordinary NIFs despite
the former name; both use `BEAM::NIF` and install in the upstream `priv` location.

Linux requires wxWidgets with STC/XRC/HTML/XML/core/base/GL/AUI/WebView support,
GLib and OpenGL/GLU. Select a nonstandard installation with
`wxWidgets_CONFIG_EXECUTABLE`. Darwin uses Cocoa initialization and framework
OpenGL; Windows uses wxMSW. Build dependency support does not establish native
restart, child-process, attended GUI or hardware-rendering compatibility.
Process-global logging and child ownership must not retain callbacks into an
unloaded NIF or weaken the VM's signal/process contracts.
