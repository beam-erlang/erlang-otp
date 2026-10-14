# OTP-owned tracing drivers build against the installed public driver SDK.
# Dynamic tracing selects its backend through the public SDK capability query.
otp_application_version(runtime_tools _runtime_tools_version)
set(_runtime_tools_priv "lib/runtime_tools-${_runtime_tools_version}/priv/lib")
include(CheckCSourceCompiles)
if(WIN32)
    set(OTP_TRACE_HAS_SOCKLEN_T TRUE)
else()
check_c_source_compiles("#include <sys/types.h>
#include <sys/socket.h>
int main(void) { socklen_t size = 0; return (int)size; }" OTP_TRACE_HAS_SOCKLEN_T)
endif()
if(NOT OTP_TRACE_HAS_SOCKLEN_T)
    message(FATAL_ERROR "OTP tracing requires the platform socket length type")
endif()
foreach(_kind IN ITEMS file ip)
    set(_module "trace_${_kind}_drv")
    set(_target "otp_trace_${_kind}_driver")
    set(_source "${PROJECT_SOURCE_DIR}/lib/runtime_tools/c_src/${_module}.c")
    add_library("${_target}" MODULE "${_source}")
    target_link_libraries("${_target}" PRIVATE BEAM::Driver)
    if(NOT WIN32)
        target_compile_definitions("${_target}" PRIVATE HAVE_SOCKLEN_T)
    endif()
    target_compile_definitions("${_target}" PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
    set_target_properties("${_target}" PROPERTIES PREFIX "" OUTPUT_NAME "${_module}"
        C_VISIBILITY_PRESET hidden
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/${_runtime_tools_priv}")
    install(TARGETS "${_target}"
        LIBRARY DESTINATION "${_runtime_tools_priv}"
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        RUNTIME DESTINATION "${_runtime_tools_priv}"
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    otp_register_native("${_target}" driver "${_module}" "${_source}"
        "${_runtime_tools_priv}/${_module}${CMAKE_SHARED_MODULE_SUFFIX}")
endforeach()
set(_dyntrace_source "${PROJECT_SOURCE_DIR}/lib/runtime_tools/c_src/dyntrace.c")
add_library(otp_dyntrace_nif MODULE "${_dyntrace_source}")
beam_target_nif(otp_dyntrace_nif)
target_compile_features(otp_dyntrace_nif PRIVATE c_std_11)
target_compile_definitions(otp_dyntrace_nif PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
target_include_directories(otp_dyntrace_nif PRIVATE
    "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common"
    "${PROJECT_SOURCE_DIR}/lib/runtime_tools/c_src")
if(OTP_NATIVE_TRACE_BACKEND MATCHES "^(dtrace|systemtap)$")
    target_compile_definitions(otp_dyntrace_nif PRIVATE HAVE_USE_DTRACE)
elseif(OTP_NATIVE_TRACE_BACKEND STREQUAL lttng)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(OTP_LTTNG REQUIRED IMPORTED_TARGET lttng-ust)
    target_compile_definitions(otp_dyntrace_nif PRIVATE USE_LTTNG)
    target_link_libraries(otp_dyntrace_nif PRIVATE PkgConfig::OTP_LTTNG)
endif()
set_target_properties(otp_dyntrace_nif PROPERTIES PREFIX "" OUTPUT_NAME dyntrace
    C_VISIBILITY_PRESET hidden
    LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/${_runtime_tools_priv}")
install(TARGETS otp_dyntrace_nif
    LIBRARY DESTINATION "${_runtime_tools_priv}"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    RUNTIME DESTINATION "${_runtime_tools_priv}"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
otp_register_native(otp_dyntrace_nif nif dyntrace "${_dyntrace_source}"
    "${_runtime_tools_priv}/dyntrace${CMAKE_SHARED_MODULE_SUFFIX}")
if(NOT OTP_NATIVE_TRACE_BACKEND STREQUAL "none")
install(DIRECTORY "${PROJECT_SOURCE_DIR}/lib/runtime_tools/examples"
    DESTINATION "lib/runtime_tools-${_runtime_tools_version}")
endif()
