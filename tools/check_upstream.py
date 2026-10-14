#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run OTP suites with preserved assertions and declared test-setup adaptations."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
from scratch import scratch
import shutil
import signal
import socket
import subprocess
import time
import tempfile
import sys
from host_testing import work_root as native_work_root, seatbelt, identity_expression, owned_processes, stop_owned_processes

from installation_inventory import inventory, verify_installation
from upstream_results import case_results


DEBUGGER_SUITES = {"debugger_SUITE": 5, "int_SUITE": 7,
                   "int_eval_SUITE": 13, "int_break_SUITE": 2}
STDLIB_SUITES = {"lists_SUITE": 78}

# Explicit non-GUI selections; original GUI cases remain deferred.
OBSERVER_SUITES = {"observer_SUITE": 2, "etop_SUITE": 4,
                   "ttb_SUITE": 49, "crashdump_viewer_SUITE": 6}
RELTOOL_SUITES = {"reltool_app_SUITE": 6, "reltool_server_SUITE": 49}
TOOLS_SUITES = OBSERVER_SUITES | RELTOOL_SUITES

WX_SUITES = {"wx_app_SUITE": 6, "wx_basic_SUITE": 17, "wx_event_SUITE": 14,
             "wx_class_SUITE": 18, "wx_xtra_SUITE": 5, "wx_opengl_SUITE": 3}

ODBC_SUITES = {"odbc_start_SUITE": 4, "odbc_connect_SUITE": 20,
               "odbc_query_SUITE": 44, "odbc_data_type_SUITE": 40}

MEGACO_SUITES = {"megaco_app_SUITE": 2, "megaco_flex_SUITE": 3,
                 "megaco_binary_term_id_SUITE": 25, "megaco_sdp_SUITE": 2,
                 "megaco_codec_mini_SUITE": 26, "megaco_codec_v1_SUITE": 123,
                 "megaco_codec_v2_SUITE": 172, "megaco_codec_v3_SUITE": 164}

SNMP_SUITES = {"snmp_app_SUITE": 2, "snmp_compiler_SUITE": 16,
               "snmp_pdus_SUITE": 4, "snmp_conf_SUITE": 17}

DIALYZER_SUITES = {
    "dialyzer_utils_SUITE": 3, "dialyzer_SUITE": 9, "dialyzer_cl_SUITE": 3,
    "cplt_SUITE": 41, "iplt_SUITE": 36, "typer_SUITE": 4,
    "abstract_SUITE": 1, "incremental_SUITE": 22,
}

JAVA_SUITES = {"jinterface_SUITE": 36, "nc_SUITE": 21}

OS_MON_SUITES = {"os_mon_SUITE": 2, "cpu_sup_SUITE": 5,
                 "disksup_SUITE": 9, "memsup_SUITE": 7}

