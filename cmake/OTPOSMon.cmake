# OS Monitor helpers are application-owned standalone port programs.
# They use OS interfaces only; no VM-private headers or second runtime.
if(WIN32)
    add_executable(otp_win32sysinfo "${PROJECT_SOURCE_DIR}/lib/os_mon/c_src/win32sysinfo.c")
    set_target_properties(otp_win32sysinfo PROPERTIES OUTPUT_NAME win32sysinfo
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/lib/os_mon-${_version}/priv/bin")
    install(TARGETS otp_win32sysinfo RUNTIME DESTINATION "lib/os_mon-${_version}/priv/bin")
    install(FILES ${_sources} DESTINATION "lib/os_mon-${_version}/src")
    return()
endif()
if(NOT CMAKE_SYSTEM_NAME MATCHES "^(Linux|Darwin)$")
    message(FATAL_ERROR "OS Monitor native assembly requires Linux or Darwin")
endif()
foreach(_helper IN ITEMS cpu_sup memsup)
    add_executable(otp_os_mon_${_helper}
        "${PROJECT_SOURCE_DIR}/lib/os_mon/c_src/${_helper}.c")
    set_target_properties(otp_os_mon_${_helper} PROPERTIES
        OUTPUT_NAME "${_helper}"
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/lib/os_mon-${_version}/priv/bin")
    install(TARGETS otp_os_mon_${_helper}
        RUNTIME DESTINATION "lib/os_mon-${_version}/priv/bin")
endforeach()
install(FILES ${_sources} "${PROJECT_SOURCE_DIR}/lib/os_mon/include/memsup.hrl"
    "${PROJECT_SOURCE_DIR}/lib/os_mon/c_src/cpu_sup.c"
    "${PROJECT_SOURCE_DIR}/lib/os_mon/c_src/memsup.c"
    DESTINATION "lib/os_mon-${_version}/src")
