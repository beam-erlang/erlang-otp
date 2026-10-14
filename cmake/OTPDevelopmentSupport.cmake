# SPDX-License-Identifier: Apache-2.0
# Upstream installs standalone support libraries and their development headers.
# These OTP-owned libraries are not linked into the product host or its NIFs.
if(WIN32)
    # The Unix internal support archives are not inputs to the Windows product.
    return()
endif()
set(_support_config "${PROJECT_BINARY_DIR}/generated/development-support")
set(_support_include "${PROJECT_SOURCE_DIR}/erts/include/internal")
set(_ethread_config "/* Generated for the retained standalone support libraries. */\n")
foreach(_size IN ITEMS VOID_P INT LONG LONG_LONG)
    if(_size STREQUAL VOID_P)
        set(_ethr_size PTR)
    else()
        set(_ethr_size "${_size}")
    endif()
    string(APPEND _ethread_config "#define ETHR_SIZEOF_${_ethr_size} ${SIZEOF_${_size}}\n")
endforeach()
check_type_size("__int128_t" SIZEOF___INT128_T)
if(NOT SIZEOF___INT128_T)
    set(SIZEOF___INT128_T 0)
endif()
string(APPEND _ethread_config "#define ETHR_SIZEOF___INT128_T ${SIZEOF___INT128_T}\n#define ETHR_SIZEOF___INT64 0\n#define ASSUMED_CACHE_LINE_SIZE 64\n#define ETHR_PTHREADS 1\n#define ETHR_HAVE_ETHREAD_DEFINES 1\n#define ETHR_HAVE_PTHREAD_H 1\n#define ETHR_HAVE_GCC___ATOMIC_BUILTINS 1\n#define ETHR_TRUST_GCC_ATOMIC_BUILTINS_MEMORY_BARRIERS 0\n")
set(CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
set(CMAKE_REQUIRED_LIBRARIES Threads::Threads)
foreach(_probe IN ITEMS "pthread_spin_lock|pthread.h|PTHREAD_SPIN_LOCK"
        "pthread_rwlockattr_setkind_np|pthread.h|PTHREAD_RWLOCKATTR_SETKIND_NP"
        "pthread_attr_setguardsize|pthread.h|PTHREAD_ATTR_SETGUARDSIZE"
        "sched_yield|sched.h|SCHED_YIELD")
    string(REPLACE "|" ";" _fields "${_probe}")
    list(GET _fields 0 _function)
    list(GET _fields 1 _header)
    list(GET _fields 2 _name)
    check_symbol_exists("${_function}" "${_header}" OTP_ETHR_${_name})
    if(OTP_ETHR_${_name})
        string(APPEND _ethread_config "#define ETHR_HAVE_${_name} 1\n")
    endif()
endforeach()
check_c_source_compiles("#include <pthread.h>\nint main(void) { return PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP; }" OTP_ETHR_WRITER)
check_c_source_compiles("#include <linux/futex.h>\n#include <sys/syscall.h>\nint main(void) { return SYS_futex + FUTEX_WAIT; }" OTP_ETHR_FUTEX)
check_c_source_compiles("#include <pthread.h>\n#include <time.h>\nint main(void) { pthread_condattr_t a; pthread_condattr_init(&a); return pthread_condattr_setclock(&a, CLOCK_MONOTONIC); }" OTP_ETHR_COND_CLOCK)
if(OTP_ETHR_WRITER)
    string(APPEND _ethread_config "#define ETHR_HAVE_PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP 1\n")
endif()
if(OTP_ETHR_FUTEX)
    string(APPEND _ethread_config "#define ETHR_HAVE_LINUX_FUTEX 1\n")
endif()
if(OTP_ETHR_COND_CLOCK)
    string(APPEND _ethread_config "#define ETHR_HAVE_PTHREAD_COND_TIMEDWAIT_MONOTONIC 1\n")
endif()
if(HAVE_CLOCK_GETTIME)
    string(APPEND _ethread_config "#define ETHR_HAVE_CLOCK_GETTIME_MONOTONIC 1\n#define ETHR_MONOTONIC_CLOCK_ID CLOCK_MONOTONIC\n")
endif()
string(APPEND _ethread_config "#define ETHR_HAVE_SCHED_H 1\n#define ETHR_SCHED_YIELD_RET_INT 1\n#define ETHR_HAVE_SYS_TIME_H 1\n")
set(_atomic_sizes 0)
foreach(_width IN ITEMS 4 8)
    math(EXPR _bits "${_width} * 8")
    check_c_source_compiles("#include <stdint.h>\nint main(void) { uint${_bits}_t n=0; __sync_add_and_fetch(&n,1); __atomic_add_fetch(&n,1,__ATOMIC_SEQ_CST); return n; }" OTP_ETHR_ATOMIC_${_width})
    if(OTP_ETHR_ATOMIC_${_width})
        math(EXPR _atomic_sizes "${_atomic_sizes} | ${_width}")
    endif()
endforeach()
foreach(_operation IN ITEMS __sync_add_and_fetch __sync_fetch_and_and __sync_fetch_and_or
        __sync_val_compare_and_swap __atomic_store_n __atomic_load_n __atomic_add_fetch
        __atomic_fetch_and __atomic_fetch_or __atomic_compare_exchange_n)
    string(APPEND _ethread_config "#define ETHR_HAVE_${_operation} ${_atomic_sizes}\n")
endforeach()
string(APPEND _ethread_config "#define ETHR_HAVE___sync_synchronize ~0\n")
set(CMAKE_REQUIRED_FLAGS "-fPIC")
check_c_source_compiles([=[
int main(void) {
    char changed;
    long next[2] = {0}, previous[2] = {0}, storage[2] = {0}, *p = storage;
    __asm__ __volatile__(
#if __SIZEOF_POINTER__ == 4
        "lock; cmpxchg8b %0; "
#else
        "lock; cmpxchg16b %0; "
#endif
        "setz %3"
        : "=m"(*p), "=d"(previous[1]), "=a"(previous[0]), "=q"(changed)
        : "m"(*p), "1"(previous[1]), "2"(previous[0]), "c"(next[1]), "b"(next[0])
        : "cc", "memory");
    return 0;
}
]=] OTP_ETHR_DW_CMPXCHG_ASM)
if(OTP_ETHR_DW_CMPXCHG_ASM)
    string(APPEND _ethread_config "#define ETHR_GCC_HAVE_DW_CMPXCHG_ASM_SUPPORT 1\n")
endif()
foreach(_instruction IN ITEMS "DMB|dmb sy" "DMB_LD|dmb ld" "DMB_ST|dmb st" "ISB_SY|isb sy")
    string(REPLACE "|" ";" _parts "${_instruction}")
    list(GET _parts 0 _name)
    list(GET _parts 1 _asm)
    check_c_source_compiles("int main(void) { __asm__ __volatile__(\"${_asm}\" ::: \"memory\"); return 0; }"
        OTP_ETHR_ARM_${_name})
    if(OTP_ETHR_ARM_${_name})
        set(_value 1)
    else()
        set(_value 0)
    endif()
    string(APPEND _ethread_config "#define ETHR_HAVE_GCC_ASM_ARM_${_name}_INSTRUCTION ${_value}\n")
endforeach()
unset(CMAKE_REQUIRED_FLAGS)
unset(CMAKE_REQUIRED_DEFINITIONS)
unset(CMAKE_REQUIRED_LIBRARIES)
# Generate the retained public template, keeping implementation-only probes in
# compiler definitions rather than leaking them into the installed header.
file(READ "${_support_include}/ethread_header_config.h.in" _ethread_template)
string(REGEX MATCHALL "#define [^\n]+" _ethread_defines "${_ethread_config}")
foreach(_define IN LISTS _ethread_defines)
    string(REGEX REPLACE "^#define ([A-Za-z0-9_]+).*" "\\1" _name "${_define}")
    string(REPLACE "#undef ${_name}\n" "${_define}\n" _ethread_template "${_ethread_template}")
endforeach()
string(REGEX REPLACE "#undef ([A-Za-z0-9_]+)" "/* #undef \\1 */" _ethread_template "${_ethread_template}")
file(CONFIGURE OUTPUT "${_support_config}/ethread_header_config.h"
    CONTENT "/* Generated from the retained ethread_header_config.h.in template. */\n${_ethread_template}" @ONLY)
foreach(_variant IN ITEMS erts_internal erts_internal_r)
    add_library(otp_${_variant} STATIC
        "${PROJECT_SOURCE_DIR}/erts/lib_src/common/erl_printf.c"
        "${PROJECT_SOURCE_DIR}/erts/lib_src/common/erl_printf_format.c"
        "${PROJECT_SOURCE_DIR}/erts/lib_src/common/erl_misc_utils.c")
    set_target_properties(otp_${_variant} PROPERTIES OUTPUT_NAME "${_variant}" POSITION_INDEPENDENT_CODE ON)
endforeach()
add_library(otp_ethread STATIC
    erts/lib_src/common/ethr_aux.c erts/lib_src/common/ethr_atomics.c
    erts/lib_src/common/ethr_mutex.c erts/lib_src/common/ethr_cbf.c
    erts/lib_src/pthread/ethread.c erts/lib_src/pthread/ethr_event.c)
set_target_properties(otp_ethread PROPERTIES OUTPUT_NAME ethread POSITION_INDEPENDENT_CODE ON)
target_compile_definitions(otp_ethread PRIVATE ETHR_HAVE_ETHREAD_DEFINES ETHR_HAVE_SYS_TIME_H)
target_compile_options(otp_ethread PRIVATE -include "${_support_config}/ethread_header_config.h")
if(OTP_ETHR_PTHREAD_ATTR_SETGUARDSIZE)
    target_compile_definitions(otp_ethread PRIVATE ETHR_HAVE_PTHREAD_ATTR_SETGUARDSIZE)
endif()
foreach(_target IN ITEMS otp_erts_internal otp_erts_internal_r otp_ethread)
    target_include_directories(${_target} PRIVATE "${_support_config}" "${_native_config_dir}"
        "${PROJECT_SOURCE_DIR}/erts/include" "${_support_include}")
    target_compile_definitions(${_target} PRIVATE HAVE_CONFIG_H _GNU_SOURCE)
    if(NOT _target STREQUAL otp_erts_internal)
        target_compile_definitions(${_target} PRIVATE USE_THREADS _REENTRANT _THREAD_SAFE POSIX_THREADS _POSIX_THREAD_SAFE_FUNCTIONS)
    endif()
    install(TARGETS ${_target} ARCHIVE DESTINATION "erts-${_erts_version}/lib/internal")
endforeach()
install(DIRECTORY "${_support_include}/" DESTINATION "erts-${_erts_version}/include/internal"
    PATTERN ethread_header_config.h EXCLUDE PATTERN ethr_internal.h EXCLUDE PATTERN "*.in" EXCLUDE)
install(FILES "${_support_config}/ethread_header_config.h"
    "${PROJECT_SOURCE_DIR}/erts/emulator/beam/erl_internal_test.h"
    DESTINATION "erts-${_erts_version}/include/internal")
set(ETHR_LIB_NAME ethread)
set(ETHR_DEFS "-DUSE_THREADS  -D_THREAD_SAFE -D_REENTRANT -DPOSIX_THREADS -D_POSIX_THREAD_SAFE_FUNCTIONS -D_GNU_SOURCE")
set(ETHR_LIBS "-lethread -lerts_internal_r -lpthread  -lrt")
set(ETHR_X_LIBS "-lpthread  -lrt")
set(ETHR_THR_LIB_BASE pthread)
set(ERTS_INTERNAL_X_LIBS "")
foreach(_template IN ITEMS ethread.mk erts_internal.mk)
    configure_file("${_support_include}/${_template}.in" "${_support_config}/${_template}" @ONLY)
endforeach()
install(FILES "${_support_config}/ethread.mk" "${_support_config}/erts_internal.mk"
    DESTINATION "erts-${_erts_version}/include/internal")
install(FILES "${PROJECT_SOURCE_DIR}/erts/lib/internal/README" DESTINATION "erts-${_erts_version}/lib/internal")
