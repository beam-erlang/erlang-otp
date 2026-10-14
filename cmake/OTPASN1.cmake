# Source-owned ASN.1 generators run as separate installed compiler-host jobs.
set(_asn1_src "${PROJECT_SOURCE_DIR}/lib/asn1/src")
set(_asn1_gen "${PROJECT_BINARY_DIR}/generated/asn1")
set(_asn1_templates asn1rtt_check asn1rtt_ext asn1rtt_per_common asn1rtt_real_common
    asn1rtt_ber asn1rtt_jer asn1rtt_per asn1rtt_uper)
set(_asn1_template_sources)
foreach(_module IN LISTS _asn1_templates)
    list(APPEND _asn1_template_sources "${_asn1_src}/${_module}.erl")
endforeach()
add_custom_command(OUTPUT "${_asn1_gen}/asn1ct_rtt.erl"
    COMMAND ${OTP_BUILD_COMMAND}
        asn1-templates "${PROJECT_SOURCE_DIR}" "${_asn1_gen}" "${OTP_BUILD_ROOT}" ${_asn1_templates}
    DEPENDS ${_asn1_template_sources} "${_asn1_src}/prepare_templates.erl"
        ${_otp_headers} "${_otp_driver}" otp_build_host
    COMMENT "Generating ASN.1 runtime templates from source bytecode" VERBATIM)
add_custom_command(OUTPUT "${_asn1_gen}/asn1ct_eval_ext.erl"
    COMMAND ${OTP_BUILD_COMMAND}
        asn1-eval "${PROJECT_SOURCE_DIR}" "${_asn1_gen}" "${OTP_BUILD_ROOT}"
    DEPENDS "${_asn1_gen}/asn1ct_rtt.erl" "${_asn1_src}/asn1ct_eval_ext.funcs"
        "${_asn1_src}/asn1ct_func.erl" "${_asn1_src}/prepare_templates.erl"
        ${_otp_headers} "${_otp_driver}" otp_build_host
    COMMENT "Generating ASN.1 compile-time evaluation functions" VERBATIM)

otp_application_version(asn1 _asn1_version)
add_library(otp_asn1_nif MODULE "${PROJECT_SOURCE_DIR}/lib/asn1/c_src/asn1_erl_nif.c")
target_link_libraries(otp_asn1_nif PRIVATE BEAM::NIF)
set_target_properties(otp_asn1_nif PROPERTIES PREFIX "" OUTPUT_NAME asn1rt_nif
    LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/lib/asn1-${_asn1_version}/priv/lib")
install(TARGETS otp_asn1_nif
    LIBRARY DESTINATION "lib/asn1-${_asn1_version}/priv/lib"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    RUNTIME DESTINATION "lib/asn1-${_asn1_version}/priv/lib"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
