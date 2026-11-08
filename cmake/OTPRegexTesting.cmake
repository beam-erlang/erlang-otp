# SPDX-License-Identifier: Apache-2.0
# Private acceptance hosts share the production startup and VM. Only regex
# instrumentation and an explicitly supplied test control provider differ.
otp_add_re_native(otp_re_nif_instrumented TRUE TRUE)
otp_add_re_native(otp_re_nif_measured TRUE FALSE)
add_library(otp_re_test_control OBJECT "${PROJECT_SOURCE_DIR}/tools/fixtures/re_test_control.c")
target_link_libraries(otp_re_test_control PRIVATE BEAM::NIF)
target_compile_features(otp_re_test_control PRIVATE c_std_11)
target_compile_definitions(otp_re_test_control PRIVATE STATIC_ERLANG_NIF_LIBNAME=otp_re_test)
set_target_properties(otp_re_test_control PROPERTIES EXCLUDE_FROM_ALL TRUE C_VISIBILITY_PRESET hidden)
set(_re_test_assets "${_assets}")
list(LENGTH _nifs _re_native_count)
math(EXPR _re_test_count "${_re_native_count}+1")
string(REPLACE "#define OTP_NIF_COUNT ${_re_native_count}" "#define OTP_NIF_COUNT ${_re_test_count}" _re_test_assets "${_re_test_assets}")
string(REPLACE "static const beam_builtin_nif otp_nifs[] = {\n"
    "extern struct enif_entry_t *otp_re_test_nif_init(void);\nstatic const beam_builtin_nif otp_nifs[] = {\n    {sizeof(beam_builtin_nif), \"otp_re_test\", OTP_SDK_BUILD_ID, otp_re_test_nif_init, 0},\n"
    _re_test_assets "${_re_test_assets}")
file(MAKE_DIRECTORY "${PROJECT_BINARY_DIR}/generated/re-test")
file(CONFIGURE OUTPUT "${PROJECT_BINARY_DIR}/generated/re-test/otp_host_assets.h" CONTENT "${_re_test_assets}" @ONLY)
add_library(otp_re_test_host_inputs OBJECT "${PROJECT_SOURCE_DIR}/tools/otp_host_inputs.c")
target_compile_features(otp_re_test_host_inputs PRIVATE c_std_11)
target_include_directories(otp_re_test_host_inputs PRIVATE "${PROJECT_BINARY_DIR}/generated/re-test" "${PROJECT_BINARY_DIR}/generated")
target_link_libraries(otp_re_test_host_inputs PRIVATE BEAM::RuntimeStatic)
set_target_properties(otp_re_test_host_inputs PROPERTIES EXCLUDE_FROM_ALL TRUE)
foreach(_variant IN ITEMS instrumented measured)
    set(_native ${_otp_linked_native})
    list(REMOVE_ITEM _native otp_re_nif)
    list(APPEND _native "otp_re_nif_${_variant}" otp_re_test_control)
    otp_add_host("otp_re_${_variant}_host" "${PROJECT_BINARY_DIR}/otp/${_preload_relative}" otp_erl
        HOST_INPUTS otp_re_test_host_inputs NATIVE_TARGETS ${_native})
    set_target_properties("otp_re_${_variant}_host" PROPERTIES EXCLUDE_FROM_ALL TRUE)
endforeach()
