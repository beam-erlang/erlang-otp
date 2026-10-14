# Linux application assembly coverage

The OTP 29.0 version-table row defines 35 application entries plus ERTS 17.0.
The original Linux objective contains all 35; wx acceptance and dependent GUI
coverage are explicitly deferred, while other application assembly and non-GUI
behavior remain in scope. Both flavors now build and install all 35 applications.
Both flavors match the complete upstream installation shape and pass installed-content
review, allocator/crash-dump acceptance and the complete playground matrix. See
[assembly fidelity](assembly-fidelity.md) and the selected upstream coverage in the
[Observer/Reltool record](observer-reltool.md). The preceding
checkpoint assembled 33, including ET with failing product checks. wx acceptance remains incomplete after correcting BEAM’s
private PCRE symbol collision. Built means source compilation and resources exist, not that
all upstream suites or installation assets are certified. ERTS execution comes
solely from the installed BEAM SDK and `libbeam`, never a second VM build.

| Application | Version | Assembly | Evidence or remaining work |
| --- | --- | --- | --- |
| `asn1` | 5.5 | Built | [Bounded evidence](asn1.md); broader compatibility pending. |
| `common_test` | 1.31 | Built | [Bounded evidence](upstream-testing.md); broader compatibility pending. |
| `compiler` | 10.0 | Built | [Bounded evidence](build.md); broader compatibility pending. |
| `crypto` | 5.9 | Built | [Bounded evidence](crypto.md); broader compatibility pending. |
| `debugger` | 7.0 | Built | [Interpreter and breakpoint evidence](debugger.md); broader language suites pending and GUI coverage deferred. |
| `dialyzer` | 6.0 | Built | [Dialyzer and Typer assembly](dialyzer.md); broader suite and property coverage pending. |
| `diameter` | 2.7 | Built | [Assembly and inspection evidence](diameter.md); broader transport/interoperability coverage pending. |
| `edoc` | 1.5 | Built | [EDoc evidence](edoc.md); four upstream EEP-48 skips remain. |
| `eldap` | 1.3 | Built | [ELDAP evidence](eldap.md); 60 upstream TLS setup skips remain. |
| `erl_interface` | 5.8 | Built | [Bounded evidence](commands.md); broader compatibility pending. |
| `et` | 1.8 | Built; selected headless acceptance passed | [Event-file and unchanged suite comparison](et-sendfile-comparison.md); relocated/isolated three-boot product checks pass. GUI acceptance remains deferred. |
| `eunit` | 2.11 | Built | [Build and acceptance](xml-unit-testing.md); broader compatibility pending. |
| `ftp` | 1.2.5 | Built | [File-transfer evidence](file-transfer.md); broader compatibility pending. |
| `inets` | 9.7 | Built | [Bounded evidence](database-http.md); broader compatibility pending. |
| `jinterface` | 1.16 | Built | [Java assembly and interoperability](jinterface.md); two unimplemented upstream cases remain skipped. |
| `kernel` | 11.0 | Built | [Bounded evidence](build.md); broader compatibility pending. |
| `megaco` | 4.9 | Built | [Megaco assembly](megaco.md); broader transport/gateway and interoperability acceptance pending. |
| `mnesia` | 4.26 | Built | [Bounded evidence](database-http.md); broader compatibility pending. |
| `observer` | 2.19 | Built; selected headless acceptance passed | [Metadata, Etop, TTB and selected crash-dump backend cases pass](observer-reltool.md); GUI acceptance deferred. |
| `odbc` | 2.17 | Built | [ODBC assembly](odbc.md); 17 upstream skips and broader database/driver compatibility remain. |
| `os_mon` | 2.12 | Built | [Linux helper and suite evidence](os-monitor.md); CPU idle-measurement skip and SNMP-facing coverage remain. |
| `parsetools` | 2.8 | Built | [Bounded evidence](build.md); broader compatibility pending. |
| `public_key` | 1.21 | Built | [Bounded evidence](public-key.md); broader compatibility pending. |
| `reltool` | 1.1 | Built; selected headless acceptance passed | [Target example and complete application/server suites pass](observer-reltool.md); GUI acceptance deferred. |
| `runtime_tools` | 2.4 | Built | [Bounded evidence](runtime-tools.md); broader compatibility pending. |
| `sasl` | 4.4 | Built | [Bounded evidence](build.md); broader compatibility pending. |
| `snmp` | 5.20.3 | Built | [SNMP assembly](snmp.md); four upstream unimplemented cases and broader agent/manager coverage remain. |
| `ssh` | 6.0 | Built | [SSH evidence](ssh.md); broader suites/interoperability pending. |
| `ssl` | 11.7 | Built | [Bounded evidence](ssl.md); broader compatibility pending. |
| `stdlib` | 8.0 | Built | [Bounded evidence](build.md); broader compatibility pending. |
| `syntax_tools` | 4.1 | Built | [Bounded evidence](build.md); broader compatibility pending. |
| `tftp` | 1.3 | Built | [File-transfer evidence](file-transfer.md); broader compatibility pending. |
| `tools` | 4.2 | Built | [Bounded evidence](build.md); broader compatibility pending. |
| `wx` | 2.6 | Built; acceptance deferred | [wx evidence](wx.md): 28 cases pass; native restart, GTK child-process integration and manual OpenGL coverage remain deferred. Debugger now supplies its resource. |
| `xmerl` | 2.2 | Built | [Build and acceptance](xml-unit-testing.md); broader XML conformance pending. |

Versions come from [`otp_versions.table`](../otp_versions.table); the selected
build inventory lives in [`OTPApplications.cmake`](../cmake/OTPApplications.cmake).
Optional dependencies are outstanding requirements, not platform exclusions.
Each newly assembled application must establish generators, native ownership,
private resources and test prerequisites from its retained sources and pinned
upstream reference. Do not infer completeness from an application resource alone.
