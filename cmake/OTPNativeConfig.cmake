# Platform configuration for OTP-owned commands and native extensions.

include_guard(GLOBAL)

include(CheckIncludeFile)
include(CheckSymbolExists)
include(CheckTypeSize)
include(CheckCSourceCompiles)
include(CMakePushCheckState)
find_package(Threads REQUIRED)

set(OTP_NATIVE_CONFIG_DIR "${OTP_INTERNAL_ROOT}/native")
file(MAKE_DIRECTORY "${OTP_NATIVE_CONFIG_DIR}")
cmake_push_check_state(RESET)
set(CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)

foreach(_type IN ITEMS char short int long "long long" "void *")
    string(TOUPPER "${_type}" _name)
    string(REPLACE " " "_" _name "${_name}")
    string(REPLACE "*" "P" _name "${_name}")
    check_type_size("${_type}" SIZEOF_${_name})
endforeach()

function(otp_linux_native_flags target)
    cmake_parse_arguments(N "DED;HIDDEN;NO_LINK_HARDENING" "" "" ${ARGN})
    if(N_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unknown Linux native recipe options: ${N_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT DEFINED OTP_LINUX_NATIVE_CFLAGS)
        return()
    endif()
    # CMake's Release default defines NDEBUG; the original recipes do not.
    target_compile_options(${target} PRIVATE ${OTP_LINUX_NATIVE_CFLAGS} -fno-common -UNDEBUG)
    if(N_HIDDEN)
        target_compile_options(${target} PRIVATE -fvisibility=hidden)
    endif()
    if(NOT N_NO_LINK_HARDENING)
        target_link_options(${target} PRIVATE ${OTP_LINUX_NATIVE_LDFLAGS})
    endif()
    if(N_DED)
        target_link_options(${target} PRIVATE -Wl,-Bsymbolic)
    endif()
endfunction()

if(WIN32)
    include("${CMAKE_CURRENT_LIST_DIR}/WindowsNativeConfig.cmake")
    return()
endif()

foreach(_header IN ITEMS
    sys/time.h
    sys/select.h
    sys/uio.h
    pthread.h
    syslog.h
    unistd.h
    stdlib.h
    sys/ioctl.h
    pty.h
    utmp.h
    util.h
)
    string(TOUPPER "${_header}" _name)
    string(REGEX REPLACE "[/\\.]" "_" _name "${_name}")
    check_include_file("${_header}" HAVE_${_name})
endforeach()

foreach(_probe IN ITEMS
    "setsid|unistd.h"
    "inet_pton|arpa/inet.h"
    "in6addr_any|netinet/in.h"
    "in6addr_loopback|netinet/in.h"
    "writev|sys/uio.h"
    "sysconf|unistd.h"
    "strerror|string.h"
    "flockfile|stdio.h"
    "putc_unlocked|stdio.h"
    "fwrite_unlocked|stdio.h"
    "isfinite|math.h"
    "posix_openpt|stdlib.h;fcntl.h"
    "grantpt|stdlib.h"
    "unlockpt|stdlib.h"
    "ptsname|stdlib.h"
    "clock_gettime|time.h"
    "vsyslog|syslog.h"
    "getaddrinfo|sys/types.h;sys/socket.h;netdb.h"
    "getnameinfo|sys/types.h;sys/socket.h;netdb.h"
    "gethostbyname2|sys/types.h;sys/socket.h;netdb.h"
)
    string(REPLACE "|" ";" _fields "${_probe}")
    list(POP_FRONT _fields _symbol)
    string(TOUPPER "${_symbol}" _name)
    check_symbol_exists("${_symbol}" "${_fields}" HAVE_${_name})
endforeach()

check_symbol_exists(IPV6_V6ONLY "netinet/in.h" HAVE_DECL_IPV6_V6ONLY)
check_c_source_compiles(
    "#include <netinet/in.h>\nint main(void) { struct sockaddr_in6 s; return sizeof(s) == 0; }"
    HAVE_IN6
)
check_c_source_compiles(
    "#include <sys/socket.h>\nint main(void) { socklen_t n = 0; return (int)n; }"
    HAVE_SOCKLEN_T
)
check_c_source_compiles(
    "#include <sys/socket.h>\nint main(void) { struct sockaddr a; return sizeof(a.sa_len) == 0; }"
    HAVE_SA_LEN
)
check_c_source_compiles(
    "#include <netdb.h>\nint main(void) { struct hostent h, *p; char b[1024]; int e; int r = gethostbyname_r(\"localhost\", &h, b, sizeof(b), &p, &e); return r + gethostbyaddr_r(b, 4, AF_INET, &h, b, sizeof(b), &p, &e); }"
    HAVE_GETHOSTBYNAME_R
)

if(NOT HAVE_SA_LEN)
    set(NO_SA_LEN 1)
endif()

if(HAVE_POSIX_OPENPT AND HAVE_GRANTPT AND HAVE_UNLOCKPT AND HAVE_PTSNAME)
    set(HAVE_WORKING_POSIX_OPENPT 1)
endif()

# Preserve run_erl's upstream openpty fallback if POSIX PTY allocation fails.
set(OTP_OPENPTY_LIBRARIES "")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND HAVE_PTY_H)
    check_symbol_exists(openpty "pty.h" HAVE_OPENPTY)
    if(NOT HAVE_OPENPTY)
        find_library(OTP_OPENPTY_LIBRARY NAMES util)
        if(OTP_OPENPTY_LIBRARY)
            cmake_push_check_state()
            set(CMAKE_REQUIRED_LIBRARIES "${OTP_OPENPTY_LIBRARY}")
            check_symbol_exists(openpty "pty.h" OTP_OPENPTY_WITH_UTIL)
            cmake_pop_check_state()
            if(OTP_OPENPTY_WITH_UTIL)
                set(HAVE_OPENPTY 1)
                set(OTP_OPENPTY_LIBRARIES "${OTP_OPENPTY_LIBRARY}")
            endif()
        endif()
    endif()
