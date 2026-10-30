# SPDX-License-Identifier: Apache-2.0
# OTP-owned primitives use the installed public SDK, with matching-build stamps
# for explicit host composition. No VM-private source or header is an input.
# Compression comes from the explicitly selected public SDK, not a second codec.
include(CheckCSourceCompiles)
set(CMAKE_REQUIRED_LIBRARIES BEAM::RuntimeStatic)
unset(OTP_HAS_PUBLIC_ZLIB CACHE)
check_c_source_compiles("#include <beam/zlib.h>
int main(void) {
    beam_zlib_stream stream = {0};
    unsigned length = 0;
    if (beam_zlib_inflate_init(&stream) != BEAM_ZLIB_OK) return 1;
    int result = beam_zlib_inflate_get_dictionary(&stream, 0, &length);
    return beam_zlib_inflate_end(&stream) != BEAM_ZLIB_OK || result != BEAM_ZLIB_OK;
}" OTP_HAS_PUBLIC_ZLIB)
unset(CMAKE_REQUIRED_LIBRARIES)
if(NOT OTP_HAS_PUBLIC_ZLIB)
    message(FATAL_ERROR "Selected BEAM SDK lacks the public in-memory zlib interface")
endif()
otp_application_version(erts _primitive_erts_version)
set(_primitive_directory "erts-${_primitive_erts_version}/lib")
foreach(_module IN ITEMS prim_buffer prim_file zlib erl_tracer)
    set(_target "otp_${_module}_nif")
    add_library("${_target}" OBJECT
        "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common/${_module}_nif.c")
    target_compile_features("${_target}" PRIVATE c_std_11)
    target_compile_definitions("${_target}" PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
    target_link_libraries("${_target}" PRIVATE BEAM::NIF)
    target_compile_definitions("${_target}" PRIVATE "STATIC_ERLANG_NIF_LIBNAME=otp_${_module}")
    set_target_properties("${_target}" PROPERTIES
        PREFIX "" OUTPUT_NAME "${_module}"
        C_VISIBILITY_PRESET hidden
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/${_primitive_directory}"
        OTP_INSTALL_PATH "${_primitive_directory}/${_module}${CMAKE_SHARED_MODULE_SUFFIX}")
    set(_extra_sources)
    if(_module STREQUAL prim_file)
        if(WIN32)
            set(_extra_sources "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/win32/win_prim_file.c")
        else()
            set(_extra_sources "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/unix/unix_prim_file.c")
        endif()
        target_sources("${_target}" PRIVATE ${_extra_sources})
    endif()
    otp_register_native("${_target}" builtin-nif "${_module}"
        "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common/${_module}_nif.c"
        "${_primitive_directory}/${_module}${CMAKE_SHARED_MODULE_SUFFIX}" ${_extra_sources})
endforeach()
include("${CMAKE_CURRENT_LIST_DIR}/OTPFileCapabilities.cmake")
target_compile_definitions(otp_prim_file_nif PRIVATE _GNU_SOURCE _FILE_OFFSET_BITS=64)
target_include_directories(otp_prim_file_nif PRIVATE
    "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common"
    "${PROJECT_BINARY_DIR}/generated")
target_link_libraries(otp_prim_file_nif PRIVATE BEAM::Driver)
function(otp_nif_relative_path output module)
    if(TARGET "otp_${module}_nif")
        get_target_property(_path "otp_${module}_nif" OTP_INSTALL_PATH)
    else()
        message(FATAL_ERROR "Missing OTP-owned native target for ${module}")
    endif()
    set("${output}" "${_path}" PARENT_SCOPE)
endfunction()
