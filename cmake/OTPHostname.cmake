# SPDX-License-Identifier: Apache-2.0
# The native resolver is an OTP service, independent of VM-private headers.
if(WIN32)
    file(CONFIGURE OUTPUT "${PROJECT_BINARY_DIR}/generated/otp_hostname_config.h" CONTENT
        "/* Native Winsock resolver. */\n#define HAVE_GETADDRINFO 1\n#define HAVE_GETNAMEINFO 1\n#define HAVE_IN6 1\n#define HAVE_IN6ADDR_ANY 1\n#define HAVE_IN6ADDR_LOOPBACK 1\n#define NO_SA_LEN 1\n" @ONLY)
else()
include(CMakePushCheckState)
include(CheckIncludeFile)
include(CheckSymbolExists)
include(CheckCSourceCompiles)
cmake_push_check_state(RESET)
set(CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
set(_hostname_config "/* OTP-owned native resolver configuration. */\n")
check_include_file(sys/time.h OTP_HOSTNAME_HAVE_SYS_TIME_H)
if(OTP_HOSTNAME_HAVE_SYS_TIME_H)
    string(APPEND _hostname_config "#define HAVE_SYS_TIME_H 1\n")
endif()
foreach(_function IN ITEMS getaddrinfo getnameinfo gethostbyname2)
    string(TOUPPER "${_function}" _name)
    check_symbol_exists("${_function}" "sys/types.h;sys/socket.h;netdb.h"
        "OTP_HOSTNAME_HAVE_${_name}")
    if(OTP_HOSTNAME_HAVE_${_name})
        string(APPEND _hostname_config "#define HAVE_${_name} 1\n")
    endif()
endforeach()
check_c_source_compiles("#include <netinet/in.h>\nint main(void) { struct in6_addr a; return sizeof(a)!=16; }"
    OTP_HOSTNAME_HAVE_IN6)
if(OTP_HOSTNAME_HAVE_IN6)
    string(APPEND _hostname_config "#define HAVE_IN6 1\n")
endif()
check_c_source_compiles("#include <sys/types.h>\n#include <sys/socket.h>\nint main(void) { struct sockaddr a; return sizeof(a.sa_len)==0; }"
    OTP_HOSTNAME_HAVE_SA_LEN)
if(NOT OTP_HOSTNAME_HAVE_SA_LEN)
    string(APPEND _hostname_config "#define NO_SA_LEN 1\n")
endif()
if(NOT OTP_HOSTNAME_HAVE_GETADDRINFO OR NOT OTP_HOSTNAME_HAVE_GETNAMEINFO)
    message(FATAL_ERROR "OTP's Linux native resolver requires getaddrinfo and getnameinfo")
endif()
cmake_pop_check_state()
file(CONFIGURE OUTPUT "${PROJECT_BINARY_DIR}/generated/otp_hostname_config.h"
    CONTENT "${_hostname_config}" @ONLY)
endif()

add_executable(otp_inet_gethost "${PROJECT_SOURCE_DIR}/erts/etc/common/inet_gethost.c")
target_compile_features(otp_inet_gethost PRIVATE c_std_11)
target_compile_definitions(otp_inet_gethost PRIVATE _GNU_SOURCE "$<$<CONFIG:Debug>:DEBUG>")
target_include_directories(otp_inet_gethost PRIVATE "${PROJECT_BINARY_DIR}/generated")
otp_application_version(erts _hostname_erts_version)
set(_hostname_directory "erts-${_hostname_erts_version}/bin")
set_target_properties(otp_inet_gethost PROPERTIES OUTPUT_NAME inet_gethost
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/${_hostname_directory}")
install(TARGETS otp_inet_gethost RUNTIME DESTINATION "${_hostname_directory}")
otp_register_native(otp_inet_gethost helper inet_gethost
    "${PROJECT_SOURCE_DIR}/erts/etc/common/inet_gethost.c"
    "${_hostname_directory}/inet_gethost${CMAKE_EXECUTABLE_SUFFIX}")
