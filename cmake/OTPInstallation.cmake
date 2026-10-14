# OTP-owned application and boot assembly around declared SDK artifacts.

file(GLOB _preload_headers CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/erts/preloaded/src/*.hrl")
add_custom_command(OUTPUT ${_preload_outputs}
    COMMAND ${OTP_BUILD_COMMAND}
        preloads "${PROJECT_SOURCE_DIR}" "${PROJECT_BINARY_DIR}/otp/${_preload_relative}"
        "${OTP_BUILD_ROOT}" ${_preload_sources}
    COMMAND ${OTP_BUILD_COMMAND}
        script "${PROJECT_SOURCE_DIR}/erts/preloaded/src/add_abstract_code" "${OTP_BUILD_ROOT}"
        "${PROJECT_BINARY_DIR}/otp/${_preload_relative}/prim_eval.beam"
        "${PROJECT_BINARY_DIR}/otp/${_preload_relative}/prim_eval.abstr"
    DEPENDS ${_preload_sources} ${_preload_headers} ${_otp_headers} "${_otp_driver}" otp_build_host
        "${PROJECT_SOURCE_DIR}/erts/preloaded/src/prim_eval.erl"
        "${PROJECT_SOURCE_DIR}/erts/preloaded/src/add_abstract_code"
    COMMENT "Compiling canonical OTP-owned preloads" VERBATIM)
add_custom_target(otp_preloads ALL DEPENDS ${_preload_outputs})

otp_application_version(kernel _kernel_version)
otp_application_version(stdlib _stdlib_version)
otp_application_version(compiler _compiler_version)
otp_application_version(sasl _sasl_version)
set(_boot_outputs)
set(_release_directory "releases/${PROJECT_VERSION_MAJOR}")
foreach(_boot_name IN ITEMS start_clean no_dot_erlang start_sasl)
    set(_boot "${PROJECT_BINARY_DIR}/otp/bin/${_boot_name}")
    set(_template "${PROJECT_SOURCE_DIR}/erts/start_scripts/${_boot_name}.rel.src")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_template}")
    file(READ "${_template}" _release)
    string(REPLACE "%SYS_VSN%" "${PROJECT_VERSION_MAJOR}" _release "${_release}")
    string(REPLACE "%ERTS_VSN%" "${_erts_version}" _release "${_release}")
    string(REPLACE "%KERNEL_VSN%" "${_kernel_version}" _release "${_release}")
    string(REPLACE "%STDLIB_VSN%" "${_stdlib_version}" _release "${_release}")
    string(REPLACE "%SASL_VSN%" "${_sasl_version}" _release "${_release}")
    file(CONFIGURE OUTPUT "${_boot}.rel" CONTENT "${_release}" @ONLY)
    add_custom_command(OUTPUT "${_boot}.script" "${_boot}.boot"
        COMMAND ${OTP_BUILD_COMMAND}
            boot "${PROJECT_BINARY_DIR}/otp/lib/sasl-${_sasl_version}/ebin"
            "${PROJECT_BINARY_DIR}/otp/lib" "${_boot}" "${OTP_BUILD_ROOT}"
        DEPENDS ${_otp_application_outputs} "${_boot}.rel" "${_otp_driver}" otp_build_host
        COMMENT "Generating ${_boot_name} from the retained OTP release template" VERBATIM)
    list(APPEND _boot_outputs "${_boot}.script" "${_boot}.boot")
endforeach()
add_custom_target(otp_boot ALL DEPENDS ${_boot_outputs})

otp_add_host(otp_erl "${PROJECT_BINARY_DIR}/otp/${_preload_relative}" ${_preload_outputs})
if(WIN32)
    # Native libraries such as OpenSSL use the process code page for DLL paths.
    if(MSVC)
        target_sources(otp_erl PRIVATE "${PROJECT_SOURCE_DIR}/tools/otp_windows.manifest")
    else()
        enable_language(RC)
        file(WRITE "${PROJECT_BINARY_DIR}/generated/otp_windows.rc"
            "#include <windows.h>\n1 RT_MANIFEST \"${PROJECT_SOURCE_DIR}/tools/otp_windows.manifest\"\n")
        target_sources(otp_erl PRIVATE "${PROJECT_BINARY_DIR}/generated/otp_windows.rc")
    endif()
endif()
set_target_properties(otp_erl PROPERTIES OUTPUT_NAME "beam.smp")
install(TARGETS otp_erl RUNTIME DESTINATION "erts-${_erts_version}/bin")
install(FILES ${_boot_outputs} DESTINATION "${_release_directory}")
foreach(_boot_name IN ITEMS start_clean no_dot_erlang start_sasl)
    install(FILES "${PROJECT_BINARY_DIR}/otp/bin/${_boot_name}.rel" DESTINATION "${_release_directory}")
endforeach()
install(FILES "${PROJECT_BINARY_DIR}/otp/bin/start_clean.boot" DESTINATION "${_release_directory}" RENAME start.boot)
install(FILES "${PROJECT_BINARY_DIR}/otp/bin/start_clean.script" DESTINATION "${_release_directory}" RENAME start.script)
install(FILES ${_preload_outputs} DESTINATION "${_preload_relative}")
beam_install_core_modules(DESTINATION "${_preload_relative}" SOURCE_DESTINATION "lib/erts-${_erts_version}/src")
install(FILES ${_preload_sources} "${PROJECT_SOURCE_DIR}/erts/preloaded/src/prim_eval.erl"
    DESTINATION "lib/erts-${_erts_version}/src")
set(_erts_template "${PROJECT_SOURCE_DIR}/erts/preloaded/src/erts.app.src")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_erts_template}")
file(READ "${_erts_template}" _erts_resource)
string(REPLACE "%VSN%" "${_erts_version}" _erts_resource "${_erts_resource}")
string(REPLACE "%ESOCK_MODS%" "prim_net, prim_socket, socket_registry," _erts_resource "${_erts_resource}")
file(CONFIGURE OUTPUT "${PROJECT_BINARY_DIR}/otp/${_preload_relative}/erts.app"
    CONTENT "${_erts_resource}" @ONLY)
install(FILES "${PROJECT_BINARY_DIR}/otp/${_preload_relative}/erts.app"
    DESTINATION "${_preload_relative}")
foreach(_app IN LISTS OTP_APPLICATIONS)
    otp_application_version("${_app}" _version)
    install(FILES ${OTP_INSTALL_${_app}_FILES} DESTINATION "lib/${_app}-${_version}/ebin")
    if(NOT _app MATCHES "^(erl_interface|sasl|ssl|os_mon)$" AND IS_DIRECTORY "${PROJECT_SOURCE_DIR}/lib/${_app}/include")
        install(DIRECTORY "${PROJECT_SOURCE_DIR}/lib/${_app}/include" DESTINATION "lib/${_app}-${_version}" PATTERN cello EXCLUDE)
    endif()
    if(_app STREQUAL common_test)
        install(DIRECTORY "${PROJECT_SOURCE_DIR}/lib/common_test/priv" DESTINATION "lib/${_app}-${_version}"
            PATTERN "*.license" EXCLUDE PATTERN vendor.info EXCLUDE)
    elseif(_app STREQUAL edoc)
        install(FILES "${PROJECT_SOURCE_DIR}/lib/edoc/priv/stylesheet.css"
            "${PROJECT_SOURCE_DIR}/lib/edoc/priv/erlang.png"
            "${PROJECT_SOURCE_DIR}/lib/edoc/priv/edoc.dtd"
            DESTINATION "lib/edoc-${_version}/priv")
        install(PROGRAMS "${PROJECT_SOURCE_DIR}/lib/edoc/bin/edoc" DESTINATION "lib/edoc-${_version}/bin")
        install(PROGRAMS "${PROJECT_SOURCE_DIR}/lib/edoc/priv/edoc_generate" DESTINATION "lib/edoc-${_version}/priv")
    elseif(_app STREQUAL tools)
        install(FILES "${PROJECT_SOURCE_DIR}/lib/tools/priv/styles.css"
            DESTINATION "lib/${_app}-${_version}/priv")
    elseif(_app MATCHES "^(ssl|mnesia|inets|eunit|xmerl|ftp|tftp|ssh|eldap)$")
        install(DIRECTORY "${PROJECT_SOURCE_DIR}/lib/${_app}/src" DESTINATION "lib/${_app}-${_version}"
            FILES_MATCHING PATTERN "*.erl" PATTERN "*.hrl" PATTERN ftp_internal.hrl EXCLUDE)
    endif()
    if(_app STREQUAL xmerl)
        install(DIRECTORY "${PROJECT_SOURCE_DIR}/lib/xmerl/src/"
            DESTINATION "lib/xmerl-${_version}/src"
            FILES_MATCHING PATTERN "*.yrl" PATTERN "*.app.src" PATTERN "*.appup.src"
            PATTERN "xmerl_xsd_re_parse.yrl" EXCLUDE)
    endif()
    if(_app MATCHES "^(mnesia|ssh)$")
        install(DIRECTORY DESTINATION "lib/${_app}-${_version}/include")
    elseif(_app STREQUAL odbc)
        install(DIRECTORY DESTINATION "lib/${_app}-${_version}/priv/obj")
    endif()
endforeach()
if(NOT WIN32)
beam_get_runtime_artifact(_child_helper NAME helper.child_setup KIND executable-helper)
file(SHA256 "${_child_helper}" _child_helper_sha256)
install(CODE "file(SHA256 [==[${_child_helper}]==] _actual)\nif(NOT _actual STREQUAL [==[${_child_helper_sha256}]==])\n  message(FATAL_ERROR \"Selected SDK child helper changed after configuration\")\nendif()")
install(PROGRAMS "${_child_helper}" DESTINATION "erts-${_erts_version}/bin")
endif()
beam_install_native_headers(DESTINATION usr/include ARTIFACTS header.erl_nif header.erl_driver)
beam_install_native_headers(DESTINATION "erts-${_erts_version}/include" ARTIFACTS header.erl_nif header.erl_driver)
foreach(_destination IN ITEMS usr/include "erts-${_erts_version}/include")
    if(WIN32)
        set(_driver_int "${PROJECT_SOURCE_DIR}/erts/emulator/sys/win32/driver_int.h")
    else()
        set(_driver_int "${PROJECT_SOURCE_DIR}/erts/emulator/sys/unix/driver_int.h")
    endif()
    install(FILES "${_driver_int}"
        "${PROJECT_SOURCE_DIR}/erts/include/erl_fixed_size_int_types.h" DESTINATION "${_destination}")
endforeach()

if(BUILD_TESTING)
    add_test(NAME otp-host-public-boundary
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_sdk_boundary.py"
            --executable "$<TARGET_FILE:otp_erl>" --source "${PROJECT_SOURCE_DIR}/tools/otp_host.c"
            --source "${PROJECT_SOURCE_DIR}/tools/otp_host_inputs.c"
            --compile-commands "${PROJECT_BINARY_DIR}/compile_commands.json"
            --sdk "${BEAM_SDK_ROOT}" --nm "${CMAKE_NM}" --execution process)
    add_test(NAME initial-product
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_product.py"
            --build "${PROJECT_BINARY_DIR}" --cmake "${CMAKE_COMMAND}"
            --source "${PROJECT_SOURCE_DIR}" --sdk "${BEAM_SDK_ROOT}" --flavor "${OTP_BEAM_FLAVOR}"
            --cc "${CMAKE_C_COMPILER}")
    set_tests_properties(initial-product PROPERTIES TIMEOUT 120)
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        find_program(OTP_BWRAP NAMES sandbox-exec PATHS /usr/bin NO_DEFAULT_PATH)
    else()
        find_program(OTP_BWRAP bwrap)
    endif()
    if(NOT OTP_BWRAP)
        set(OTP_BWRAP "")
    endif()
    add_test(NAME isolated-product
        COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_product.py"
            --build "${PROJECT_BINARY_DIR}" --cmake "${CMAKE_COMMAND}"
            --source "${PROJECT_SOURCE_DIR}" --sdk "${BEAM_SDK_ROOT}" --flavor "${OTP_BEAM_FLAVOR}"
            --cc "${CMAKE_C_COMPILER}" --bwrap "${OTP_BWRAP}")
    set_tests_properties(isolated-product PROPERTIES TIMEOUT 120)

endif()
