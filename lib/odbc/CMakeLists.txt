# The driver manager and EI are explicit dependencies of the ODBC port program.

if(WIN32)
    # Use the same explicitly selected Windows SDK as the native toolchain.
    find_package(ODBC REQUIRED)
else()
set(ODBC_CONFIG "$ENV{ODBC_CONFIG}" CACHE FILEPATH "Explicit installed ODBC config program")
if(ODBC_CONFIG)
if(NOT IS_ABSOLUTE "${ODBC_CONFIG}" OR NOT EXISTS "${ODBC_CONFIG}" OR IS_DIRECTORY "${ODBC_CONFIG}")
    message(FATAL_ERROR "Set ODBC_CONFIG to an explicit absolute installed odbc_config or iodbc-config")
endif()
execute_process(COMMAND "${ODBC_CONFIG}" --version
    RESULT_VARIABLE _odbc_status OUTPUT_VARIABLE _odbc_version ERROR_VARIABLE _odbc_error)
if(NOT _odbc_status EQUAL 0)
    message(FATAL_ERROR "Selected ODBC config failed: ${_odbc_error}")
endif()
execute_process(COMMAND "${ODBC_CONFIG}" --cflags
    OUTPUT_VARIABLE _odbc_cflags OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND "${ODBC_CONFIG}" --libs
    OUTPUT_VARIABLE _odbc_libraries OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
separate_arguments(_odbc_cflags NATIVE_COMMAND "${_odbc_cflags}")
separate_arguments(_odbc_libraries NATIVE_COMMAND "${_odbc_libraries}")
set(_odbc_include_paths)
set(_odbc_library_paths)
set(_odbc_library_names)
foreach(_flag IN LISTS _odbc_cflags)
    if(_flag MATCHES "^-I(.+)$")
        list(APPEND _odbc_include_paths "${CMAKE_MATCH_1}")
    endif()
endforeach()
foreach(_flag IN LISTS _odbc_libraries)
    if(_flag MATCHES "^-L(.+)$")
        list(APPEND _odbc_library_paths "${CMAKE_MATCH_1}")
    elseif(_flag MATCHES "^-l(.+odbc.*|odbc)$")
        list(APPEND _odbc_library_names "${CMAKE_MATCH_1}")
    endif()
endforeach()
find_path(_selected_odbc_include NAMES sql.h
    PATHS ${_odbc_include_paths} NO_DEFAULT_PATH NO_CACHE)
find_library(_selected_odbc_library NAMES ${_odbc_library_names}
    PATHS ${_odbc_library_paths} NO_DEFAULT_PATH NO_CACHE)
if(NOT _selected_odbc_include OR NOT _selected_odbc_library)
    message(FATAL_ERROR "Selected ODBC config does not identify usable include and library directories")
endif()
set(ODBC_INCLUDE_DIR "${_selected_odbc_include}")
set(ODBC_LIBRARY "${_selected_odbc_library}")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${ODBC_CONFIG}")
else()
    # Like upstream's --with-odbc prefix, select native files without a config
    # program. Separate paths also accommodate native multiarch installations.
    if(NOT IS_ABSOLUTE "${ODBC_INCLUDE_DIR}" OR NOT EXISTS "${ODBC_INCLUDE_DIR}/sql.h"
        OR NOT IS_ABSOLUTE "${ODBC_LIBRARY}" OR NOT EXISTS "${ODBC_LIBRARY}"
        OR IS_DIRECTORY "${ODBC_LIBRARY}")
        message(FATAL_ERROR
            "Set ODBC_CONFIG, or both ODBC_INCLUDE_DIR and ODBC_LIBRARY to existing absolute native paths")
    endif()
endif()
find_package(ODBC REQUIRED)
endif()
find_package(Threads REQUIRED)
include(CheckCSourceCompiles)
include(CMakePushCheckState)
cmake_push_check_state(RESET)
set(CMAKE_REQUIRED_LIBRARIES ODBC::ODBC)
# Recheck the selected headers/library when dependencies change on reconfigure.
unset(OTP_ODBC_SQL_ALLOC_HANDLE CACHE)
check_c_source_compiles("#ifdef _WIN32\n#include <windows.h>\n#endif\n#include <sql.h>\n#include <sqlext.h>\nint main(void) { SQLHANDLE h; return SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &h); }"
    OTP_ODBC_SQL_ALLOC_HANDLE)
if(NOT OTP_ODBC_SQL_ALLOC_HANDLE)
    message(FATAL_ERROR "Selected ODBC driver manager lacks usable headers or SQLAllocHandle")
endif()
set(CMAKE_REQUIRED_LIBRARIES "")
if(NOT WIN32)
check_c_source_compiles("#include <netinet/in.h>\nint main(void) { struct sockaddr_in6 s; return sizeof(s.sin6_addr) == 0; }"
    OTP_ODBC_SOCKADDR_IN6)
set(CMAKE_REQUIRED_FLAGS "-Werror")
check_c_source_compiles("#pragma GCC diagnostic ignored \"-Wstringop-truncation\"\nint main(void) { return 0; }"
    OTP_ODBC_GCC_DIAGNOSTIC)
cmake_pop_check_state()
else()
    cmake_pop_check_state()
endif()

otp_application_version(odbc _version)
install(DIRECTORY DESTINATION "lib/odbc-${_version}/priv/obj")
set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/odbc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/odbc_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/odbc_sup.erl"
)
set(_odbc_debug_options)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(_odbc_debug_options "{d,debug}")
endif()
otp_add_application(APP odbc
    SOURCES ${_sources}
    OPTIONS ${_odbc_debug_options} nowarn_deprecated_catch
        "{d,'SERVER_SOFTWARE',\"odbc/${_version}\"}"
        "{parse_transform,sys_pre_attributes}"
        "{attribute,insert,app_vsn,\"odbc-${_version}\"}"
    INPUTS "${CMAKE_CURRENT_SOURCE_DIR}/src/odbc_internal.hrl"
        "${CMAKE_CURRENT_SOURCE_DIR}/include/odbc.hrl"
)

