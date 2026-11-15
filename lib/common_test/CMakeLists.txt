# common_test application sources, generation and release rules.
otp_application_version(common_test _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_config_plain.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_config_xml.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_conn_log_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_cover.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_default_gl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_doctest.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_event.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_framework.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_ftp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_gen_conn.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_groups.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_hooks.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_hooks_lock.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_logs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_make.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_master.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_master_event.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_master_logs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_master_status.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_netconfc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_property_test.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_release_test.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_repeat.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_rpc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_run.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_slave.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_snmp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_ssh.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_suite.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_telnet.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_telnet_client.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_testspec.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_util.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cte_track.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cth_conn_log.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cth_log_redirect.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cth_surefire.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl2html2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/test_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/test_server_ctrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/test_server_gl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/test_server_io.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/test_server_node.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/test_server_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/unix_telnet.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP common_test
    SOURCES ${_sources}
    OPTIONS
        warn_obsolete_bool_op nowarn_deprecated_catch
        "{i,\"${PROJECT_SOURCE_DIR}/lib/snmp/include\"}"
    OWN_CODE_PATH
    NO_SOURCE_SUPPORT_INSTALL
    INPUTS ${_headers}
)
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_util.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ct_netconfc.hrl"
    DESTINATION "lib/common_test-${_version}/src")

set(_proper_ext_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/proper_ext/ct_proper_ext.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/proper_ext/ct_quickcheck_ext.erl")
set(_proper_ext_out "${PROJECT_BINARY_DIR}/lib/common_test/proper_ext")
otp_add_compile_job(TARGET otp_common_test_proper_ext APP common_test
    OUT "${_proper_ext_out}" GENERATED "${OTP_GENERATED_ROOT}/common_test/src"
    SOURCES ${_proper_ext_sources}
    OPTIONS warnings_as_errors warn_missing_doc_function warn_missing_doc_callback
        warn_missing_spec_documented warnings_as_errors
    DEPENDS ${_headers})
add_dependencies(otp_app_common_test otp_common_test_proper_ext)
install(FILES ${_proper_ext_sources}
    "${_proper_ext_out}/ct_proper_ext.beam" "${_proper_ext_out}/ct_quickcheck_ext.beam"
    DESTINATION "lib/common_test-${_version}/proper_ext")

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/priv" DESTINATION "lib/common_test-${_version}")
