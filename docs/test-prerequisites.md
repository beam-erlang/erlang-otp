# Test prerequisites

This guide describes input families required by the selected original OTP cases.
It is documentation, not a machine-readable input profile or an execution
permission. Supply actual selected inputs through the acceptance runner's
`--inputs` profile, following the [acceptance guide](otp-tests.md#explicit-prerequisites-and-private-services).
The operational manifest and project adapters define supported execution.
Missing tools, unavailable services and unresolved coverage remain nonpassing.

| Family | Required inputs and scope |
| --- | --- |
| Property framework | Selected PropEr application, headers and immutable tree identity, without another OTP core. Crypto includes a PropEr-specific case; merely finding EQC or Triq does not close that requirement. |
| Historical OTP | Real older installations requested by `ct_release_test` or `test_server`, with explicit release names, paths and installed-file identities. The current original reference cannot substitute for an older release. |
| Terminal tests | Selected `tmux`, `nano`, `vim` and `unbuffer`/Expect as required, using private sessions under the job's scratch root. |
| OpenSSL interoperability | An explicitly selected OpenSSL CLI with its required providers/configuration. Preserve original capability guards and FIPS defaults; an unavailable capability is not a generic passing exemption. |
| DNS | The pinned `inet_res_SUITE_data/run-ns` starts Knot `knotd` (version 2.9 or newer) from its fixed native paths and uses the original zone inputs. Preserve its owned listeners/configuration; never alter host resolver files. Other DNS tools apply only where selected cases use them. |
| OpenSSH | Explicit `sshd`, `ssh` and `ssh-keygen` paths. Provision private keys, configuration and a high loopback port through an owned lifecycle. |
| Net-SNMP | Selected `snmpd`, `snmpget`, `snmptrapd`, and manager-fixture `mib2c`/`net-snmp-config` with development headers/libraries. Preserve IPv4/IPv6 and known-version guards. Use private state, configuration and listeners, recording package and actual tool versions/hashes. |
| HTTP proxy | Explicit Apache `httpd`, its module directory and MIME file, `tinyproxy` and `ncat`, with private configuration, ports and verified process ownership. |
| Configured endpoints | Explicit Common Test configuration for active endpoint-dependent cases, including telnet and EI's unreachable-host tests. Upstream example credentials and remote addresses are not service selections. |
| FTP/FTPS | A selected private server with immutable identity and isolated credentials, state and listeners. Original Unix FTP setup performs process-name cleanup; the verified Linux PID/proc/network envelope must exist before it runs. Tool selection alone cannot admit host-wide cleanup. |
| GUI/display | A wx-enabled candidate and usable private graphical session where original OTP cases apply. Preserve exact platform guards; generic wx/display startup failure is a prerequisite gap. Do not fabricate `DISPLAY` values or GUI outcomes. |
| Debugger manual results | Independently obtained original manual results with identity and provenance in the expected `manual_results.erl` fixture. Missing or unknown results remain nonpassing; never generate passing answers or run instructions that change the user's home directory. |
| Manual GUI checks | The three wx OpenGL checks require the original `user` configuration. An automated private display does not provide manual results. |
| Optional SSH image catalog | Foreign-version compatibility cases enumerate explicitly available Docker images. The pinned default environment does not provision that catalog; absence means zero image coverage. Stdlib's exported Docker example is not selected by its canonical specification. Never forward the host Docker socket. |
| OCSP responder | A supported private loopback responder for cases that require one. Inspect the selected tool's actual binding capability and ownership behavior; version strings or a previous machine's results do not authorize a listener or explain a current failure. No wildcard-listener fallback is supplied. |

The input profile accepts hashed `artifacts`, per-domain `ct_config` files,
`epmd_port`, a closed-tree `proper` selection, artifact-key `executables` and
ordered closed-tree `native_roots` for Linux native dependencies.
There are no legacy aliases or implicit service installers. Historical-release
activation and complete service provisioning remain readiness gaps. Unsupported
fields fail explicitly; old profiles cannot activate removed adapters.

SSL, OS_Mon, FTP and EPMD preparation requires verified Linux namespace admission
before the original fixture can use broad process selectors. A tool selection
alone cannot enable those fixtures. Such blocks preserve missing
coverage; they do not alter original OTP assertions, deadlines or raw outcomes.