def erl_string(value):
    return json.dumps(str(value), ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--build", type=Path)
    selection.add_argument("--prefix", type=Path,
                           help="Verified installed runtime; isolated suites receive a private copy")
    parser.add_argument("--provenance", type=Path)
    parser.add_argument("--host-observer", type=Path)
    parser.add_argument("--disposable-worker", action="store_true",
                        help="Explicit disposable Darwin worker for unchanged global process-kill cases")
    parser.add_argument("--cmake", default="cmake")
    parser.add_argument("--work-root", type=Path,
                        help="Explicit scratch root for suites that turn filenames into atoms")
    parser.add_argument("--ftp-server", type=Path, help="Explicit vsftpd executable for ftp_SUITE")
    parser.add_argument("--suite", choices=["prim_file_SUITE", "sendfile_SUITE", "zlib_SUITE", "zstd_SUITE", "ram_file_SUITE", "base64_SUITE", "math_SUITE", "queue_SUITE", "dirty_nif_SUITE", "engine_SUITE", "asn1_app_SUITE", "syntax_SUITE", "error_SUITE", "asn1_SUITE", "pbe_SUITE", "pubkey_policy_tree_SUITE", "ssl_rfc_5869_SUITE", "ssl_cipher_SUITE", "tls_1_3_record_SUITE", "runtime_tools_SUITE", "dbg_SUITE", "mnesia_install_test", "inets_SUITE", "http_format_SUITE", "httpc_cookie_SUITE", "eunit_SUITE", "xmerl_sax_SUITE", "xmerl_sax_stream_SUITE", "xmerl_SUITE", "xmerl_xsd_SUITE", "ftp_format_SUITE", "tftp_SUITE", "ftp_SUITE", "ssh_basic_SUITE", "edoc_SUITE", "eep48_SUITE", "eldap_basic_SUITE", "diameter_app_SUITE", "diameter_compiler_SUITE", "diameter_codec_SUITE", "diameter_config_SUITE", "diameter_sync_SUITE", "diameter_reg_SUITE", "et_SUITE"] + list(OS_MON_SUITES) + list(JAVA_SUITES) + list(DIALYZER_SUITES) + list(SNMP_SUITES) + list(MEGACO_SUITES) + list(ODBC_SUITES) + list(WX_SUITES) + list(DEBUGGER_SUITES) + list(TOOLS_SUITES) + list(STDLIB_SUITES), required=True)
    parser.add_argument("--ldap-root", type=Path, help="Extracted OpenLDAP package root for eldap_basic_SUITE")
    parser.add_argument("--postgres-root", type=Path, help="Extracted PostgreSQL 18 and psqlODBC dependency root")
    parser.add_argument("--xvfb", type=Path, help="Explicit Xvfb for private GUI acceptance")
    parser.add_argument("--wx-product", action="store_true",
                        help="Run the independent wx restart probe instead of wx_app_SUITE")
    parser.add_argument("--java", type=Path)
    parser.add_argument("--javac", type=Path)
    parser.add_argument("--inet-backend", choices=("inet", "socket"),
                        help="Kernel backend for the unchanged sendfile suite")
    parser.add_argument("--schedulers", type=int,
                        help="Normal schedulers for the candidate and default peer launches")
    parser.add_argument("--case", action="append", choices=("t_sendfile_closeduring", "t_sendfile_crashduring", "large_file_heavy", "utf8", "nchar", "nvarchar"),
                        help="Focused unchanged sendfile, RAM-file heavy or ODBC Unicode case")
    parser.add_argument("--strace", type=Path,
                        help="Diagnostic syscall tracing of sendfile execution, never uninstrumented acceptance")
    args = parser.parse_args()
    if sys.platform == 'darwin' and args.suite in {'cpu_sup_SUITE', 'disksup_SUITE', 'memsup_SUITE'} and not args.disposable_worker:
        raise RuntimeError('prerequisite-blocked: unchanged global process-kill cases require an explicitly selected disposable macOS worker')
    if args.prefix and (not args.provenance or not args.work_root):
        parser.error("--prefix requires --provenance and --work-root")
    if args.provenance and not args.prefix:
        parser.error("--provenance requires --prefix")
    if args.case and not (args.suite == "sendfile_SUITE" and set(args.case) <= {
            "t_sendfile_closeduring", "t_sendfile_crashduring"} or
            args.suite == "ram_file_SUITE" and args.case == ["large_file_heavy"] or
            args.suite == "odbc_data_type_SUITE" and set(args.case) <= {"utf8", "nchar", "nvarchar"}):
        parser.error("--case must select sendfile, RAM-file heavy or ODBC Unicode cases")
    if args.strace and args.suite != "sendfile_SUITE":
        parser.error("--strace applies only to sendfile_SUITE")
    if args.case and len(set(args.case)) != len(args.case):
        parser.error("Duplicate case selection")
    if args.inet_backend and args.suite != "sendfile_SUITE":
        parser.error("--inet-backend applies only to sendfile_SUITE")
    if args.wx_product and args.suite != "wx_app_SUITE":
        parser.error("--wx-product requires the wx_app_SUITE fixture selection")
    if args.schedulers is None:
        # Large PLT merges need parallel analysis within upstream's unchanged
        # case deadline. Do not constrain this workload to two workers.
        available = len(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else (os.cpu_count() or 1)
        args.schedulers = min(8, available) if args.suite == "dialyzer_cl_SUITE" else 2
    if args.schedulers < 1:
        parser.error("--schedulers must be positive")
    source = args.source.resolve()
    build = args.build.resolve() if args.build else None
    installed = verify_installation(args.prefix, args.provenance) if args.prefix else None
    if args.suite in set(OS_MON_SUITES) | set(DIALYZER_SUITES) | set(SNMP_SUITES) | set(MEGACO_SUITES) | set(DEBUGGER_SUITES) | set(TOOLS_SUITES) and not shutil.which('sandbox-exec' if sys.platform == 'darwin' else 'bwrap'):
        raise RuntimeError("Selected suites require their native execution isolation backend")
    display_dependency = None
    if args.suite in WX_SUITES:
        if not args.xvfb or not shutil.which("bwrap"):
            raise RuntimeError("GUI suites require --xvfb and private namespaces")
        args.xvfb = args.xvfb.resolve(strict=True)
        if not os.access(args.xvfb, os.X_OK):
            raise RuntimeError("Selected Xvfb is not executable")
        display_dependency = {"path": str(args.xvfb),
                              "sha256": hashlib.sha256(args.xvfb.read_bytes()).hexdigest(),
                              "renderer_selection": "LIBGL_ALWAYS_SOFTWARE=1"}
    odbc_dependency = None
    if args.suite in ODBC_SUITES:
        if not args.postgres_root or not shutil.which("bwrap"):
            raise RuntimeError("ODBC suites require --postgres-root and private namespaces")
        args.postgres_root = args.postgres_root.resolve()
        required = ["usr/lib/postgresql/18/bin/" + name for name in
                    ("postgres", "initdb", "pg_ctl", "createdb")]
        required += ["usr/lib/x86_64-linux-gnu/odbc/psqlodbcw.so",
                     "usr/share/postgresql/18/postgres.bki"]
        for relative in required:
            if not (args.postgres_root / relative).is_file():
                raise RuntimeError(f"PostgreSQL/ODBC dependency missing: {relative}")
        odbc_dependency = {"root": str(args.postgres_root), "sha256": {
            relative: hashlib.sha256((args.postgres_root / relative).read_bytes()).hexdigest()
            for relative in required}, "version": subprocess.check_output(
                [str(args.postgres_root / "usr/lib/postgresql/18/bin/postgres"), "--version"], text=True).strip()}
        manager = Path('/usr/lib/x86_64-linux-gnu/libodbc.so.2').resolve(strict=True)
        odbc_dependency['manager'] = {'path':str(manager),
            'sha256':hashlib.sha256(manager.read_bytes()).hexdigest()}
    java_dependency = None
    if args.suite in JAVA_SUITES:
        if not args.java or not args.javac or not shutil.which("bwrap"):
            raise RuntimeError("Java suites require selected java/javac and private process namespaces")
        java_dependency = {}
        for name in ("java", "javac"):
            executable = getattr(args, name).resolve(strict=True)
            setattr(args, name, executable)
            java_dependency[name] = {"path": str(executable),
                "sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
                "version": subprocess.check_output([str(executable), "-version"], stderr=subprocess.STDOUT, text=True).strip()}
    ftp_dependency = None
    if args.suite == "ftp_SUITE":
        if not args.ftp_server or not args.ftp_server.is_file() or not os.access(args.ftp_server, os.X_OK):
            raise RuntimeError("ftp_SUITE requires an explicit executable --ftp-server (vsftpd)")
        args.ftp_server = args.ftp_server.resolve()
        if args.ftp_server.name != "vsftpd":
            raise RuntimeError("The upstream FTP suite discovers the executable by its vsftpd basename")
        bwrap = shutil.which("bwrap")
        if not bwrap:
            raise RuntimeError("ftp_SUITE requires bwrap for private process/network namespaces")
        ftp_dependency = {"path": str(args.ftp_server),
                          "sha256": hashlib.sha256(args.ftp_server.read_bytes()).hexdigest()}
        # The retained suite searches these system directories before PATH.
        # Refuse a different server instead of silently ignoring the selection.
        preferred = shutil.which("vsftpd", path="/sbin:/usr/sbin:/usr/local/sbin")
        if preferred and Path(preferred).resolve() != args.ftp_server:
            raise RuntimeError(f"The upstream suite would prefer {preferred}; select that executable explicitly")
    ldap_dependency = None
    if args.suite == "eldap_basic_SUITE":
        if not args.ldap_root:
            raise RuntimeError("eldap_basic_SUITE requires --ldap-root")
        args.ldap_root = args.ldap_root.resolve()
        required = ["usr/sbin/slapd", "usr/lib/ldap/back_mdb.so",
                    "usr/lib/x86_64-linux-gnu/libslapi.so.2", "etc/ldap/schema/core.schema"]
        for relative in required:
            if not (args.ldap_root / relative).is_file():
                raise RuntimeError(f"OpenLDAP dependency missing: {relative}")
        ldap_dependency = {"root": str(args.ldap_root), "sha256": {
            relative: hashlib.sha256((args.ldap_root / relative).read_bytes()).hexdigest()
            for relative in required}}
        bwrap = shutil.which("bwrap")
        if not bwrap:
            raise RuntimeError("ELDAP acceptance requires private process/network namespaces")
    work_root = args.work_root.resolve() if args.work_root else native_work_root(build, 'upstream')
    if args.prefix and work_root.is_relative_to(args.prefix.resolve()):
        parser.error("Test output must be outside the selected installation")
    work_root.mkdir(parents=True, exist_ok=True)
    # dbg_SUITE:port and EEP-48 doc lookup convert private filenames to atoms. Keep the
    # harness-generated path short enough for OTP's unchanged 255-character
    # atom limit; suite contents and native arguments remain untouched.
    if args.suite in OS_MON_SUITES:
        # disksup's unchanged port test searches process command lines. Keep
        # harness paths free of helper names so it finds the actual helper.
        work = Path(tempfile.mkdtemp(prefix="monitor-", dir=work_root))
    elif args.suite in {"dbg_SUITE", "eep48_SUITE"}:
        work = Path(tempfile.mkdtemp(prefix=args.suite.split("_")[0] + "-", dir=work_root))
    else:
        work = work_root / (("wx-product" if args.wx_product else args.suite) + "-" + str(time.time_ns()))
    # EUnit's unchanged command test splits ct:get_progname() on spaces.
    # Keep that suite's executable path a single token; product acceptance
    # independently covers installations whose paths contain spaces.
    product_name = "otp" if args.suite == "eunit_SUITE" else "OTP candidate"
    prefix, suites, logs = work / product_name, work / "suites", work / "logs"
    with scratch(work):
        suites.mkdir(parents=True)
        logs.mkdir()
        if installed:
            prefix = args.prefix.resolve(strict=True)
            if (display_dependency or odbc_dependency or java_dependency or
                    args.suite in set(DIALYZER_SUITES) | set(SNMP_SUITES) |
                    set(MEGACO_SUITES) | set(DEBUGGER_SUITES) | set(TOOLS_SUITES)):
                # The namespace exposes only work and explicitly selected system
                # inputs. Copy the attested product there rather than mounting
                # the source/SDK or relying on the original prefix being visible.
                relocated = work / 'relocated OTP'
                shutil.copytree(prefix, relocated, symlinks=True)
                if inventory(relocated) != installed['entries']:
                    raise RuntimeError('Private installed product copy differs from its provenance')
                prefix = relocated
        else:
            subprocess.run([args.cmake, "--install", str(build), "--prefix", str(prefix)],
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if not installed and (args.suite in {"prim_file_SUITE", "sendfile_SUITE", "zstd_SUITE", "ram_file_SUITE"} or display_dependency or odbc_dependency or ldap_dependency or java_dependency or args.suite in set(DIALYZER_SUITES) | set(SNMP_SUITES) | set(MEGACO_SUITES) | set(DEBUGGER_SUITES) | set(TOOLS_SUITES)):
            relocated = work / "relocated OTP"
            prefix.rename(relocated)
            prefix = relocated
        native = args.suite in {"dirty_nif_SUITE", "dbg_SUITE"}
        suite_root = {"prim_file_SUITE": "lib/kernel/test",
                      "ram_file_SUITE": "lib/kernel/test",
                      "sendfile_SUITE": "lib/kernel/test",
                      "zlib_SUITE": "lib/kernel/test",
                      "dirty_nif_SUITE": "erts/emulator/test",
                      "engine_SUITE": "lib/crypto/test",
                      "asn1_app_SUITE": "lib/asn1/test",
                      "syntax_SUITE": "lib/asn1/test",
                      "error_SUITE": "lib/asn1/test",
                      "asn1_SUITE": "lib/asn1/test",
                      "pbe_SUITE": "lib/public_key/test",
                      "pubkey_policy_tree_SUITE": "lib/public_key/test",
                      "ssl_rfc_5869_SUITE": "lib/ssl/test",
                      "ssl_cipher_SUITE": "lib/ssl/test",
                      "tls_1_3_record_SUITE": "lib/ssl/test",
                      "runtime_tools_SUITE": "lib/runtime_tools/test",
                      "dbg_SUITE": "lib/runtime_tools/test",
                      "mnesia_install_test": "lib/mnesia/test",
                      "inets_SUITE": "lib/inets/test",
                      "http_format_SUITE": "lib/inets/test",
                      "httpc_cookie_SUITE": "lib/inets/test",
                      "eunit_SUITE": "lib/eunit/test",
                      "xmerl_sax_SUITE": "lib/xmerl/test",
                      "xmerl_sax_stream_SUITE": "lib/xmerl/test",
                      "xmerl_SUITE": "lib/xmerl/test",
                      "xmerl_xsd_SUITE": "lib/xmerl/test",
                      "ftp_format_SUITE": "lib/ftp/test",
                      "tftp_SUITE": "lib/tftp/test",
                      "ftp_SUITE": "lib/ftp/test",
                      "ssh_basic_SUITE": "lib/ssh/test",
                      "edoc_SUITE": "lib/edoc/test",
                      "eep48_SUITE": "lib/edoc/test",
                      "eldap_basic_SUITE": "lib/eldap/test"}.get(args.suite, "lib/stdlib/test")
        if args.suite in OS_MON_SUITES:
            suite_root = "lib/os_mon/test"
        if args.suite.startswith("diameter_"):
            suite_root = "lib/diameter/test"
        if java_dependency:
            suite_root = "lib/jinterface/test"
        if args.suite in DIALYZER_SUITES:
            suite_root = "lib/dialyzer/test"
        if args.suite == "et_SUITE":
            suite_root = "lib/et/test"
        if args.suite in DEBUGGER_SUITES:
            suite_root = "lib/debugger/test"
        if args.suite in OBSERVER_SUITES:
            suite_root = "lib/observer/test"
        if args.suite in RELTOOL_SUITES:
            suite_root = "lib/reltool/test"
        if display_dependency:
            suite_root = "lib/wx/test"
        if odbc_dependency:
            suite_root = "lib/odbc/test"
        if args.suite in MEGACO_SUITES:
            suite_root = "lib/megaco/test"
        if args.suite in SNMP_SUITES:
            suite_root = "lib/snmp/test"
        inputs = [f"{suite_root}/{args.suite}.erl",
                  "lib/common_test/test_server/ts_install_cth.erl"]
        if args.suite == "ttb_SUITE":
            inputs += ["lib/observer/test/" + name for name in
                       ("ttb_helper.erl", "client.erl", "server.erl")]
        if args.suite == "crashdump_viewer_SUITE":
            inputs += ["lib/observer/test/crashdump_helper.erl",
                       "lib/observer/test/crashdump_helper_unicode.erl"]
        if args.suite in RELTOOL_SUITES:
            inputs += ["lib/reltool/test/reltool_test_lib.erl",
                       "lib/reltool/test/reltool_test_lib.hrl"]
        if display_dependency:
            inputs += ["lib/wx/test/" + name for name in
                       ("wx_test_lib.erl", "wx_test_lib.hrl", "wx_obj_test.erl",
                        "wx_oc_object.erl", "wx_test_enums.erl", "wxt.erl")]
            inputs += ["tools/fixtures/otp_wx_probe.erl", "tools/display_server.py"]
        if odbc_dependency:
            inputs += ["lib/odbc/test/" + name for name in
                       ("odbc_test_lib.erl", "odbc_test.hrl", "postgres.erl")]
            inputs += ["tools/fixtures/otp_odbc_probe.erl", "tools/postgres_server.py"]
        if args.suite in DIALYZER_SUITES:
            inputs += ["lib/dialyzer/test/" + name for name in
                       ("dialyzer_common.erl", "file_utils.erl", "dialyzer_test_constants.hrl")]
        if args.suite in MEGACO_SUITES:
            inputs += ["lib/megaco/test/" + name for name in
                       ("megaco_test_lib.erl", "megaco_test_lib.hrl", "megaco_test_sys_monitor.erl",
                        "megaco_test_global_sys_monitor.erl", "megaco_codec_test_lib.erl",
                        "megaco_codec_flex_lib.erl")]
        if args.suite in {"megaco_codec_v1_SUITE", "megaco_codec_v2_SUITE", "megaco_codec_v3_SUITE"}:
            version = args.suite.removeprefix("megaco_codec_v").removesuffix("_SUITE")
            inputs.append(f"lib/megaco/test/megaco_test_msg_v{version}_lib.erl")
        if args.suite in SNMP_SUITES:
            inputs += ["lib/snmp/test/" + name for name in
                       ("snmp_test_lib.erl", "snmp_test_lib.hrl", "snmp_test_sys_monitor.erl",
                        "snmp_test_global_sys_monitor.erl", "snmp_test_mgr_counter_server.erl")]
        if java_dependency:
            inputs.append("lib/jinterface/test/jitu.erl")
        if args.suite.startswith("diameter_"):
            inputs += ["lib/diameter/test/diameter_util.erl", "lib/diameter/test/diameter_util.hrl",
                       "lib/diameter/test/diameter_event_logger.erl", "lib/diameter/include/diameter.hrl"]
            if args.suite == "diameter_codec_SUITE":
                inputs += ["lib/diameter/test/diameter_codec_test.erl", "lib/diameter/test/diameter_enum.erl"]
        if args.suite == "eldap_basic_SUITE":
            inputs += ["lib/eldap/test/make_certs.erl", "tools/fixtures/otp_ldap_probe.erl"]
        if args.suite == "dirty_nif_SUITE":
            inputs.append("erts/emulator/test/literal_area_collector_test.erl")
        if args.suite in {"math_SUITE", "lists_SUITE"}:
            inputs.append("lib/stdlib/test/error_info_lib.erl")
        if args.suite == "asn1_SUITE":
            inputs += [str(p.relative_to(source)) for p in sorted((source / suite_root).glob("*.erl"))
                       if not p.name.endswith("_SUITE.erl")]
            inputs.append("lib/asn1/test/External.hrl")
        if args.suite == "tls_1_3_record_SUITE":
            inputs += ["lib/ssl/test/ssl_test_lib.erl", "lib/ssl/test/ssl_test_lib.hrl"]
        if args.suite == "mnesia_install_test":
            inputs += ["lib/mnesia/test/" + name for name in
                       ("mnesia_test_lib.erl", "mnesia_test_lib.hrl", "ext_test.erl",
                        "ext_test_server.erl", "ext_test_server.hrl")]
        if args.suite == "sendfile_SUITE":
            inputs += ["lib/kernel/test/kernel_test_lib.erl", "lib/kernel/test/kernel_test_lib.hrl"]
        if args.suite == "inets_SUITE":
            inputs.append("lib/inets/test/inets_test_lib.hrl")
        if args.suite == "http_format_SUITE":
            inputs.append("lib/inets/src/http_lib/http_internal.hrl")
        if args.suite == "eunit_SUITE":
            inputs += ["lib/eunit/test/" + name for name in
                       ("eunit_test_listener.erl", "tc0.erl", "tlatin.erl", "tutf8.erl", "ttimesout.erl")]
        if args.suite == "xmerl_SUITE":
            inputs += ["lib/xmerl/test/xmerl_app_test.erl", "lib/xmerl/test/xmerl_appup_test.erl"]
        if args.suite == "xmerl_xsd_SUITE":
            inputs.append("lib/xmerl/test/xmerl_test_lib.erl")
        if args.suite == "ftp_format_SUITE":
            inputs.append("lib/ftp/src/ftp_internal.hrl")
        if args.suite == "tftp_SUITE":
            inputs += ["lib/tftp/test/tftp_test_lib.erl", "lib/tftp/test/tftp_test_lib.hrl"]
        if args.suite == "ftp_SUITE":
            inputs.append("lib/ftp/test/ftp_test_lib.erl")
        if args.suite == "ssh_basic_SUITE":
            inputs += ["lib/ssh/test/" + name for name in
                       ("ssh_test_lib.erl", "ssh_test_lib.hrl", "cth_events.erl",
                        "ssh_key_cb.erl", "ssh_key_cb_options.erl", "ssh_test_cli.erl",
                        "ssh_peername_sockname_server.erl")]
            inputs.append("lib/ssh/src/ssh_transport.hrl")
        expected_cases = {"zstd_SUITE": 10, "ram_file_SUITE": 9, "prim_file_SUITE": 41, "sendfile_SUITE": 14, "zlib_SUITE": 36, "base64_SUITE": 19, "math_SUITE": 4, "queue_SUITE": 7, "dirty_nif_SUITE": 35, "engine_SUITE": 31, "asn1_app_SUITE": 5, "syntax_SUITE": 12, "error_SUITE": 21, "asn1_SUITE": 103, "pbe_SUITE": 5, "pubkey_policy_tree_SUITE": 10, "ssl_rfc_5869_SUITE": 7, "ssl_cipher_SUITE": 4, "tls_1_3_record_SUITE": 4, "runtime_tools_SUITE": 3, "dbg_SUITE": 22, "mnesia_install_test": 3, "inets_SUITE": 6, "http_format_SUITE": 18, "httpc_cookie_SUITE": 10, "eunit_SUITE": 15, "xmerl_sax_SUITE": 12, "xmerl_sax_stream_SUITE": 4, "xmerl_SUITE": 46, "xmerl_xsd_SUITE": 85, "ftp_format_SUITE": 12, "tftp_SUITE": 9, "ftp_SUITE": 84, "ssh_basic_SUITE": 49, "edoc_SUITE": 10, "eep48_SUITE": 44, "eldap_basic_SUITE": 116, "diameter_app_SUITE": 7, "diameter_compiler_SUITE": 5, "diameter_codec_SUITE": 5, "diameter_config_SUITE": 2, "diameter_sync_SUITE": 1, "diameter_reg_SUITE": 1, "et_SUITE": 2}
        expected_cases.update(OS_MON_SUITES)
        expected_cases.update(JAVA_SUITES)
        expected_cases.update(DIALYZER_SUITES)
        expected_cases.update(SNMP_SUITES)
        expected_cases.update(MEGACO_SUITES)
        expected_cases.update(ODBC_SUITES)
        expected_cases.update(WX_SUITES)
        expected_cases.update(DEBUGGER_SUITES)
        expected_cases.update(TOOLS_SUITES)
        expected_cases.update(STDLIB_SUITES)
        expected = expected_cases[args.suite]
        if args.case:
            expected = len(args.case)
        inputs += ["tools/fixtures/otp_ct_event.erl", "tools/fixtures/otp_ct_selection.erl"]
        manifest = {}
        adaptation_manifest = json.loads((source / 'tools/upstream-test-adaptations.json').read_text())
        if adaptation_manifest.get('format') != 1 or adaptation_manifest.get('upstream_commit') != (
                source / 'UPSTREAM_COMMIT').read_text().strip():
            raise RuntimeError('Invalid upstream test-adaptation manifest')
        adaptations = {}
        for relative in inputs:
            original = source / relative
            copied = suites / original.name
            shutil.copyfile(original, copied)
            assert original.read_bytes() == copied.read_bytes()
            manifest[relative] = hashlib.sha256(copied.read_bytes()).hexdigest()
            if relative in adaptation_manifest['adaptations']:
                adaptation = adaptation_manifest['adaptations'][relative]
                if adaptation['sha256'] != manifest[relative] or adaptation['kind'] != 'test-setup':
                    raise RuntimeError('Test-setup adaptation differs from its reviewed digest: ' + relative)
                adaptations[relative] = adaptation
        if args.suite == "eunit_SUITE":
            examples = suites / "examples"
            examples.mkdir()
            for original in sorted((source / "lib/eunit/examples").iterdir()):
                if original.is_file():
                    shutil.copyfile(original, examples / original.name)
                    manifest[str(original.relative_to(source))] = hashlib.sha256(original.read_bytes()).hexdigest()
        data = suites / (args.suite + "_data")
        source_data = source / suite_root / data.name
        if args.suite in TOOLS_SUITES:
            data.mkdir(exist_ok=True)
        if args.suite == "inets_SUITE":
            # httpd_reload uses CT's data_dir as an empty document root. Git does
            # not preserve empty fixture directories, so create that root here.
            data.mkdir(exist_ok=True)
        if args.suite == "error_SUITE":
            # CT supplies data_dir with a trailing separator. The unchanged suite
            # resolves its shared corpus beside that directory in the suite tree.
            source_data = source / "lib/asn1/test/asn1_SUITE_data"
            data = suites / "asn1_SUITE_data"
        if args.suite == "snmp_compiler_SUITE":
            data = suites / "snmp_test_data"
            source_data = source / suite_root / data.name
        if source_data.is_dir():
            data.mkdir(exist_ok=True)
            for original in sorted(source_data.rglob("*")):
                if original.is_dir():
                    # Upstream archives retain empty fixture directories too.
                    # Reltool changes into use_selected_vsn/b-1.0/rel directly.
                    (data / original.relative_to(source_data)).mkdir(parents=True, exist_ok=True)
                    continue
                if not original.is_file():
                    continue
                copied = data / original.relative_to(source_data)
                copied.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(original, copied)
                relative = str(original.relative_to(source))
                manifest[relative] = hashlib.sha256(copied.read_bytes()).hexdigest()
        if args.suite == "reltool_server_SUITE":
            examples = source / "lib/reltool/examples"
            shutil.copytree(examples, suites / "examples")
            for original in sorted(examples.rglob("*")):
                if original.is_file():
                    manifest[str(original.relative_to(source))] = hashlib.sha256(original.read_bytes()).hexdigest()
        environment = {k: v for k, v in os.environ.items()
                       if not k.startswith(("ERL_", "ERLC_", "ESCRIPT_", "LD_", "DYLD_"))
                       and k not in {"BINDIR", "ROOTDIR", "EMU"}}
        environment.update(HOME=str(work), PATH=str(prefix / "bin") + ":/usr/bin:/bin")
        if args.suite in DIALYZER_SUITES:
            for key in ("DIALYZER_PLT", "DIALYZER_IPLT", "DIALYZER_CONFIG", "DIALYZER_EMULATOR", "XDG_CACHE_HOME", "XDG_CONFIG_HOME"):
                environment.pop(key, None)
        if java_dependency:
            for key in ("CLASSPATH", "JAVA_TOOL_OPTIONS", "JDK_JAVA_OPTIONS", "_JAVA_OPTIONS"):
                environment.pop(key, None)
            environment["PATH"] = str(args.java.parent) + ":" + environment["PATH"]
            environment["JAVA_TOOL_OPTIONS"] = "-Duser.home=" + str(work)
        if ftp_dependency:
            environment["PATH"] += ":" + str(args.ftp_server.parent)
            # Extracting the package avoids installing its system account. Supply
            # the anonymous account only inside this test's mount/user namespace.
            account_file = work / "passwd"
            accounts = Path("/etc/passwd").read_text()
            if not any(line.startswith("ftp:") for line in accounts.splitlines()):
                accounts += f"ftp:x:{os.getuid()}:{os.getgid()}:FTP test:{work}:/usr/sbin/nologin\n"
            account_file.write_text(accounts)
        if java_dependency or args.suite in set(DIALYZER_SUITES) | set(SNMP_SUITES) | set(MEGACO_SUITES) | set(TOOLS_SUITES) or args.suite in {"mnesia_install_test", "eunit_SUITE", "memsup_SUITE"}:
            # Unchanged helpers may start peer nodes without -setcookie.
            # Their ordinary HOME cookie must match this harness's parent node.
            cookie = work / ".erlang.cookie"
            with cookie.open("x") as stream:
                cookie.chmod(0o600)
                stream.write("otp_native_acceptance\n")
        def run(command, cwd=work):
            if ftp_dependency:
                # The unchanged suite uses process-list cleanup and a fixed port.
                # Its server and all children must remain in private namespaces.
                command = [bwrap, "--unshare-user", "--unshare-pid", "--unshare-net", "--die-with-parent",
                           "--ro-bind", "/", "/", "--bind", str(work), str(work),
                           "--ro-bind", str(account_file), "/etc/passwd",
                           "--dev", "/dev", "--proc", "/proc", "--chdir", str(work), *command]
            process = subprocess.Popen(command, cwd=cwd, env=environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                output, _ = process.communicate(timeout=7200 if args.suite == "asn1_SUITE" or args.suite in DIALYZER_SUITES else (1200 if args.suite in TOOLS_SUITES else 600))
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    output, _ = process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    output, _ = process.communicate()
                (work / "timeout.log").write_bytes(output)
                raise RuntimeError(f"Upstream execution timed out; {work / 'timeout.log'}")
            except BaseException:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.communicate()
                raise
            with (work / "execution.log").open("ab") as stream:
                stream.write((json.dumps(command) + "\n").encode() + output + b"\n")
            if process.returncode:
                raise RuntimeError(f"Command failed ({process.returncode}); {work / 'execution.log'}\n"
                                   + output.decode("utf-8", errors="backslashreplace"))
            return output
        hooks = work / "hooks"
        hooks.mkdir()
        if installed:
            identity = (f'{erl_string(prefix)}=code:root_dir(),'
                        f'{installed["flavor"]}=erlang:system_info(emu_flavor),'
                        '"29"=erlang:system_info(otp_release),'
                        'Host=filename:join([code:root_dir(),"erts-"++erlang:system_info(version),"bin","beam.smp"]),'
                        '{ok,Host}=file:read_link("/proc/self/exe"),'
                        '{ok,Maps}=file:read_file("/proc/self/maps"),nomatch=binary:match(Maps,<<"libbeam.so">>),halt().')
            if sys.platform == 'darwin':
                linux = ('Host=filename:join([code:root_dir(),"erts-"++erlang:system_info(version),"bin","beam.smp"]),'
                         '{ok,Host}=file:read_link("/proc/self/exe"),'
                         '{ok,Maps}=file:read_file("/proc/self/maps"),nomatch=binary:match(Maps,<<"libbeam.so">>),')
                assert linux in identity
                identity = identity.replace(linux, identity_expression(args.host_observer or build, work))
            run([str(prefix / "bin/erl"), "+S2", "-noshell", "-eval", identity])
        run([str(prefix / "bin/erlc"), "+debug_info", "-o", str(hooks),
             str(suites / "ts_install_cth.erl")])
        compile_includes = []
        if args.suite in MEGACO_SUITES:
            compile_includes += ["-Dmegaco_parser_inline", "+{parse_transform,sys_pre_attributes}",
                                 '+{attribute,insert,app_vsn,"megaco-4.9"}']
        if args.suite in SNMP_SUITES:
            compile_includes += ["-Dsnmp_test_data=snmp_test_data", '-Dversion="5.20.3"',
                                 "+{parse_transform,sys_pre_attributes}",
                                 '+{attribute,insert,app_vsn,"snmp-5.20.3"}']
        if java_dependency:
            compile_includes = ["-I", str(next((prefix / "lib").glob("common_test-*/include")))]
            jar = next((prefix / "lib").glob("jinterface-*/priv/OtpErlang.jar"))
            java_dependency["jar_sha256"] = hashlib.sha256(jar.read_bytes()).hexdigest()
            run([str(args.javac), "-encoding", "UTF-8", "-classpath", str(jar),
                 "-d", str(data), *map(str, sorted(data.glob("*.java")))])
        # TTB uses ?FILE as a trace filename. The original test makefile compiles
        # from the suite directory; a "suites/" prefix instead names a nonexistent
        # subdirectory under CT's runtime working directory.
        compile_cwd = suites if args.suite == "ttb_SUITE" else work
        run([str(prefix / "bin/erlc"), "+debug_info", "-I", str(suites), *compile_includes, "-o", str(suites),
             *[str(Path(relative).name if args.suite == "ttb_SUITE" else suites / Path(relative).name)
               for relative in inputs
               if relative.endswith(".erl") and Path(relative).name != "ts_install_cth.erl"]],
            cwd=compile_cwd)
        if args.suite in DEBUGGER_SUITES and data.is_dir():
            # The interpreter needs ordinary debug-info BEAM files beside unchanged
            # fixture sources, as supplied by the original test build.
            run([str(prefix / "bin/erlc"), "+debug_info", "-o", str(data),
                 *map(str, sorted(data.glob("*.erl")))])
        if args.suite == "reltool_server_SUITE":
            # Exact targets from the pinned upstream Makefile.src. Other fixture
            # applications intentionally retain their original uncompiled contents.
            fixture_modules = {
                "otp_9229/x-1.0": ("x", "mylib"), "otp_9229/y-1.0": ("y", "mylib"),
                "dependencies/x-1.0": ("x1", "x2", "x3"),
                "dependencies/y-1.0": ("y1", "y2"), "dependencies/z-1.0": ("z1",),
                "escript/someapp-1.0": ("mymod",), "use_selected_vsn/b-1.0": ("b",),
                "use_selected_vsn/b-3.0": ("b",), "use_selected_vsn/lib2/b-2.0": ("b",),
                "slim/a-1.0": ("a_sup", "a"),
            }
            # The upstream exported source includes this empty working directory;
            # Git checkouts cannot retain it. Recreate its original shape when
            # preparing copied data, without changing the suite or fixture files.
            (data / "use_selected_vsn/b-1.0/rel").mkdir(exist_ok=True)
            for relative, modules in fixture_modules.items():
                directory = data / relative
                ebin = directory / "ebin"
                ebin.mkdir(exist_ok=True)
                run([str(prefix / "bin/erlc"), "+debug_info", "-o", str(ebin),
                     *[str(directory / "src" / (module + ".erl")) for module in modules]])
        if args.suite == "snmp_compiler_SUITE":
            # Upstream's fixture build provides Test2.bin in the shared data
            # directory; the augmentation case imports it while writing elsewhere.
            preparation_expression = (
                f'{{ok,_}}=snmpc:compile({erl_string(data / "Test2.mib")},'
                f'[{{outdir,{erl_string(data)}}},{{group_check,false}}]),halt().')
            run([str(prefix / "bin/erl"), "+S2", "-noshell", "-eval", preparation_expression])
        if native:
            run([args.cmake, "-S", str(source / "tools/fixtures/native"), "-B", str(work / "native-build"),
                 f"-DOTP_PREFIX={prefix}", f"-DSUITE={args.suite}", f"-DSUITE_DATA={data}"])
            run([args.cmake, "--build", str(work / "native-build"), "--parallel", "2"])
        outcome = work / "ct-result.term"
        declaration = work / 'declared-selection.json'
        if not args.wx_product:
            # Declaration callbacks execute in a separate VM, so inspection
            # cannot seed randomness or mutate state in the actual suite VM.
            run([str(prefix / 'bin/erl'), f'+S{args.schedulers}', '-noshell',
                 '-pa', str(suites), str(hooks), '-eval',
                 f'otp_ct_selection:write({args.suite},{erl_string(work / "selection-logs")},'
                 f'{erl_string(declaration)}),halt().'])
        ct_options = ""
        selection = {
            "observer_SUITE": "{testcase,[app_file,appup_file]},",
            "etop_SUITE": "{group,normal},",
            "crashdump_viewer_SUITE": "{testcase,[non_existing,not_a_crashdump,old_crashdump,new_crashdump,load_file,not_found_items]},",
        }.get(args.suite, "")
        if args.case:
            selection = "{testcase,[" + ",".join(args.case) + "]},"
        ct_options += selection
        if args.suite == "mnesia_install_test":
            # This unchanged sub-suite gets node allocation from mnesia_SUITE's
            # hook in the full hierarchy. Supply the same hook when run standalone.
            ct_options = "{ct_hooks,[{ts_install_cth,[{nodenames,2}]}]},"
        if ldap_dependency:
            ipv6_config = work / "ipv6.config"
            ipv6_config.write_text("{ipv6_hosts,['" + socket.gethostname().replace("'", "\\'") + "']}.\n"
                "{ldap_tls_options,[{verify,verify_peer},{cacertfile," +
                erl_string(work / 'ldap-server/ca.pem') + "}]}.\n")
            ct_options = f"{{config,{erl_string(ipv6_config)}}},"
        if odbc_dependency:
            ct_options += f'{{config,{erl_string(work / "odbc-driver.config")}}},'
        product_probe = ('ok=otp_ldap_probe:run(os:getenv("OTP_LDAP_CERT")), '
                         if ldap_dependency else "")
        origin_modules = ['ct', 'ct_run', 'erl_syntax_lib', 'compile']
        if args.suite in OBSERVER_SUITES:
            origin_modules += ['observer', 'etop', 'ttb', 'crashdump_viewer']
        elif args.suite in RELTOOL_SUITES:
            origin_modules += ['reltool', 'reltool_server', 'reltool_target']
        expression = (
            product_probe + f'Prefix={erl_string(prefix)}, '
            f'[true=lists:prefix(Prefix++"/",code:which(M)) || M <- [{",".join(origin_modules)}]], '
            f'Result=ct:run_test([{{dir,{erl_string(suites)}}},{{suite,{args.suite}}},'
            f'{ct_options}{{auto_compile,false}},{{logdir,{erl_string(logs)}}},'
            f'{{event_handler,{{otp_ct_event,[{erl_string(work / "events.log")}]}}}}]), '
            f'ok=file:write_file({erl_string(outcome)},io_lib:format("~tp.~n",[Result])), '
            'io:format("Upstream result: ~tp~n",[Result]), '
            f'case Result of {{{expected},0,{{0,0}}}} -> halt(0); _ -> halt(1) end.'
        )
        command = [str(prefix / "bin/erl"), f"+S{args.schedulers}", "-noshell", "-pa", str(suites), str(hooks), "-eval", expression]
        if args.inet_backend:
            command[1:1] = ["-kernel", "inet_backend", args.inet_backend]
        if args.suite == "sendfile_SUITE":
            command[1:1] = ["+A1"]
        if args.strace:
            command = [str(args.strace.resolve(strict=True)), "-ff", "-yy", "-tt",
                       "-e", "trace=dup,dup2,dup3,close,sendfile,fcntl,socket,accept,accept4,connect,shutdown,exit,exit_group",
                       "-o", str(work / "syscalls"), *command]
        if args.wx_product:
            command = [str(prefix / "bin/erl"), f"+S{args.schedulers}", "-noshell",
                       "-pa", str(suites), "-s", "otp_wx_probe", "run"]
        if args.suite in OS_MON_SUITES:
            # These unchanged suites start os_mon themselves and require SASL's
            # alarm service to have been booted by the test environment.
            command[1:1] = ["-boot", str(prefix / "bin/start_sasl")]
        if ldap_dependency:
            command = [bwrap, "--unshare-user", "--unshare-pid", "--unshare-net", "--die-with-parent",
                       "--ro-bind", "/", "/", "--bind", str(work), str(work),
                       "--dev", "/dev", "--proc", "/proc", "--chdir", str(work),
                       shutil.which("python3"), str(source / "tools/ldap_server.py"),
                       "--root", str(args.ldap_root), "--work", str(work), "--", *command]
        def execute_suite(command):
            if args.suite in OS_MON_SUITES:
                # Keep suite names out of the Erlang/bwrap argv as well: the
                # process-search assertion must observe real helper processes.
                script = work / "launch.erl"
                script.write_text(command[-1] + "\n")
                command = command[:-1] + [f'{{ok,_}}=file:script({erl_string(script)}),halt().']
            if args.suite in OS_MON_SUITES and sys.platform != 'darwin':
                # Port-kill cases must see only their own helper processes. Keep
                # shared networking for the explicitly selected private EPMD.
                command = [shutil.which("bwrap"), "--unshare-user", "--unshare-pid",
                           "--die-with-parent", "--ro-bind", "/", "/",
                           "--bind", str(work), str(work), "--dev", "/dev",
                           "--proc", "/proc", "--chdir", str(work), *command]
            isolated_suite = java_dependency or args.suite in set(DIALYZER_SUITES) | set(SNMP_SUITES) | set(MEGACO_SUITES) | set(DEBUGGER_SUITES) | set(TOOLS_SUITES) | (set(OS_MON_SUITES) if sys.platform == 'darwin' else set())
            if isolated_suite and sys.platform == 'darwin':
                from types import SimpleNamespace
                selected = installed['build'].get('sdk_selection') if installed else json.loads((build / 'sdk-selection.json').read_text())
                denied = [source]
                if build:
                    denied.append(build)
                if selected:
                    denied.append(Path(selected['prefix']))
                backend = SimpleNamespace(bwrap=Path(shutil.which('sandbox-exec')))
                command = [*seatbelt(backend, work, denied), *command]
            elif isolated_suite:
                # Only the relocated product, copied fixtures and system/JDK files
                # are visible. Neither the original SDK nor repository is mounted.
                isolation = [shutil.which("bwrap"), "--unshare-user", "--unshare-pid", "--die-with-parent"]
                for system_path in ("/usr", "/bin", "/lib", "/lib64", "/etc"):
                    if Path(system_path).exists():
                        isolation += ["--ro-bind", system_path, system_path]
                isolation += ["--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                              "--bind", str(work), str(work), "--chdir", str(work)]
                command = isolation + command
            if odbc_dependency:
                isolation = [shutil.which("bwrap"), "--unshare-user", "--unshare-pid",
                             "--unshare-net", "--die-with-parent"]
                for system_path in ("/usr", "/bin", "/lib", "/lib64", "/etc"):
                    if Path(system_path).exists():
                        isolation += ["--ro-bind", system_path, system_path]
                isolation += ["--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                              "--bind", str(work), str(work), "--chdir", str(work),
                              "--ro-bind", str(args.postgres_root), str(args.postgres_root)]
                command = isolation + [shutil.which("python3"), str(suites / "postgres_server.py"),
                    "--root", str(args.postgres_root), "--work", str(work),
                    "--prefix", str(prefix), "--probe", str(suites),
                    "--odbc-library",odbc_dependency['manager']['path'], "--", *command]
            if display_dependency:
                isolation = [shutil.which("bwrap"), "--unshare-user", "--unshare-pid",
                             "--unshare-net", "--die-with-parent"]
                for system_path in ("/usr", "/bin", "/lib", "/lib64", "/etc"):
                    if Path(system_path).exists():
                        isolation += ["--ro-bind", system_path, system_path]
                isolation += ["--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                              "--bind", str(work), str(work), "--chdir", str(work),
                              "--ro-bind", str(args.xvfb), str(args.xvfb)]
                command = isolation + [shutil.which("python3"), str(suites / "display_server.py"),
                    "--xvfb", str(args.xvfb), "--work", str(work),
                    *(["--timeout", "90"] if args.wx_product else []), "--", *command]
            # Preserve selection and input provenance even when CT reports failure.
            preparation = {"sdk": installed["build"].get("sdk_selection") if installed else json.loads((build / "sdk-selection.json").read_text()),
                           "installation": {"runtime": installed["runtime"], "flavor": installed["flavor"],
                                            "prefix": str(prefix), "original_prefix":str(args.prefix.resolve()),
                                            "private_copy":prefix != args.prefix.resolve(),
                                            "provenance_sha256": hashlib.sha256(args.provenance.read_bytes()).hexdigest()} if installed else None,
                           "runtime_images": {str(path.relative_to(prefix)): hashlib.sha256(path.read_bytes()).hexdigest()
                                              for pattern in ('erts-*/bin/beam.smp', 'erts-*/bin/erl_child_setup')
                                              for path in prefix.glob(pattern)},
                           "instrumented": bool(args.strace),
                           "async_threads": 1 if args.suite == "sendfile_SUITE" else None,
                           "suite": None if args.wx_product else args.suite,
                           "test_kind": "wx-product" if args.wx_product else "upstream-suite",
                           "expected_cases": None if args.wx_product else expected,
                           "case_selection": selection or "complete suite",
                           "normal_schedulers": args.schedulers,
                           "ftp_server": ftp_dependency, "ldap_server": ldap_dependency, "java": java_dependency,
                           "postgres": odbc_dependency, "display": display_dependency,
                           "source_sha256": manifest, "inet_backend": args.inet_backend,
                           "test_adaptations": adaptations,
                           "declared_selection": json.loads(declaration.read_text()) if declaration.exists() else None,
                           "harness_sha256": {name: hashlib.sha256((source / 'tools' / name).read_bytes()).hexdigest()
                                              for name in ('check_upstream.py', 'upstream_results.py', 'scratch.py')},
                           "peer_defaults": environment.get("ERL_AFLAGS"),
                           "private_hostname_lookup": {"hostname": socket.gethostname(), "address": "127.0.0.1",
                               "inetrc_sha256": hashlib.sha256(Path(environment['ERL_INETRC']).read_bytes()).hexdigest()}
                               if sys.platform == 'darwin' and environment.get('ERL_INETRC') else None,
                           "generated_snmp_mibs": ["Test2.bin"] if args.suite == "snmp_compiler_SUITE" else [],
                           "native_outputs": sorted(p.name for p in data.glob("*.so")) if native else []}
            (work / "preparation.json").write_text(json.dumps(preparation, indent=2) + "\n")
            succeeded = False
            try:
                run(command)
                succeeded = True
            finally:
                for relative, digest in manifest.items():
                    assert digest == hashlib.sha256((source / relative).read_bytes()).hexdigest()
                if args.wx_product:
                    record = dict(preparation, complete=succeeded)
                    (work / "result.json").write_text(json.dumps(record, indent=2) + "\n")
                elif outcome.exists():
                    result = outcome.read_text().strip()
                    match = re.fullmatch(r"\{(\d+),(\d+),\{(\d+),(\d+)\}\}\.", result)
                    if match:
                        passed, failed, user_skips, auto_skips = map(int, match.groups())
                        skipped_cases = []
                        for suite_log in logs.rglob("suite.log"):
                            for block in re.split(r"(?==case )", suite_log.read_text().replace("\r", "")):
                                case = re.search(r"^=case\s+(\S+)", block)
                                skipped = re.search(r"^=result\s+(auto_skipped|skipped): (.*)$", block, re.MULTILINE)
                                if case and skipped:
                                    skipped_cases.append({"case": case.group(1),
                                                          "kind": skipped.group(1), "reason": skipped.group(2)})
                        record = dict(preparation, result=result,
                                      suites={args.suite: {"passed": passed, "failed": failed,
                                              "skipped": user_skips + auto_skips,
                                              "user_skipped": user_skips, "auto_skipped": auto_skips}},
                                      skipped_cases=skipped_cases,
                                      complete=(passed, failed, user_skips, auto_skips) == (expected, 0, 0, 0))
                        try:
                            cases, configurations = case_results(work / 'events.log',
                                (passed, failed, user_skips, auto_skips))
                            record.update(cases=cases, configurations=configurations,
                                          case_evidence_complete=True)
                            record['complete'] = record['complete'] and all(
                                item['status'] == 'passed' for item in configurations)
                        except (ValueError, OSError) as error:
                            record.update(case_evidence_complete=False,
                                          case_evidence_error=str(error), complete=False)
                        (work / "result.json").write_text(json.dumps(record, indent=2) + "\n")
                        if not record['case_evidence_complete']:
                            raise RuntimeError(record['case_evidence_error'])
                        if succeeded and not record['complete']:
                            raise RuntimeError('Common Test configurations or case evidence did not pass')

        if native or java_dependency or args.suite in set(DIALYZER_SUITES) | set(SNMP_SUITES) | set(MEGACO_SUITES) | set(TOOLS_SUITES) or args.suite in {"asn1_SUITE", "mnesia_install_test", "eunit_SUITE", "memsup_SUITE"}:
            with socket.socket() as reservation:
                reservation.bind(("127.0.0.1", 0))
                epmd_port = reservation.getsockname()[1]
            environment.update(ERL_EPMD_PORT=str(epmd_port),
                               ERL_AFLAGS=f"+S{args.schedulers}:{args.schedulers} +SDcpu2:2 +SDio2 -start_epmd false")
            # Defaults precede each test's explicit switches, so a suite can still
            # select a different scheduler configuration for its peers.
            with (work / "epmd.log").open("w") as epmd_log:
                if sys.platform == 'darwin':
                    hostname = socket.gethostname()
                    names = list(dict.fromkeys([hostname, hostname.split('.')[0]]))
                    inetrc = work / 'inetrc'
                    inetrc.write_text('{lookup,[file,native]}.\n{host,{127,0,0,1},[' +
                                      ','.join(erl_string(name) for name in names) + ']}.\n')
                    environment['ERL_INETRC'] = str(inetrc)
                    addresses = '127.0.0.1'
                else:
                    addresses = ','.join(sorted({'127.0.0.1', socket.gethostbyname(socket.gethostname())}))
                daemon = subprocess.Popen([str(prefix / "bin/epmd"), "-port", str(epmd_port),
                                           "-address", addresses],
                                          cwd=work, env=environment,
                                          stdout=epmd_log, stderr=subprocess.STDOUT,
                                          start_new_session=True)
                try:
                    deadline = time.monotonic() + 10
                    while True:
                        if daemon.poll() is not None:
                            raise RuntimeError("Private test EPMD exited")
                        try:
                            with socket.create_connection(("127.0.0.1", epmd_port), timeout=0.2):
                                break
                        except OSError:
                            if time.monotonic() >= deadline:
                                raise RuntimeError("Private test EPMD did not listen")
                            time.sleep(0.02)
                    # Java and Observer fixtures derive peer names from the ordinary
                    # local hostname, including cleanup. A localhost alias differs.
                    local_hostname = java_dependency or args.suite in TOOLS_SUITES
                    node_name = f"ct_{os.getpid()}" + ("" if local_hostname else "@localhost")
                    node_args = ["-sname", node_name,
                                 "-setcookie", "otp_native_acceptance", "-start_epmd", "false"]
                    # Verify the default peer launcher resolves the candidate before
                    # handing control to unchanged suites which use CT_PEER.
                    peer_check = (f'{{ok,P,N}}=peer:start_link(#{{name => "origin_peer",args => ["-setcookie","otp_native_acceptance"]}}),'
                                  f'{erl_string(prefix)}=rpc:call(N,code,root_dir,[]),'
                                  f'{{ok,Maps}}=rpc:call(N,file,read_file,["/proc/self/maps"]),'
                                  f'{erl_string(next(prefix.glob("erts-*/bin/beam.smp")))}=element(2,rpc:call(N,file,read_link,["/proc/self/exe"])),'
                                  'nomatch=binary:match(Maps,<<"libbeam.so">>),'
                                  'ok=peer:stop(P),')
                    if sys.platform == 'darwin':
                        import shlex
                        # The peer reports its OS PID; a copied native helper inspects
                        # that live process rather than trusting VM-reported origins.
                        identity_expression(args.host_observer or build, work)
                        observer = work / 'host-observer'
                        host = next(prefix.glob('erts-*/bin/beam.smp'))
                        peer_check = (f'{{ok,P,N}}=peer:start_link(#{{name => "origin_peer",args => ["-setcookie","otp_native_acceptance"]}}),'
                                      f'{erl_string(prefix)}=rpc:call(N,code,root_dir,[]),'
                                      'PeerPid=rpc:call(N,os,getpid,[]),true=list_to_integer(PeerPid)>0,'
                                      '"STATIC_HOST_OK\\n"=rpc:call(N,os,cmd,['
                                      + erl_string(shlex.quote(str(observer)) + ' --verify-static ') + '++PeerPid++'
                                      + erl_string(' ' + shlex.quote(str(host))) + ']),ok=peer:stop(P),')
                    command = command[:-1] + [peer_check + expression]
                    command[1:1] = node_args
                    execute_suite(command)
                finally:
                    if daemon.poll() is None:
                        os.killpg(daemon.pid, signal.SIGTERM)
                        try:
                            daemon.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            os.killpg(daemon.pid, signal.SIGKILL)
                            daemon.wait()
                    if sys.platform == 'darwin':
                        observer = work / 'host-observer'
                        survivors = owned_processes(observer, work)
                        if survivors:
                            stop_owned_processes(observer, work)
                            raise RuntimeError(f'Owned runtime processes remained after upstream execution: {survivors}')
        else:
            execute_suite(command)
        if args.wx_product:
            print(f"wx product: three boots passed. Evidence: {work}")
        else:
            print(f"OTP {args.suite}: {expected} passed, no failures or skips. Evidence: {work}")


if __name__ == "__main__":
    main()
