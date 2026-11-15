# Configuration for OTP-owned Windows commands and ordinary native extensions.
# This contains no VM implementation or producer build-tree dependencies.
set(CMAKE_REQUIRED_DEFINITIONS -D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00)
set(CMAKE_REQUIRED_LIBRARIES ws2_32)
foreach(_probe IN ITEMS
        "getaddrinfo|winsock2.h;ws2tcpip.h"
        "getnameinfo|winsock2.h;ws2tcpip.h"
        "inet_pton|winsock2.h;ws2tcpip.h"
        "in6addr_any|winsock2.h;ws2tcpip.h"
        "in6addr_loopback|winsock2.h;ws2tcpip.h")
    string(FIND "${_probe}" "|" _separator)
    string(SUBSTRING "${_probe}" 0 ${_separator} _symbol)
    math(EXPR _separator "${_separator} + 1")
    string(SUBSTRING "${_probe}" ${_separator} -1 _headers)
    string(TOUPPER "${_symbol}" _name)
    check_symbol_exists("${_symbol}" "${_headers}" HAVE_${_name})
endforeach()
if(NOT HAVE_GETADDRINFO OR NOT HAVE_GETNAMEINFO)
    message(FATAL_ERROR "Selected Windows SDK lacks native hostname interfaces")
endif()
check_c_source_compiles("#include <winsock2.h>\n#include <ws2tcpip.h>\nint main(void) { struct sockaddr_in6 s; return sizeof(s) == 0; }" HAVE_IN6)
# Match EI's winsock2 visibility; ws2tcpip.h separately typedefs socklen_t.
check_c_source_compiles("#include <winsock2.h>\nint main(void) { socklen_t n=0; return n; }" HAVE_SOCKLEN_T)
set(HAVE_STDLIB_H 1)
set(HAVE_STRERROR 1)
set(HAVE_ISFINITE 1)
set(HAVE_COPYING_PUTENV 1)
set(NO_SA_LEN 1)
set(OTP_EI_ATOMIC_SIZES 0)
cmake_pop_check_state()
configure_file("${CMAKE_CURRENT_LIST_DIR}/templates/native_config.h.in" "${OTP_NATIVE_CONFIG_DIR}/config.h")
configure_file("${CMAKE_CURRENT_LIST_DIR}/templates/native_int_sizes.h.in" "${OTP_NATIVE_CONFIG_DIR}/erl_int_sizes_config.h")
add_library(otp_native_config INTERFACE)
target_compile_features(otp_native_config INTERFACE c_std_11)
target_compile_definitions(otp_native_config INTERFACE
    HAVE_CONFIG_H __WIN32__ WIN32 WINDOWS NT _WIN32_WINNT=0x0A00 WINVER=0x0A00
    ERTS_MIXED_VC USE_THREADS WIN32_THREADS _THREAD_SAFE _REENTRANT
    _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_WARNINGS FD_SETSIZE=1024)
target_compile_options(otp_native_config INTERFACE "$<$<COMPILE_LANGUAGE:C,CXX>:/utf-8>")
target_include_directories(otp_native_config INTERFACE "${OTP_NATIVE_CONFIG_DIR}")
target_link_libraries(otp_native_config INTERFACE ws2_32 mswsock advapi32 user32)
