# SPDX-License-Identifier: Apache-2.0
# Dependency discovery must never select a different installed runtime silently.
set(BEAM_SDK_ROOT "" CACHE PATH "Explicit installed BEAM SDK prefix")
set(OTP_BEAM_FLAVOR "" CACHE STRING "Required BEAM flavor: emu or jit")
set_property(CACHE OTP_BEAM_FLAVOR PROPERTY STRINGS emu jit)
if(NOT IS_ABSOLUTE "${BEAM_SDK_ROOT}" OR NOT IS_DIRECTORY "${BEAM_SDK_ROOT}")
    message(FATAL_ERROR "Set BEAM_SDK_ROOT to an absolute, existing installed BEAM SDK prefix")
endif()
if(NOT OTP_BEAM_FLAVOR MATCHES "^(emu|jit)$")
    message(FATAL_ERROR "Set OTP_BEAM_FLAVOR explicitly to emu or jit")
endif()
file(REAL_PATH "${BEAM_SDK_ROOT}" BEAM_SDK_ROOT)
set(BEAM_DIR "${BEAM_SDK_ROOT}/lib/cmake/BEAM" CACHE PATH "Selected installed BEAM package" FORCE)
find_package(BEAM CONFIG REQUIRED COMPONENTS RuntimeStatic NIF Driver PATHS "${BEAM_DIR}" NO_DEFAULT_PATH)
foreach(_target RuntimeStatic NIF Driver)
    if(NOT TARGET BEAM::${_target})
        message(FATAL_ERROR "Selected BEAM SDK does not export BEAM::${_target}")
    endif()
endforeach()
foreach(_command beam_check_runtime_sdk beam_get_runtime_artifact beam_install_runtime_artifacts beam_install_native_headers beam_install_core_modules beam_target_nif)
    if(NOT COMMAND "${_command}")
        message(FATAL_ERROR "Selected BEAM SDK lacks ${_command}; install a runtime with public artifact acquisition and deployment support")
    endif()
endforeach()
set(OTP_BEAM_SDK_VERSION "" CACHE STRING "Expected full BEAM distribution release")
set(OTP_BEAM_SDK_BUILD_ID "" CACHE STRING "Expected exact BEAM SDK build identity")
string(LENGTH "${OTP_BEAM_SDK_BUILD_ID}" _expected_id_length)
if(OTP_BEAM_SDK_VERSION STREQUAL "" OR NOT _expected_id_length EQUAL 64
        OR NOT OTP_BEAM_SDK_BUILD_ID MATCHES "^[0-9a-f]+$")
    message(FATAL_ERROR "Set OTP_BEAM_SDK_VERSION and OTP_BEAM_SDK_BUILD_ID from the verified SDK candidate record, independently of the selected prefix")
endif()
beam_check_runtime_sdk(VERSION "${OTP_BEAM_SDK_VERSION}"
    FLAVOR "${OTP_BEAM_FLAVOR}" BUILD_ID "${OTP_BEAM_SDK_BUILD_ID}")
if(WIN32)
    beam_get_runtime_artifact(_target_metadata NAME sdk.target KIND target-metadata)
    file(STRINGS "${_target_metadata}" _sdk_compiler REGEX "^compiler-environment = ")
    set(_compiler_environment "${CMAKE_C_COMPILER_ID}")
    if(CMAKE_C_SIMULATE_ID)
        string(APPEND _compiler_environment "-${CMAKE_C_SIMULATE_ID}")
    elseif(MINGW)
        string(APPEND _compiler_environment "-MinGW")
    endif()
    if(NOT _sdk_compiler STREQUAL "compiler-environment = \"${_compiler_environment}\"")
        message(FATAL_ERROR "OTP and its installed BEAM SDK must use the same native compiler environment")
    endif()
endif()

# These are declared SDK capabilities, not knowledge of private install paths.
set(_required_artifacts runtime.static api.beam api.runtime api.zlib)
if(NOT WIN32)
    list(APPEND _required_artifacts helper.child_setup)
endif()
set(_core_artifacts)
foreach(_artifact IN LISTS BEAM_RUNTIME_ARTIFACTS)
    if(_artifact MATCHES "^(core[.]|core-source[.]|link[.]static|header[.])")
        beam_get_runtime_artifact(_path NAME "${_artifact}")
        list(APPEND _core_artifacts "${_artifact}")
    endif()
endforeach()
set(_artifact_json "{}")
foreach(_artifact IN ITEMS ${_required_artifacts} ${_core_artifacts} header.beam_native header.erl_nif header.erl_driver)
    beam_get_runtime_artifact(_path NAME "${_artifact}")
    file(SHA256 "${_path}" _sha256)
    string(JSON _artifact_json SET "${_artifact_json}" "${_artifact}" "\"${_sha256}\"")
endforeach()

# Compile against the selected installed headers, before building any host.
include(CheckCSourceCompiles)
set(CMAKE_REQUIRED_LIBRARIES BEAM::RuntimeStatic)
unset(OTP_HAS_PUBLIC_PRELOAD_COMPOSITION CACHE)
check_c_source_compiles("#include <beam/beam.h>
int main(void) {
    beam_composition_options options = {0};
    options.builtin_nif_count = 0;
    options.builtin_driver_count = 0;
    options.preload_count = 0;
    options.preloads = (const beam_module_spec *)0;
    beam_embedded_dependency dependency = {sizeof(beam_embedded_dependency), \"probe\", BEAM_EMBEDDED_INCLUDED};
    options.embedded_dependency_count = 1;
    options.embedded_dependencies = &dependency;
    beam_vm_options vm = {0};
    vm.break_policy = BEAM_BREAK_DISABLED;
    return (int) options.preload_count;
}" OTP_HAS_PUBLIC_PRELOAD_COMPOSITION)
unset(CMAKE_REQUIRED_LIBRARIES)
if(NOT OTP_HAS_PUBLIC_PRELOAD_COMPOSITION)
    message(FATAL_ERROR "Selected BEAM SDK lacks public preload composition, embedded dependency reporting or process interrupt policy required for OTP compatibility")
endif()

function(_otp_json_string output value)
    string(REPLACE "\\" "\\\\" _value "${value}")
    string(REPLACE "\"" "\\\"" _value "${_value}")
    string(REPLACE "\n" "\\n" _value "${_value}")
    string(REPLACE "\r" "\\r" _value "${_value}")
    string(REPLACE "\t" "\\t" _value "${_value}")
    set("${output}" "\"${_value}\"" PARENT_SCOPE)
endfunction()
set(_selection "{}")
foreach(_field VERSION FLAVOR BUILD_ID ARCHITECTURE TRIPLE)
    _otp_json_string(_value "${BEAM_SDK_${_field}}")
    string(TOLOWER "${_field}" _key)
    string(JSON _selection SET "${_selection}" "${_key}" "${_value}")
endforeach()
_otp_json_string(_value "${BEAM_SDK_ROOT}")
string(JSON _selection SET "${_selection}" prefix "${_value}")
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/UPSTREAM_COMMIT" _upstream LIMIT_COUNT 1)
_otp_json_string(_value "${_upstream}")
string(JSON _selection SET "${_selection}" upstream_commit "${_value}")
string(JSON _selection SET "${_selection}" artifacts "${_artifact_json}")
file(CONFIGURE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/sdk-selection.json"
    CONTENT "${_selection}\n" @ONLY)
message(STATUS "BEAM SDK: ${BEAM_SDK_VERSION}, ${BEAM_SDK_FLAVOR}, ${BEAM_SDK_BUILD_ID}")
