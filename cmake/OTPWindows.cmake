# SPDX-License-Identifier: Apache-2.0
# Product-owned Windows configuration, independent of the VM's private headers.
if(NOT (MSVC OR (MINGW AND CMAKE_C_COMPILER_ID STREQUAL "GNU")))
    message(FATAL_ERROR "Select native MSVC or UCRT64 GCC for Windows OTP")
endif()
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8 OR NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^(AMD64|amd64|x86_64)$")
    message(FATAL_ERROR "The native Windows OTP configuration currently requires AMD64")
endif()
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
add_compile_definitions(__WIN32__ WIN32 WIN32_LEAN_AND_MEAN NOMINMAX
    _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_WARNINGS _WINSOCK_DEPRECATED_NO_WARNINGS
    _WIN32_WINNT=0x0A00 WINVER=0x0A00)
if(MSVC)
    add_compile_definitions(ERTS_MIXED_VC)
    add_compile_options("$<$<COMPILE_LANGUAGE:C>:/experimental:c11atomics>")
else()
    include(CheckCSourceCompiles)
    check_c_source_compiles("#include <_mingw.h>\n#ifndef _UCRT\n#error UCRT64 required\n#endif\nint main(void) { return 0; }" OTP_HAVE_MINGW_UCRT)
    if(NOT OTP_HAVE_MINGW_UCRT)
        message(FATAL_ERROR "Select a native UCRT64 GCC compiler, outside MSYS /usr")
    endif()
endif()
include_directories("${PROJECT_BINARY_DIR}/generated")

# The retained zlib is an ordinary third-party dependency, not a VM input.
set(_zlib "${PROJECT_SOURCE_DIR}/erts/emulator/zlib")
set(_zlib_sources)
foreach(_source adler32 compress crc32 deflate inffast inflate inftrees trees uncompr zutil)
    list(APPEND _zlib_sources "${_zlib}/${_source}.c")
endforeach()
add_library(otp_zlib STATIC ${_zlib_sources})
target_include_directories(otp_zlib PUBLIC "${_zlib}")
add_library(ZLIB::ZLIB ALIAS otp_zlib)

file(CONFIGURE OUTPUT "${PROJECT_BINARY_DIR}/generated/config.h" CONTENT
    "/* OTP-owned Windows command capabilities. */\n#define SIZEOF_VOID_P 8\n#define SIZEOF_LONG 4\n#define SIZEOF_LONG_LONG 8\n#define SIZEOF_INT 4\n#define SIZEOF_SHORT 2\n#define SIZEOF_CHAR 1\n#define HAVE_STDLIB_H 1\n#define HAVE_STRERROR 1\n#define HAVE_IN6 1\n#define HAVE_IN6ADDR_ANY 1\n#define HAVE_IN6ADDR_LOOPBACK 1\n#define HAVE_DECL_IPV6_V6ONLY 1\n#define HAVE_SDKDDKVER_H 1\n#define NO_SA_LEN 1\n" @ONLY)

function(otp_finalize_windows_targets)
    get_property(_targets DIRECTORY PROPERTY BUILDSYSTEM_TARGETS)
    foreach(_target IN LISTS _targets)
        get_target_property(_type "${_target}" TYPE)
        get_target_property(_links "${_target}" LINK_LIBRARIES)
        if(_type MATCHES "^(EXECUTABLE|MODULE_LIBRARY|SHARED_LIBRARY)$" AND
                NOT "BEAM::RuntimeStatic" IN_LIST _links)
            # SDK hosts inherit their system libraries after the VM archive.
            # Directory-wide link entries put Winsock ahead of that archive,
            # which loses its imports with the GNU linker.
            target_link_libraries("${_target}" PRIVATE ws2_32 advapi32 iphlpapi)
        endif()
        if(_type MATCHES "^(MODULE_LIBRARY|SHARED_LIBRARY)$")
            get_target_property(_directory "${_target}" LIBRARY_OUTPUT_DIRECTORY)
            if(_directory)
                set_target_properties("${_target}" PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_directory}")
            endif()
        endif()
    endforeach()
    file(GLOB _openssl_dlls "${OPENSSL_ROOT_DIR}/bin/libcrypto*.dll" "${OPENSSL_ROOT_DIR}/bin/libssl*.dll")
    if(NOT _openssl_dlls)
        message(FATAL_ERROR "Select an installed shared Windows OpenSSL prefix with OPENSSL_ROOT_DIR")
    endif()
    if(MSVC)
        file(REAL_PATH "${wxWidgets_DIR}/../../.." _wx_root)
        file(GLOB _wx_dlls "${_wx_root}/lib/vc_x64_dll/*.dll")
        if(NOT _wx_dlls)
            message(FATAL_ERROR "Selected shared wxMSW installation has no runtime DLLs")
        endif()
        install(FILES ${_openssl_dlls} ${_wx_dlls} DESTINATION "erts-${_erts_version}/bin")
    else()
        get_filename_component(OTP_WINDOWS_RUNTIME_DIRECTORY "${CMAKE_C_COMPILER}" DIRECTORY)
        # Third-party DLLs in System32 must not override the selected OpenSSL.
        # Seed both executable directories before resolving the remaining PE closure.
        install(FILES ${_openssl_dlls} DESTINATION bin)
        install(FILES ${_openssl_dlls} DESTINATION "erts-${_erts_version}/bin")
        configure_file("${PROJECT_SOURCE_DIR}/cmake/OTPInstallWindowsRuntime.cmake.in"
            "${PROJECT_BINARY_DIR}/OTPInstallWindowsRuntime.cmake" @ONLY)
        install(SCRIPT "${PROJECT_BINARY_DIR}/OTPInstallWindowsRuntime.cmake")
        # The packaged wx/OpenSSL dependency stack uses these native libraries.
        foreach(_package IN ITEMS gcc-libs libwinpthread winpthreads openssl wxWidgets3.2
                expat pcre2 libpng libjpeg-turbo libtiff libwebp jbigkit lerc xz zstd zlib libdeflate)
            set(_notices "${OTP_WINDOWS_RUNTIME_DIRECTORY}/../share/licenses/${_package}")
            if(IS_DIRECTORY "${_notices}")
                install(DIRECTORY "${_notices}/" DESTINATION "COPYRIGHTS/${_package}")
            endif()
        endforeach()
    endif()
endfunction()
