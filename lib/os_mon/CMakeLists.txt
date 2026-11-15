# os_mon application sources, generation and release rules.
otp_application_version(os_mon _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/os_mon.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/os_mon_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/os_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/disksup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/memsup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cpu_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/os_mon_sysinfo.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/nteventlog.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP os_mon
    SOURCES ${_sources}
    INPUTS ${_headers}
    NO_INCLUDE_INSTALL
)


# Upstream os_mon port programs on the supported native Linux/macOS targets.
# They communicate over stdin/stdout; neither program links a VM implementation.

otp_application_version(os_mon _os_mon_version)

if(WIN32)
    set(_os_mon_helpers win32sysinfo nteventlog)
else()
    set(_os_mon_helpers cpu_sup memsup)
endif()
foreach(_helper IN LISTS _os_mon_helpers)
    if(_helper STREQUAL nteventlog)
        set(_helper_sources)
        foreach(_part main util registry pipe_stdin format)
            list(APPEND _helper_sources "${CMAKE_CURRENT_SOURCE_DIR}/c_src/nteventlog/elog_${_part}.c")
        endforeach()
        add_executable(otp_${_helper} ${_helper_sources})
    else()
    add_executable(otp_${_helper} "${PROJECT_SOURCE_DIR}/lib/os_mon/c_src/${_helper}.c")
    endif()
    otp_linux_native_flags(otp_${_helper} HIDDEN)
    if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
        target_link_libraries(otp_${_helper} PRIVATE otp_native_config)
        target_compile_options(otp_${_helper} PRIVATE -O2 -g
            -Werror=undef -Werror=implicit -Werror=return-type)
    endif()
    if(WIN32)
        target_sources(otp_${_helper} PRIVATE "${PROJECT_SOURCE_DIR}/erts/etc/win32/port_entry.c")
        target_compile_definitions(otp_${_helper} PRIVATE __WIN32__ _CRT_SECURE_NO_DEPRECATE)
        target_link_options(otp_${_helper} PRIVATE /ENTRY:erl_port_entry)
        target_link_libraries(otp_${_helper} PRIVATE advapi32 user32)
    endif()
    set_target_properties(otp_${_helper} PROPERTIES
        OUTPUT_NAME "${_helper}"
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/os_mon/priv/bin/${OTP_TARGET}"
    )
    install(TARGETS otp_${_helper} RUNTIME DESTINATION "lib/os_mon-${_os_mon_version}/priv/bin")
endforeach()

if(WIN32)
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/c_src/"
        DESTINATION "lib/os_mon-${_os_mon_version}/src"
        FILES_MATCHING PATTERN "*.c" PATTERN "*.h")
else()
install(FILES
    "${PROJECT_SOURCE_DIR}/lib/os_mon/c_src/cpu_sup.c"
    "${PROJECT_SOURCE_DIR}/lib/os_mon/c_src/memsup.c"
    DESTINATION "lib/os_mon-${_os_mon_version}/src"
)
endif()
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/memsup.hrl"
    DESTINATION "lib/os_mon-${_os_mon_version}/src")
