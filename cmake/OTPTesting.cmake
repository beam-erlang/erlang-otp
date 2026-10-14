# Test preparation is CMake-owned; behavioral assertions remain upstream-owned.
# Reviewed setup adaptations are declared in tools/upstream-test-adaptations.json.
if(WIN32)
    if(BUILD_TESTING)
        add_test(NAME otp-windows-development
            COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_windows_product.py"
                --compiler "${CMAKE_C_COMPILER}" --ninja "${CMAKE_MAKE_PROGRAM}"
                --build-dir "${PROJECT_BINARY_DIR}" --work "${PROJECT_BINARY_DIR}/checks/windows"
                --cmake "${CMAKE_COMMAND}" --openssl "${OPENSSL_ROOT_DIR}/bin/openssl.exe"
                --flavor "${OTP_BEAM_FLAVOR}")
        set_tests_properties(otp-windows-development PROPERTIES TIMEOUT 600 RUN_SERIAL TRUE
            LABELS "installed;Windows;development")
    endif()
    # POSIX observation/isolation harnesses remain available on their platforms.
    return()
endif()
if(BUILD_TESTING)
    add_test(NAME otp-upstream-evidence
        COMMAND "${Python3_EXECUTABLE}" -m unittest discover
            -s "${PROJECT_SOURCE_DIR}/tools" -p test_upstream_results.py)
    set_tests_properties(otp-upstream-evidence PROPERTIES TIMEOUT 30 LABELS "checks;evidence")
    find_package(Threads REQUIRED)
    add_executable(otp_test_host_observer
        "${PROJECT_SOURCE_DIR}/tools/test_support/host_observer.c"
        "${PROJECT_SOURCE_DIR}/tools/test_support/host_observe.c")
    target_link_libraries(otp_test_host_observer PRIVATE Threads::Threads ${CMAKE_DL_LIBS})
    target_compile_options(otp_test_host_observer PRIVATE -Wall -Wextra -Werror)
    add_library(otp_test_observation_image MODULE "${PROJECT_SOURCE_DIR}/tools/test_support/image.c")
    add_test(NAME otp-test-support COMMAND "${Python3_EXECUTABLE}"
        "${PROJECT_SOURCE_DIR}/tools/test_support/check_observation.py"
        "$<TARGET_FILE:otp_test_host_observer>" "$<TARGET_FILE:otp_test_observation_image>")
    set_tests_properties(otp-test-support PROPERTIES TIMEOUT 30 LABELS "checks;native;observation")
    add_test(NAME otp-et-event-file
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_et_event_file.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --cmake "${CMAKE_COMMAND}")
    set_tests_properties(otp-et-event-file PROPERTIES TIMEOUT 120 LABELS "installed;et")
    add_executable(otp_host_preparation_probe
        "${PROJECT_SOURCE_DIR}/tools/fixtures/host_preparation.c"
        $<TARGET_OBJECTS:otp_host_inputs> "${PROJECT_BINARY_DIR}/generated/otp_erl_preloads.c")
    set(_allocation_fault_args)
    if(APPLE)
        target_sources(otp_host_preparation_probe PRIVATE "${PROJECT_SOURCE_DIR}/tools/test_support/host_observe.c")
        target_include_directories(otp_host_preparation_probe PRIVATE "${PROJECT_SOURCE_DIR}/tools/test_support")
        add_library(otp_test_allocation_fault SHARED "${PROJECT_SOURCE_DIR}/tools/test_support/allocation_fault.c")
        target_compile_features(otp_test_allocation_fault PRIVATE c_std_11)
        list(APPEND _allocation_fault_args --allocation-fault "$<TARGET_FILE:otp_test_allocation_fault>")
    endif()
    target_compile_features(otp_host_preparation_probe PRIVATE c_std_11)
    target_include_directories(otp_host_preparation_probe PRIVATE
        "${PROJECT_SOURCE_DIR}/tools" "${PROJECT_BINARY_DIR}/generated")
    target_link_libraries(otp_host_preparation_probe PRIVATE BEAM::RuntimeStatic ${_otp_linked_native} m)
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(otp_host_preparation_probe PRIVATE -Wall -Wextra -Werror)
    endif()
    set(_observer_preloads "${PROJECT_BINARY_DIR}/generated/boot-observer")
    set(_observer_files)
    foreach(_module IN LISTS _preloads)
        list(APPEND _observer_files "${_observer_preloads}/${_module}.beam")
    endforeach()
    otp_add_host(otp_boot_observer_host "${_observer_preloads}" ${_observer_files})
    set_target_properties(otp_boot_observer_host PROPERTIES EXCLUDE_FROM_ALL TRUE)
    add_test(NAME otp-native-activation
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_native_activation.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --sdk "${BEAM_SDK_ROOT}" --cmake "${CMAKE_COMMAND}" --bwrap "${OTP_BWRAP}")
    set_tests_properties(otp-native-activation PROPERTIES TIMEOUT 240
        LABELS "installed;relocated;isolated;native;ownership")
    add_test(NAME otp-host-preparation
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_host_preparation.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --sdk "${BEAM_SDK_ROOT}" --cmake "${CMAKE_COMMAND}" --bwrap "${OTP_BWRAP}"
            --probe "$<TARGET_FILE:otp_host_preparation_probe>" ${_allocation_fault_args})
    set_tests_properties(otp-host-preparation PROPERTIES TIMEOUT 240
        LABELS "installed;relocated;isolated;ownership;preparation")
    add_test(NAME otp-terminal-lifecycle
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_terminal.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --sdk "${BEAM_SDK_ROOT}" --cmake "${CMAKE_COMMAND}" --bwrap "${OTP_BWRAP}")
    set_tests_properties(otp-terminal-lifecycle PROPERTIES TIMEOUT 180
        LABELS "installed;relocated;isolated;terminal;ownership")
    add_test(NAME otp-boot-observer
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_boot_observer.py"
            --observer-host "$<TARGET_FILE:otp_boot_observer_host>"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --sdk "${BEAM_SDK_ROOT}" --cmake "${CMAKE_COMMAND}" --bwrap "${OTP_BWRAP}")
    set_tests_properties(otp-boot-observer PROPERTIES TIMEOUT 180
        LABELS "installed;relocated;isolated;ownership;restart")
    add_test(NAME otp-compatibility-transfer
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_compatibility.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --sdk "${BEAM_SDK_ROOT}" --cmake "${CMAKE_COMMAND}" --bwrap "${OTP_BWRAP}")
    set_tests_properties(otp-compatibility-transfer PROPERTIES TIMEOUT 300
        LABELS "installed;relocated;isolated;ownership")

    add_test(NAME otp-development-support
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_development_support.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --cc "${CMAKE_C_COMPILER}" --cmake "${CMAKE_COMMAND}")
    set_tests_properties(otp-development-support PROPERTIES TIMEOUT 180 LABELS "installed;native")
    set(OTP_REFERENCE_PREFIX "" CACHE PATH "Original-build OTP 29.0 reference of the selected flavor")
    set(OTP_REFERENCE_PROVENANCE "" CACHE FILEPATH "External original-build installation provenance")
    add_test(NAME otp-installed-tree
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_installed_tree.py"
            --build "${PROJECT_BINARY_DIR}" --cmake "${CMAKE_COMMAND}"
            --reference-prefix "${OTP_REFERENCE_PREFIX}"
            --reference-provenance "${OTP_REFERENCE_PROVENANCE}")
    set_tests_properties(otp-installed-tree PROPERTIES TIMEOUT 180 LABELS "installed;reference;layout")
    set(OTP_REBAR3_FILE "" CACHE FILEPATH "Pinned Rebar3 3.27.0 archive for standard release acceptance")
    add_test(NAME otp-standard-release
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_release.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --sdk "${BEAM_SDK_ROOT}" --rebar3 "${OTP_REBAR3_FILE}"
            --bwrap "${OTP_BWRAP}" --cmake "${CMAKE_COMMAND}")
    set_tests_properties(otp-standard-release PROPERTIES TIMEOUT 300
        LABELS "installed;relocated;isolated;release")
    add_test(NAME asn1-value-generation
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_asn1_values.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --cmake "${CMAKE_COMMAND}")
    set_tests_properties(asn1-value-generation PROPERTIES TIMEOUT 240)
    add_executable(otp_host_info_probe "${PROJECT_SOURCE_DIR}/tools/fixtures/host_info.c")
    target_link_libraries(otp_host_info_probe PRIVATE BEAM::RuntimeStatic)
    target_include_directories(otp_host_info_probe PRIVATE "${PROJECT_BINARY_DIR}/generated")
    add_test(NAME otp-command-policy
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_commands.py"
            --api-probe "$<TARGET_FILE:otp_host_info_probe>"
            --build "${PROJECT_BINARY_DIR}" --cmake "${CMAKE_COMMAND}" --source "${PROJECT_SOURCE_DIR}")
    set_tests_properties(otp-command-policy PROPERTIES TIMEOUT 180)
    find_program(OTP_XVFB NAMES Xvfb DOC "Xvfb executable for private graphical acceptance")
    option(OTP_ENABLE_WX_TESTS "Run deferred wx acceptance (known native lifetime and GTK child-policy failures)" OFF)
    # Retain the checks and assertions for explicit opt-in; disabled is not passed.
    add_test(NAME wx-product
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_upstream.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --cmake "${CMAKE_COMMAND}" --suite wx_app_SUITE --wx-product --xvfb "${OTP_XVFB}")
    set_tests_properties(wx-product PROPERTIES TIMEOUT 180 LABELS "wx;deferred")
    if(NOT OTP_ENABLE_WX_TESTS)
        set_tests_properties(wx-product PROPERTIES DISABLED TRUE)
    endif()
    set(OTP_POSTGRES_ROOT "" CACHE PATH "Extracted PostgreSQL 18 and psqlODBC for upstream ODBC acceptance")
    # The complete upstream RAM-file suite deliberately skips this case after
    # large_file_light creates its marker. Execute it unchanged in fresh state.
    add_test(NAME upstream-ram_file-heavy
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_upstream.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --cmake "${CMAKE_COMMAND}" --suite ram_file_SUITE --case large_file_heavy)
    set_tests_properties(upstream-ram_file-heavy PROPERTIES TIMEOUT 420 RUN_SERIAL TRUE
        LABELS "upstream;installed;ram-file;resource-heavy")
    set(OTP_LDAP_ROOT "" CACHE PATH "Extracted OpenLDAP dependency for upstream ELDAP interoperability")
    set(OTP_SHORT_TEST_ROOT "" CACHE PATH "Optional short scratch root for filename-to-atom tests")
    find_program(OTP_FTP_SERVER NAMES vsftpd DOC "vsftpd executable for upstream FTP interoperability")
    option(OTP_DISPOSABLE_WORKER "Run unchanged global process-kill suites on an explicitly disposable Darwin worker" OFF)
    foreach(_suite IN ITEMS prim_file_SUITE sendfile_SUITE zlib_SUITE zstd_SUITE ram_file_SUITE base64_SUITE math_SUITE queue_SUITE lists_SUITE dirty_nif_SUITE engine_SUITE asn1_app_SUITE syntax_SUITE error_SUITE asn1_SUITE pbe_SUITE pubkey_policy_tree_SUITE ssl_rfc_5869_SUITE ssl_cipher_SUITE tls_1_3_record_SUITE runtime_tools_SUITE dbg_SUITE mnesia_install_test inets_SUITE http_format_SUITE httpc_cookie_SUITE eunit_SUITE xmerl_sax_SUITE xmerl_sax_stream_SUITE xmerl_SUITE xmerl_xsd_SUITE ftp_format_SUITE tftp_SUITE ftp_SUITE ssh_basic_SUITE edoc_SUITE eep48_SUITE eldap_basic_SUITE diameter_app_SUITE diameter_compiler_SUITE diameter_codec_SUITE diameter_config_SUITE diameter_sync_SUITE diameter_reg_SUITE os_mon_SUITE cpu_sup_SUITE disksup_SUITE memsup_SUITE jinterface_SUITE nc_SUITE dialyzer_utils_SUITE dialyzer_SUITE dialyzer_cl_SUITE cplt_SUITE iplt_SUITE typer_SUITE abstract_SUITE incremental_SUITE snmp_app_SUITE snmp_compiler_SUITE snmp_pdus_SUITE snmp_conf_SUITE megaco_app_SUITE megaco_flex_SUITE megaco_binary_term_id_SUITE megaco_sdp_SUITE megaco_codec_mini_SUITE megaco_codec_v1_SUITE megaco_codec_v2_SUITE megaco_codec_v3_SUITE odbc_start_SUITE odbc_connect_SUITE odbc_query_SUITE odbc_data_type_SUITE et_SUITE observer_SUITE etop_SUITE ttb_SUITE crashdump_viewer_SUITE reltool_app_SUITE reltool_server_SUITE debugger_SUITE int_SUITE int_eval_SUITE int_break_SUITE wx_app_SUITE wx_basic_SUITE wx_event_SUITE wx_class_SUITE wx_xtra_SUITE wx_opengl_SUITE)
        set(_suite_args)
        if(APPLE AND OTP_DISPOSABLE_WORKER)
            list(APPEND _suite_args --disposable-worker)
        endif()
        if(OTP_SHORT_TEST_ROOT AND _suite MATCHES "^(dbg|eep48)_SUITE$")
            list(APPEND _suite_args --work-root "${OTP_SHORT_TEST_ROOT}")
        endif()
        if(_suite STREQUAL sendfile_SUITE)
            list(APPEND _suite_args --inet-backend inet)
        endif()
        if(_suite MATCHES "^(jinterface|nc)_SUITE$")
            list(APPEND _suite_args --java "${Java_JAVA_EXECUTABLE}" --javac "${Java_JAVAC_EXECUTABLE}")
        elseif(_suite MATCHES "^wx_")
            list(APPEND _suite_args --xvfb "${OTP_XVFB}")
        elseif(_suite MATCHES "^odbc_")
            list(APPEND _suite_args --postgres-root "${OTP_POSTGRES_ROOT}")
        elseif(_suite STREQUAL ftp_SUITE)
            list(APPEND _suite_args --ftp-server "${OTP_FTP_SERVER}")
        elseif(_suite STREQUAL eldap_basic_SUITE)
            list(APPEND _suite_args --ldap-root "${OTP_LDAP_ROOT}")
        endif()
        add_test(NAME "upstream-${_suite}"
            COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_upstream.py"
                --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
                --cmake "${CMAKE_COMMAND}" --suite "${_suite}" ${_suite_args})
        set_tests_properties("upstream-${_suite}" PROPERTIES LABELS upstream TIMEOUT 1320)
        if(APPLE AND NOT OTP_DISPOSABLE_WORKER AND _suite MATCHES "^(cpu_sup|disksup|memsup)_SUITE$")
            set_tests_properties("upstream-${_suite}" PROPERTIES LABELS "upstream;prerequisite-blocked;disposable-worker-required")
        endif()
        if(_suite MATCHES "^wx_")
            set_tests_properties("upstream-${_suite}" PROPERTIES LABELS "upstream;wx;deferred")
            if(NOT OTP_ENABLE_WX_TESTS)
                set_tests_properties("upstream-${_suite}" PROPERTIES DISABLED TRUE)
            endif()
        endif()
    endforeach()
    add_test(NAME upstream-sendfile_SUITE-socket
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_upstream.py"
            --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
            --cmake "${CMAKE_COMMAND}" --suite sendfile_SUITE --inet-backend socket)
    set_tests_properties(upstream-sendfile_SUITE-socket PROPERTIES LABELS upstream TIMEOUT 1320)
    set_tests_properties(upstream-asn1_SUITE upstream-dialyzer_utils_SUITE upstream-dialyzer_SUITE upstream-dialyzer_cl_SUITE upstream-cplt_SUITE upstream-iplt_SUITE upstream-typer_SUITE upstream-abstract_SUITE upstream-incremental_SUITE PROPERTIES TIMEOUT 7500)
endif()
