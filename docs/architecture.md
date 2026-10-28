# OTP distribution architecture

This distribution builds Erlang/OTP applications and commands around one VM
implementation supplied by an explicitly selected installed BEAM/Erlang SDK.
OTP owns startup policy, applications, native services, drivers, helpers,
resources, build machinery and installation. The SDK owns the VM, public
embedding/native interfaces and generic lifecycle mechanisms. See the
[BEAM architecture](../../beam-erlang/docs/architecture.md) and
[public C API](../../beam-erlang/docs/c-api/README.md) for that boundary.

## Runtime composition

The SDK supplies shared and static forms of the same VM. OTP links product,
seed and source-built compiler hosts through `BEAM::RuntimeStatic`. Modern
BEAM commands and components retain their own linkage. An OTP process must
contain one runtime: mixing shared/static VM graphs or loading a second runtime
through a native dependency is rejected.

`libbeam` embeds exactly nine core Erlang modules: `erts_code_purger`, `erlang`,
`erts_internal`, `erts_literal_area_collector`, `erts_trace_cleaner`,
`erts_dirty_process_signal_handler`, `atomics`, `counters` and `persistent_term`.
OTP embeds thirteen additional preloads in its host and supplies them through
public composition, retaining its 22-module preload/sticky inventory and restart
semantics. The seven modern base modules and modern boot/service inventories
are ordinary selected bytecode owned by BEAM; they are not OTP build inputs or
additional VM core modules.

The OTP-owned native inventory selects linked NIFs and drivers, the socket
backend and helpers. Public composition copies preload bytes, native descriptors
and immutable startup context. Preparation does not execute a VM; native
activation and ordinary `load_nif` timing remain under the VM registries and OTP
startup policy. Selecting code grants no implicit capability. VM lifetimes own
admission, activation, failure rollback, owner monitoring and cleanup. OTP owns
process startup, native names and restart policy; BEAM contains no OTP inventory.

Sequential fresh VMs may use different explicit compositions. Concurrent VMs,
complete returning teardown of an OTP system, hot native rebinding and a stable
third-party component-provider ABI are not established contracts. Native
matching-build descriptors require the selected SDK identity.

## Installed SDK boundary

CMake discovers an installed SDK with the `RuntimeStatic`, `NIF` and `Driver`
components. Exact version, build identity, flavor, public-header hashes and
required capabilities are checked. Embedding uses `<beam/beam.h>`; native
support uses `<beam/native.h>` and standard public NIF/driver headers. A missing
mechanism requires a reviewed generic SDK interface or an OTP-owned
implementation, rather than a private header or symbol import.

Do not use sibling source/build trees, a second VM, the modern BEAM compiler or
system Erlang as a compiler/execution fallback. Original OTP installations may
be explicitly identified reference or interoperability endpoints; candidate
commands and peers must execute the selected candidate runtime.

The static target carries archive retention, native exports and link support,
including the JIT C++ runtime. Static-only SDK discovery does not require the
BEAM command or shared VM library. Private compression/regular-expression
symbols must remain isolated from application dependencies. Native extensions
resolve public VM symbols through the running OTP host.

## Independent compiler bootstrap

[bootstrap/](../bootstrap/README.md) owns source-attested seeds, their recipe,
boot resource and complete manifest. A seed host linked to the installed SDK
reproduces the deterministic foundation before a source-built host can generate
ordinary applications, resources and releases. Normal builds verify inputs and
outputs without changing tracked seeds. Candidate refresh is a separate reviewed
operation. Product, seed and source-built hosts share OTP-private preparation
and the product's linked native/preload inventories.

[OTPHost.cmake](../cmake/OTPHost.cmake) establishes version/startup inputs before
application generation. `otp_host_inputs.c` prepares owned composition/context
inputs without VM calls; failures release partial inputs and preserve caller
outputs. Tests cover cancellation, copied caller storage, failed preparation
followed by recovery and normal/custom boot paths. This preparation interface
is private to OTP, not an SDK export.

## Faithful installation

OTP installs the upstream command/application layout for equivalent configured
features. Relative paths, entry kinds, permissions and literal symlink targets
must match the pinned original build. Application bytecode, executables and
other generated contents may differ and require separate content review.

The standard host is `erts-<version>/bin/beam.smp`. It embeds the static VM,
thirteen OTP preloads and built-in native implementations. The installation
contains no `libbeam.so`, VM development archive, extra runtime directory,
startup wrapper library or validation manifest. Ordinary application dynamic
extensions remain at their upstream `priv` paths. The child-setup helper is a
real checksum-verified SDK artifact; the hostname helper is OTP-owned.

The standard `lib/erts-<version>/ebin` inspection tree contains all 22 preload
files and `erts.app`. The SDK supplies exact complete inspection bytecode for
its nine core modules through public artifact deployment; OTP supplies its
thirteen preloads. Embedded execution chunks and inspection bytes retain their
required relationship, without compiling replacement VM core modules. Normal
application compilation retains source/compiler-option metadata for tools;
strict deterministic foundation metadata is a separate bootstrap requirement.

Unix installation uses upstream `Install -minimal` finalization, including
ordinary and DESTDIR installations. Windows installs native commands and boot
resources directly. Platform system/third-party dependencies remain explicit.
Self-containment concerns the BEAM runtime and does not promise to bundle every
operating-system or GUI library.

Source/build/SDK identities and complete installed checksums remain external
acceptance inputs. They never add files to the faithful installed tree and are
not ordinary user requirements. Relocation/isolation checks hide original
prefixes, sources and builds, execute from unrelated directories and reject
loader-path fallback. [Build instructions](build.md),
[application assembly](application-build.md) and
[compatibility requirements](compatibility.md) describe the owning procedures.
