# SPDX-License-Identifier: Apache-2.0
# STDLIB owns regex; only public installed SDK interfaces reach the VM.
set(_otp_re_root "${PROJECT_SOURCE_DIR}/lib/stdlib/c_src/re")
set(_otp_re_generated "${PROJECT_BINARY_DIR}/generated/otp-re")
find_package(Python3 3.9 REQUIRED COMPONENTS Interpreter)
file(MAKE_DIRECTORY "${_otp_re_generated}")
execute_process(COMMAND "${Python3_EXECUTABLE}" "${_otp_re_root}/generate_backend.py"
    --source "${_otp_re_root}/pcre2" --output "${_otp_re_generated}"
    COMMAND_ERROR_IS_FATAL ANY)
file(GLOB _otp_re_inputs CONFIGURE_DEPENDS "${_otp_re_root}/pcre2/*.h" "${_otp_re_root}/pcre2/*.c")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${_otp_re_inputs} "${_otp_re_root}/generate_backend.py")
set(_otp_re_sources
    pcre2_auto_possess.c pcre2_chartables.c pcre2_chkdint.c pcre2_compile.c
    pcre2_compile_cgroup.c pcre2_compile_class.c pcre2_config.c pcre2_context.c
    pcre2_error.c pcre2_extuni.c pcre2_find_bracket.c pcre2_match.c
    pcre2_match_data.c pcre2_newline.c pcre2_ord2utf.c pcre2_pattern_info.c
    pcre2_script_run.c pcre2_serialize.c pcre2_string_utils.c pcre2_study.c
    pcre2_substring.c pcre2_tables.c pcre2_ucd.c pcre2_valid_utf.c pcre2_xclass.c)
list(TRANSFORM _otp_re_sources PREPEND "${_otp_re_root}/pcre2/")
function(otp_add_re_native target instrumented)
    add_library(${target} OBJECT "${_otp_re_root}/re_nif.c" ${_otp_re_sources})
    target_compile_features(${target} PRIVATE c_std_11)
    target_link_libraries(${target} PRIVATE BEAM::NIF)
    target_compile_definitions(${target} PRIVATE STATIC_ERLANG_NIF_LIBNAME=otp_re
        ERLANG_INTEGRATION PCRE2_CODE_UNIT_WIDTH=8 PCRE2_STATIC HAVE_CONFIG_H)
    target_include_directories(${target} PRIVATE "${_otp_re_root}/pcre2" "${_otp_re_generated}")
    set_target_properties(${target} PROPERTIES C_VISIBILITY_PRESET hidden POSITION_INDEPENDENT_CODE ON)
    if(MSVC)
        target_compile_options(${target} PRIVATE /experimental:c11atomics "/FI${_otp_re_generated}/backend_symbols.h")
    else()
        target_compile_options(${target} PRIVATE -include "${_otp_re_generated}/backend_symbols.h")
    endif()
    if(instrumented)
        target_compile_definitions(${target} PRIVATE OTP_RE_TESTING)
        if(NOT ARGC GREATER 2 OR ARGV2)
            target_compile_definitions(${target} PRIVATE DEBUG)
        endif()
        set_target_properties(${target} PROPERTIES EXCLUDE_FROM_ALL TRUE)
    endif()
endfunction()
otp_add_re_native(otp_re_nif FALSE)
otp_register_native(otp_re_nif builtin-nif re "${_otp_re_root}/re_nif.c"
    "${_static_directory}/re${CMAKE_SHARED_MODULE_SUFFIX}" ${_otp_re_sources})
