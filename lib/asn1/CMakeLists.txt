# asn1 application sources, generation and release rules.
otp_application_version(asn1 _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_check.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1_db.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_pretty_format.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_func.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_gen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_gen_check.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_gen_per.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_name.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_constructed_per.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_constructed_ber_bin_v2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_gen_ber_bin_v2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_gen_jer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_imm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_value.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_tok.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_parser2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_table.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_partial_decode.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1rt_nif.erl"
    "${OTP_GENERATED_ROOT}/asn1/src/asn1ct_rtt.erl"
    "${OTP_GENERATED_ROOT}/asn1/src/asn1ct_eval_ext.erl"
)

# Retained template generators consume private, source-built tool modules.
set(_template_tools "${OTP_INTERNAL_ROOT}/asn1/template-tools")
set(_template_modules
    asn1rtt_check asn1rtt_ext asn1rtt_per_common asn1rtt_real_common
    asn1rtt_ber asn1rtt_jer asn1rtt_per asn1rtt_uper)
set(_template_sources "${CMAKE_CURRENT_SOURCE_DIR}/src/prepare_templates.erl")
set(_template_beams)
foreach(_module IN LISTS _template_modules)
    list(APPEND _template_sources "${CMAKE_CURRENT_SOURCE_DIR}/src/${_module}.erl")
    list(APPEND _template_beams "${_template_tools}/${_module}.beam")
endforeach()
file(GLOB _template_headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl")
otp_add_compile_job(TARGET otp_asn1_template_tools APP asn1 STAGE otp_bootstrap_setup
    OUT "${_template_tools}" GENERATED "${OTP_GENERATED_ROOT}/asn1/src"
    SOURCES ${_template_sources}
    DEPENDS ${_template_headers})
otp_command(_templates_command "${OTP_GENERATED_ROOT}/asn1/src"
    "${OTP_BOOTSTRAP_ROOT}/bin/erl" +S 2:2 -noshell -noinput -pa "${_template_tools}"
    -run prepare_templates gen_asn1ct_rtt ${_template_beams})
otp_generator(TARGET otp_asn1_templates
    COMMANDS ${_templates_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/asn1/src/asn1ct_rtt.erl"
    DEPENDS otp_asn1_template_tools ${_template_beams} ${_templates_command_INPUTS})

set(_eval_tools "${OTP_INTERNAL_ROOT}/asn1/eval-tools")
otp_add_compile_job(TARGET otp_asn1_eval_tools APP asn1 STAGE otp_bootstrap_setup
    OUT "${_eval_tools}" GENERATED "${OTP_GENERATED_ROOT}/asn1/src"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/prepare_templates.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_func.erl"
        "${OTP_GENERATED_ROOT}/asn1/src/asn1ct_rtt.erl"
    OWN_CODE_PATH
    DEPENDS otp_asn1_templates ${_template_headers})
otp_command(_eval_command "${OTP_GENERATED_ROOT}/asn1/src"
    "${OTP_BOOTSTRAP_ROOT}/bin/erl" +S 2:2 -noshell -noinput -pa "${_eval_tools}"
    -run prepare_templates gen_asn1ct_eval asn1ct_eval_ext.funcs)
otp_generator(TARGET otp_asn1_eval
    COMMANDS
        COMMAND "${CMAKE_COMMAND}" -E copy
            "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_eval_ext.funcs"
            "${OTP_GENERATED_ROOT}/asn1/src/asn1ct_eval_ext.funcs"
        ${_eval_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/asn1/src/asn1ct_eval_ext.erl"
        "${OTP_GENERATED_ROOT}/asn1/src/asn1ct_eval_ext.funcs"
    DEPENDS otp_asn1_eval_tools "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct_eval_ext.funcs"
        ${_eval_command_INPUTS})

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1ct.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,vsn,\"${_version}\"}")
otp_add_application(
    APP asn1
    SOURCES ${_sources}
    OPTIONS nowarn_deprecated_catch
    DEPENDS otp_asn1_eval
    INPUTS ${_headers}
)


add_library(otp_asn1_nif MODULE c_src/asn1_erl_nif.c)
target_link_libraries(otp_asn1_nif PRIVATE BEAM::NIF otp_native_config)
otp_linux_native_flags(otp_asn1_nif DED)
if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
    # Unlike Crypto, the original ASN.1 recipe keeps -O3 for Debug too.
    target_compile_options(otp_asn1_nif PRIVATE -g -O3
        -Werror=undef -Werror=implicit -Werror=return-type
        -Wdeclaration-after-statement -Wall -Wstrict-prototypes -Wmissing-prototypes)
    target_compile_definitions(otp_asn1_nif PRIVATE
        _THREAD_SAFE _REENTRANT POSIX_THREADS _POSIX_THREAD_SAFE_FUNCTIONS)
endif()
set_target_properties(otp_asn1_nif PROPERTIES
    PREFIX ""
    OUTPUT_NAME asn1rt_nif
    LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/asn1/priv/lib/${OTP_TARGET}"
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/asn1/priv/lib/${OTP_TARGET}"
)
install(TARGETS otp_asn1_nif LIBRARY DESTINATION "lib/asn1-${_version}/priv/lib"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    RUNTIME DESTINATION "lib/asn1-${_version}/priv/lib")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/c_src/asn1_erl_nif.c"
    DESTINATION "lib/asn1-${_version}/c_src")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1.app.src"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/asn1.appup.src"
    DESTINATION "lib/asn1-${_version}/src")
