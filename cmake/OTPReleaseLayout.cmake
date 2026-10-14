# SPDX-License-Identifier: Apache-2.0
# Finalize the same release tree as upstream's release + Install -minimal.
set(_release_generated "${PROJECT_BINARY_DIR}/generated/release")
file(READ "${PROJECT_SOURCE_DIR}/erts/start_scripts/start_all_example.rel.src" _all_release)
string(REPLACE "%SYS_VSN%" "${PROJECT_VERSION_MAJOR}" _all_release "${_all_release}")
foreach(_app IN ITEMS erts kernel stdlib sasl os_mon inets snmp mnesia)
    otp_application_version("${_app}" _version)
    # The pinned upstream example expands SNMPEA_VSN, which is unset. This
    # example resource does not determine the installed SNMP application version.
    if(_app STREQUAL snmp)
        set(_version "")
    endif()
    string(TOUPPER "${_app}" _token)
    string(REPLACE "%${_token}_VSN%" "${_version}" _all_release "${_all_release}")
endforeach()
file(CONFIGURE OUTPUT "${_release_generated}/start_all_example.rel" CONTENT "${_all_release}" @ONLY)
install(FILES "${_release_generated}/start_all_example.rel"
    "${PROJECT_SOURCE_DIR}/OTP_VERSION" "${PROJECT_SOURCE_DIR}/sys.config"
    DESTINATION "${_release_directory}")
set(_installed_versions)
# Upstream appends this resource in lib/Makefile traversal order, before ERTS.
set(_release_app_order stdlib sasl kernel compiler
    tools common_test runtime_tools inets parsetools
    xmerl edoc snmp erl_interface asn1 jinterface wx debugger reltool
    mnesia crypto os_mon syntax_tools public_key ssl observer odbc diameter
    et megaco eunit ssh eldap dialyzer ftp tftp)
set(_release_apps ${_release_app_order})
set(_selected_apps ${OTP_APPLICATIONS})
list(SORT _release_apps)
list(SORT _selected_apps)
if(NOT _release_apps STREQUAL _selected_apps)
    message(FATAL_ERROR "Release application ordering does not cover the selected inventory")
endif()
foreach(_app IN LISTS _release_app_order)
    otp_application_version("${_app}" _version)
    string(APPEND _installed_versions "${_app}-${_version}\n")
endforeach()
string(APPEND _installed_versions "erts-${_erts_version}\n")
file(CONFIGURE OUTPUT "${_release_generated}/installed_application_versions"
    CONTENT "${_installed_versions}" @ONLY)
install(FILES "${_release_generated}/installed_application_versions"
    DESTINATION "${_release_directory}"
    PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ GROUP_WRITE WORLD_READ)
add_custom_command(OUTPUT "${_release_generated}/RELEASES.src"
    COMMAND ${OTP_BUILD_COMMAND} release-index
        "${PROJECT_BINARY_DIR}/otp/lib/sasl-${_sasl_version}/ebin"
        "${PROJECT_BINARY_DIR}/otp/bin/start_sasl.rel" "${_release_generated}" "${OTP_BUILD_ROOT}"
    DEPENDS otp_boot "${_otp_driver}" otp_build_host
    COMMENT "Generating the standard OTP release index" VERBATIM)
add_custom_target(otp_release_index ALL DEPENDS "${_release_generated}/RELEASES.src")
install(FILES "${_release_generated}/RELEASES.src" DESTINATION releases)
# Upstream uses install -d for assembly parents. Darwin's BSD install creates
# them with 0755; GNU install follows the reference's 0002 umask (0775).
# Install itself creates bin/releases with mkdir, and its epmd link uses umask.
set(_release_parents . bin lib usr releases "erts-${_erts_version}/lib" "lib/erts-${_erts_version}")
foreach(_app IN LISTS OTP_APPLICATIONS)
    otp_application_version("${_app}" _version)
    list(APPEND _release_parents "lib/${_app}-${_version}")
    if(_app MATCHES "^(asn1|crypto|megaco|observer|os_mon|runtime_tools|snmp)$")
        list(APPEND _release_parents "lib/${_app}-${_version}/priv")
    elseif(_app MATCHES "^(diameter|erl_interface)$")
        list(APPEND _release_parents "lib/${_app}-${_version}/src")
    elseif(_app STREQUAL wx)
        list(APPEND _release_parents "lib/wx-${_version}/doc" "lib/wx-${_version}/doc/examples")
    elseif(_app STREQUAL jinterface)
        foreach(_directory IN ITEMS java_src java_src/com java_src/com/ericsson java_src/com/ericsson/otp)
            list(APPEND _release_parents "lib/jinterface-${_version}/${_directory}")
        endforeach()
    endif()
endforeach()
foreach(_directory IN LISTS _release_parents)
    set(_group_write GROUP_WRITE)
    if(APPLE AND NOT _directory MATCHES "^(bin|releases)$")
        set(_group_write)
    endif()
    install(DIRECTORY DESTINATION "${_directory}" DIRECTORY_PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ ${_group_write} GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endforeach()
# Run last, after all retained commands and release resources are installed.
if(WIN32)
    install(FILES ${_boot_outputs} DESTINATION bin)
    install(FILES "${PROJECT_BINARY_DIR}/otp/bin/start_clean.boot" DESTINATION bin RENAME start.boot)
    install(FILES "${PROJECT_BINARY_DIR}/otp/bin/start_clean.script" DESTINATION bin RENAME start.script)
    configure_file("${PROJECT_SOURCE_DIR}/cmake/OTPWindowsInstall.cmake.in"
        "${PROJECT_BINARY_DIR}/generated/windows-install.cmake" @ONLY)
    install(SCRIPT "${PROJECT_BINARY_DIR}/generated/windows-install.cmake")
    return()
endif()
install(CODE [[
    set(_cross)
    if(NOT "$ENV{DESTDIR}" STREQUAL "")
        set(_cross -cross)
    endif()
    execute_process(COMMAND /bin/sh -c "umask 002; exec /bin/sh ./Install \"$@\"" otp-install ${_cross} -minimal "${CMAKE_INSTALL_PREFIX}"
        WORKING_DIRECTORY "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}"
        COMMAND_ERROR_IS_FATAL ANY)
    file(CHMOD "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/releases/RELEASES"
        "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/releases/start_erl.data"
        PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ GROUP_WRITE WORLD_READ)
]])