endif()

if(HAVE_CLOCK_GETTIME)
    set(OS_MONOTONIC_TIME_USING_CLOCK_GETTIME 1)
endif()

if(NOT HAVE_GETADDRINFO OR NOT HAVE_GETNAMEINFO)
    message(FATAL_ERROR "OTP's native hostname helper requires getaddrinfo and getnameinfo")
endif()

set(OTP_EI_ATOMIC_SIZES 0)

foreach(_width IN ITEMS 4 8)
    math(EXPR _bits "${_width} * 8")
    check_c_source_compiles(
        "#include <stdint.h>\nint main(void) { uint${_bits}_t value=0, expected=0; __atomic_store_n(&value, 1, __ATOMIC_RELEASE); expected=__atomic_load_n(&value, __ATOMIC_ACQUIRE); return !__atomic_compare_exchange_n(&value, &expected, 2, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE); }"
        OTP_EI_ATOMIC_${_width}
    )

    if(OTP_EI_ATOMIC_${_width})
        math(EXPR OTP_EI_ATOMIC_SIZES "${OTP_EI_ATOMIC_SIZES} | ${_width}")
    endif()
endforeach()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64|i[3-6]86|x86)$")
    set(HAVE_UNALIGNED_WORD_ACCESS 1)
endif()

cmake_pop_check_state()
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/templates/native_config.h.in"
    "${OTP_NATIVE_CONFIG_DIR}/config.h"
)
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/templates/native_int_sizes.h.in"
    "${OTP_NATIVE_CONFIG_DIR}/erl_int_sizes_config.h"
)

add_library(otp_native_config INTERFACE)
target_compile_features(otp_native_config INTERFACE c_std_11)
target_compile_definitions(otp_native_config INTERFACE HAVE_CONFIG_H _GNU_SOURCE)
target_include_directories(otp_native_config INTERFACE "${OTP_NATIVE_CONFIG_DIR}")

# The supported Linux amd64 GCC recipe follows ERL_OSSF_CFLAGS/LDFLAGS in
# make/autoconf/otp.m4. Keep optimization, warnings, thread definitions and
# Debug behavior in each owning recipe: upstream does not share those policies.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND
        CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)$" AND
        CMAKE_C_COMPILER_ID STREQUAL "GNU")
    include(CheckCCompilerFlag)
    include(CheckLinkerFlag)
    cmake_push_check_state(RESET)
    set(CMAKE_REQUIRED_FLAGS "-O2")
    check_c_compiler_flag("-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3" OTP_LINUX_FORTIFY_3)
    if(OTP_LINUX_FORTIFY_3)
        set(OTP_LINUX_NATIVE_CFLAGS -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3)
    else()
        check_c_compiler_flag("-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2" OTP_LINUX_FORTIFY_2)
        if(OTP_LINUX_FORTIFY_2)
            set(OTP_LINUX_NATIVE_CFLAGS -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2)
        endif()
    endif()
    foreach(_flag IN ITEMS -fstack-clash-protection -fstack-protector-strong
            -fcf-protection=full -fexceptions -fno-strict-overflow
            -fno-delete-null-pointer-checks -fno-strict-aliasing -fstrict-flex-arrays=3)
        string(MAKE_C_IDENTIFIER "${_flag}" _key)
        check_c_compiler_flag("${_flag}" OTP_LINUX_ACCEPTS_${_key})
        if(OTP_LINUX_ACCEPTS_${_key})
            list(APPEND OTP_LINUX_NATIVE_CFLAGS "${_flag}")
        elseif(_flag STREQUAL "-fstack-protector-strong")
            check_c_compiler_flag(-fstack-protector OTP_LINUX_STACK_PROTECTOR)
            if(OTP_LINUX_STACK_PROTECTOR)
                list(APPEND OTP_LINUX_NATIVE_CFLAGS -fstack-protector)
            endif()
        elseif(_flag STREQUAL "-fstrict-flex-arrays=3")
            check_c_compiler_flag(-fstrict-flex-arrays=2 OTP_LINUX_FLEX_ARRAYS_2)
            if(OTP_LINUX_FLEX_ARRAYS_2)
                list(APPEND OTP_LINUX_NATIVE_CFLAGS -fstrict-flex-arrays=2)
            endif()
        endif()
    endforeach()
    foreach(_flag IN ITEMS -fstack-protector-strong -Wl,-z,noexecstack
            -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -Wl,--no-copy-dt-needed-entries)
        string(MAKE_C_IDENTIFIER "${_flag}" _key)
        check_linker_flag(C "${_flag}" OTP_LINUX_LINKS_${_key})
        if(OTP_LINUX_LINKS_${_key})
            list(APPEND OTP_LINUX_NATIVE_LDFLAGS "${_flag}")
        endif()
    endforeach()
    cmake_pop_check_state()
endif()
