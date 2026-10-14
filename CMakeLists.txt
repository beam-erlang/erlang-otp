cmake_minimum_required(VERSION 3.25)
cmake_policy(SET CMP0141 NEW)
if(NOT DEFINED CMAKE_MSVC_DEBUG_INFORMATION_FORMAT)
    set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded)
endif()
if(POLICY CMP0177)
    cmake_policy(SET CMP0177 NEW)
endif()

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/OTP_VERSION" OTP_VERSION LIMIT_COUNT 1)
project(ErlangOTP VERSION "${OTP_VERSION}" LANGUAGES C)

if(NOT CMAKE_SYSTEM_NAME MATCHES "^(Linux|Darwin|Windows)$")
    message(FATAL_ERROR "The independent OTP build requires Linux, Darwin or Windows")
endif()
if(WIN32)
    include(cmake/OTPWindows.cmake)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
# Upstream's installed subdirectories use install -d (0755); release assembly
# parents made by mkdir are declared separately in OTPReleaseLayout.cmake.
set(CMAKE_INSTALL_DEFAULT_DIRECTORY_PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
include(cmake/SDKDependency.cmake)
include(cmake/OTPTracingCapabilities.cmake)
include(cmake/OTPNativeFlags.cmake)

configure_file(cmake/sdk_selection.h.in generated/sdk_selection.h @ONLY)
add_executable(otp_sdk_probe tools/sdk_probe.c)
target_compile_features(otp_sdk_probe PRIVATE c_std_11)
target_include_directories(otp_sdk_probe PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/generated")
target_link_libraries(otp_sdk_probe PRIVATE BEAM::RuntimeStatic)
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(otp_sdk_probe PRIVATE -Wall -Wextra -Werror)
endif()

include(CTest)
if(BUILD_TESTING)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    add_test(NAME installed-sdk-smoke
        COMMAND otp_sdk_probe "$<TARGET_FILE:otp_sdk_probe>")
    add_test(NAME installed-sdk-boundary
        COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/tools/check_sdk_boundary.py"
            --executable "$<TARGET_FILE:otp_sdk_probe>"
            --source "${CMAKE_CURRENT_SOURCE_DIR}/tools/sdk_probe.c"
            --compile-commands "${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json"
            --sdk "${BEAM_SDK_ROOT}"
            --nm "${CMAKE_NM}"
            --selection-source "${CMAKE_CURRENT_SOURCE_DIR}"
            --expected-version "${OTP_BEAM_SDK_VERSION}"
            --expected-build-id "${OTP_BEAM_SDK_BUILD_ID}"
            --expected-flavor "${OTP_BEAM_FLAVOR}"
            --cmake "${CMAKE_COMMAND}")
endif()

include(cmake/OTPVersions.cmake)
include(cmake/OTPNativeComponents.cmake)
include(cmake/OTPPrimitives.cmake)
include(cmake/OTPStaticPrimitives.cmake)
include(cmake/OTPInetDrivers.cmake)
include(cmake/OTPSockets.cmake)
include(cmake/OTPHostname.cmake)
include(cmake/OTPHost.cmake)
include(cmake/OTPBootstrap.cmake)
include(cmake/OTPApplications.cmake)
otp_finalize_bootstrap()
include(cmake/OTPInstallation.cmake)
include(cmake/OTPCommands.cmake)
include(cmake/OTPDevelopmentSupport.cmake)
include(cmake/OTPCrypto.cmake)
include(cmake/OTPRuntimeTools.cmake)
otp_write_native_inventory()
include(cmake/OTPTesting.cmake)
include(cmake/OTPInstalledExamples.cmake)
include(cmake/OTPReleaseLayout.cmake)
if(WIN32)
    otp_finalize_windows_targets()
endif()
message(STATUS "Initial OTP source assembly enabled; full product compatibility remains in progress")
