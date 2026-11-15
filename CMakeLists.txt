cmake_minimum_required(VERSION 3.25)

# Match the SDK's independent MSVC object compilation. Embedded debug records
# avoid a shared compiler PDB server across parallel native configurations.
if(NOT DEFINED CMAKE_MSVC_DEBUG_INFORMATION_FORMAT)
    set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<$<CONFIG:Debug>:Embedded>")
endif()

# Set Apple platform defaults before compiler identification and feature probes.
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    if(NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "26.0" CACHE STRING "Minimum macOS version")
    endif()
    if(NOT DEFINED CMAKE_OSX_SYSROOT)
        set(CMAKE_OSX_SYSROOT "macosx" CACHE STRING "macOS SDK")
    endif()
endif()

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/OTP_VERSION" OTP_VERSION LIMIT_COUNT 1)

project(
    erlang-otp
    VERSION "${OTP_VERSION}"
    DESCRIPTION "Erlangsters Erlang/OTP"
    HOMEPAGE_URL "https://beam.erlangsters.org"
    LANGUAGES C CXX
)

# Reconfigure when any version or upstream pin changes.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/OTP_VERSION"
    "${CMAKE_CURRENT_SOURCE_DIR}/otp_versions.table"
    "${CMAKE_CURRENT_SOURCE_DIR}/UPSTREAM_COMMIT"
)

if(NOT CMAKE_SYSTEM_NAME MATCHES "^(Linux|Darwin|Windows)$" OR CMAKE_CROSSCOMPILING)
    message(FATAL_ERROR "The OTP build supports native Linux, macOS and Windows only")
endif()
if(WIN32 AND (NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8))
    message(FATAL_ERROR "Windows OTP requires a native x64 MSVC toolchain")
endif()

# The original Linux GCC recipes use compiler-default dialects. Public SDK
# and native targets still declare their minimum language features.
if(NOT (CMAKE_SYSTEM_NAME STREQUAL "Linux" AND
        CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)$" AND
        CMAKE_C_COMPILER_ID STREQUAL "GNU"))
    set(CMAKE_C_STANDARD 11)
    set(CMAKE_CXX_STANDARD 17)
endif()
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE
)

find_package(Perl REQUIRED)
include(CTest)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/OTPVersions.cmake)
otp_application_version(erts OTP_ERTS_VERSION)

# Applications included in the core distribution.
set(OTP_APPLICATIONS
    kernel
    stdlib
    compiler
    parsetools
    sasl
    syntax_tools
    asn1
    crypto
    public_key
    tools
    runtime_tools
    xmerl
    eunit
    common_test
    erl_interface
    mnesia
    os_mon
    ssh
    snmp
    inets
    ssl
    wx
    et
    debugger
    observer
    ftp
    dialyzer
    diameter
    edoc
    eldap
    jinterface
    megaco
    odbc
    reltool
    tftp
)

set(OTP_BUILD_ROOT "${PROJECT_BINARY_DIR}")
set(OTP_INTERNAL_ROOT "${PROJECT_BINARY_DIR}/CMakeFiles/otp")
set(OTP_GENERATED_ROOT "${PROJECT_BINARY_DIR}/lib")

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/OTPAtomicInstall.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/SDKDependency.cmake)
set(OTP_COMMAND_BIN "${PROJECT_BINARY_DIR}/bin/${OTP_TARGET}")

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/OTPNativeConfig.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/OTPBootstrap.cmake)

add_subdirectory(erts)
add_subdirectory(lib)
otp_complete_distribution()
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/OTPInstallation.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/OTPPackaging.cmake)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

message(STATUS "Core OTP ${PROJECT_VERSION}: ${OTP_APPLICATIONS}")
message(STATUS
    "Selected BEAM SDK: ${BEAM_SDK_ROOT} (${BEAM_SDK_FLAVOR}/${BEAM_SDK_BUILD_TYPE}, ${BEAM_SDK_BUILD_ID})")
