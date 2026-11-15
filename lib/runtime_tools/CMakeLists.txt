# runtime_tools application sources, generation and release rules.
otp_application_version(runtime_tools _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/appmon_info.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dyntrace.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erts_alloc_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/instrument.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/msacc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_backend.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/runtime_tools.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/runtime_tools_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/scheduler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/system_information.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ttb_autostart.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP runtime_tools
    SOURCES ${_sources}
    OPTIONS nowarn_deprecated_catch
    INPUTS ${_headers}
)


# Runtime Tools uses public native interfaces; this SDK has no dynamic probes.


if(NOT DEFINED BEAM_SDK_DYNAMIC_TRACE OR NOT BEAM_SDK_DYNAMIC_TRACE STREQUAL "none")
    message(FATAL_ERROR "This OTP build requires an SDK declaring BEAM_SDK_DYNAMIC_TRACE=none")
endif()

otp_application_version(runtime_tools OTP_RUNTIME_TOOLS_VERSION)
set(_runtime_priv "lib/runtime_tools-${OTP_RUNTIME_TOOLS_VERSION}/priv/lib")

foreach(_kind IN ITEMS file ip)
    add_library(otp_trace_${_kind}_driver MODULE
        "${PROJECT_SOURCE_DIR}/lib/runtime_tools/c_src/trace_${_kind}_drv.c"
    )
    target_link_libraries(otp_trace_${_kind}_driver PRIVATE BEAM::Driver otp_native_config)
    set_target_properties(otp_trace_${_kind}_driver PROPERTIES
        PREFIX ""
        OUTPUT_NAME "trace_${_kind}_drv"
        C_VISIBILITY_PRESET hidden
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/runtime_tools/priv/lib/${OTP_TARGET}"
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/runtime_tools/priv/lib/${OTP_TARGET}"
    )
endforeach()

add_library(otp_dyntrace_nif MODULE "${PROJECT_SOURCE_DIR}/lib/runtime_tools/c_src/dyntrace.c")
target_link_libraries(otp_dyntrace_nif PRIVATE BEAM::NIF otp_native_config)
set_target_properties(otp_dyntrace_nif PROPERTIES
    PREFIX ""
    OUTPUT_NAME dyntrace
    C_VISIBILITY_PRESET hidden
    LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/runtime_tools/priv/lib/${OTP_TARGET}"
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/runtime_tools/priv/lib/${OTP_TARGET}"
)
foreach(_target IN ITEMS otp_trace_file_driver otp_trace_ip_driver otp_dyntrace_nif)
    otp_linux_native_flags(${_target} DED)
    if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
        target_compile_options(${_target} PRIVATE -g "$<IF:$<CONFIG:Debug>,-O0,-O2>"
            -Werror=undef -Werror=implicit -Werror=return-type
            -Wdeclaration-after-statement -Wall -Wstrict-prototypes -Wmissing-prototypes)
        target_compile_definitions(${_target} PRIVATE
            _THREAD_SAFE _REENTRANT POSIX_THREADS _POSIX_THREAD_SAFE_FUNCTIONS
            "$<$<CONFIG:Debug>:DEBUG>")
        set_target_properties(${_target} PROPERTIES C_VISIBILITY_PRESET default)
        if(CMAKE_BUILD_TYPE STREQUAL "Debug")
            set_target_properties(${_target} PROPERTIES DEBUG_POSTFIX ".debug")
            get_target_property(_name ${_target} OUTPUT_NAME)
            set(_alias "${PROJECT_BINARY_DIR}/lib/runtime_tools/priv/lib/${OTP_TARGET}/${_name}.so")
            # The original Erlang loaders use ordinary names even in Debug.
            # Keep one typed native module and a relative alias to that module.
            add_custom_command(TARGET ${_target} POST_BUILD BYPRODUCTS "${_alias}"
                COMMAND "${CMAKE_COMMAND}" -E rm -f "${_alias}"
                COMMAND "${CMAKE_COMMAND}" -E create_symlink "$<TARGET_FILE_NAME:${_target}>"
                    "${_alias}" VERBATIM)
            install(FILES "${_alias}" DESTINATION "${_runtime_priv}")
        endif()
    endif()
endforeach()
install(TARGETS
    otp_trace_file_driver
    otp_trace_ip_driver
    otp_dyntrace_nif
    LIBRARY DESTINATION "${_runtime_priv}"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    RUNTIME DESTINATION "${_runtime_priv}"
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)