add_executable(otp_odbcserver "${CMAKE_CURRENT_SOURCE_DIR}/c_src/odbcserver.c")
if(WIN32)
    target_compile_definitions(otp_odbcserver PRIVATE __WIN32__ WIN32)
    target_sources(otp_odbcserver PRIVATE "${PROJECT_SOURCE_DIR}/erts/etc/win32/port_entry.c")
    target_link_options(otp_odbcserver PRIVATE /ENTRY:erl_port_entry)
    target_link_libraries(otp_odbcserver PRIVATE ws2_32)
else()
    target_compile_definitions(otp_odbcserver PRIVATE UNIX)
endif()
if(OTP_ODBC_SOCKADDR_IN6)
    target_compile_definitions(otp_odbcserver PRIVATE HAVE_STRUCT_SOCKADDR_IN6_SIN6_ADDR)
endif()
if(OTP_ODBC_GCC_DIAGNOSTIC)
    target_compile_definitions(otp_odbcserver PRIVATE HAVE_GCC_DIAG_IGNORE_WSTRINGOP_TRUNCATION)
endif()
target_link_libraries(otp_odbcserver PRIVATE otp_ei ODBC::ODBC Threads::Threads)
otp_linux_native_flags(otp_odbcserver NO_LINK_HARDENING)
if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
    # Upstream keeps -O2 in Debug and also uses CFLAGS for the final CC link.
    target_compile_options(otp_odbcserver PRIVATE -g -O2 -Werror=return-type)
    target_compile_definitions(otp_odbcserver PRIVATE
        _THREAD_SAFE _REENTRANT POSIX_THREADS _POSIX_THREAD_SAFE_FUNCTIONS)
    target_link_options(otp_odbcserver PRIVATE ${OTP_LINUX_NATIVE_CFLAGS} -g -O2)
endif()
set_target_properties(otp_odbcserver PROPERTIES
    OUTPUT_NAME odbcserver
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/odbc/priv/bin/${OTP_TARGET}"
)
install(TARGETS otp_odbcserver RUNTIME DESTINATION "lib/odbc-${_version}/priv/bin")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/c_src/odbcserver.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/odbcserver.h"
    DESTINATION "lib/odbc-${_version}/c_src")
