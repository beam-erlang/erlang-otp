# Dictionary compilation has a private compiler stage and explicit inherited-codec dependencies.

otp_application_version(diameter _version)
set(_diameter_debug_options)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(_diameter_debug_options "{d,debug}" warn_obsolete_bool_op)
endif()
set(_diameter_options ${_diameter_debug_options}
    warn_export_vars warn_unused_vars nowarn_deprecated_catch
    "{parse_transform,sys_pre_attributes}"
    "{attribute,insert,app_vsn,\"diameter-${_version}\"}")
set(_generated "${OTP_GENERATED_ROOT}/diameter/src")
set(_compiler "${OTP_INTERNAL_ROOT}/diameter/dictionary-tools")
set(_syntax "${OTP_BOOTSTRAP_ROOT}/lib/syntax_tools/ebin")
set(_parser "${_generated}/compiler/diameter_dict_parser.erl")
set_property(SOURCE "${_parser}" PROPERTY OTP_INSTALL_SOURCE_DIRECTORY gen)
get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_dict_parser.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${_parser}"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_dict_parser.yrl")
otp_generator(TARGET otp_diameter_parser
    COMMANDS ${_parser_command}
    OUTPUTS "${_parser}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_dict_parser.yrl" otp_bootstrap_parsetools ${_parser_command_INPUTS}
)
set(_compiler_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_codegen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_exprecs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_dict_scanner.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_dict_util.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_make.erl"
    "${_parser}"
)
set(_compiler_outputs)
foreach(_source IN LISTS _compiler_sources)
    get_filename_component(_module "${_source}" NAME_WE)
    list(APPEND _compiler_outputs "${_compiler}/${_module}.beam")
endforeach()
otp_add_compile_job(TARGET otp_diameter_compiler APP diameter
    OUT "${_compiler}" GENERATED "${_generated}/gen"
    SOURCES ${_compiler_sources}
    OPTIONS warnings_as_errors warn_missing_doc_function warn_missing_doc_callback
        warn_missing_spec_documented ${_diameter_options}
    PATHS "${_syntax}"
    OWN_CODE_PATH
    DEPENDS otp_diameter_parser otp_bootstrap_syntax_tools
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_forms.hrl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_vsn.hrl"
)

# Accounting dictionaries consume the compiled base dictionary's dict/0.
set(_dictionaries base_rfc3588 base_rfc6733 base_accounting acct_rfc6733 doic_rfc7683 relay)
set(_dictionary_sources)
set(_dictionary_headers)
set(_dictionary_targets)
foreach(_dictionary IN LISTS _dictionaries)
    set(_inherited)
    if(_dictionary STREQUAL base_accounting)
        set(_inherited "${_compiler}/diameter_gen_base_rfc3588.beam")
    elseif(_dictionary STREQUAL acct_rfc6733)
        set(_inherited "${_compiler}/diameter_gen_base_rfc6733.beam")
    endif()
    set(_schema "${CMAKE_CURRENT_SOURCE_DIR}/src/dict/${_dictionary}.dia")
    set(_module "diameter_gen_${_dictionary}")
    otp_command(_dictionary_command "${_generated}/gen"
        "${OTP_BOOTSTRAP_ROOT}/bin/escript" "${CMAKE_CURRENT_SOURCE_DIR}/bin/diameterc"
        -i "${_compiler}" -o "${_generated}/gen" "${_schema}")
    otp_generator(TARGET otp_diameter_generate_${_dictionary}
        COMMANDS ${_dictionary_command}
        OUTPUTS "${_generated}/gen/${_module}.erl" "${_generated}/gen/${_module}.hrl"
        DEPENDS "${_schema}" ${_compiler_outputs} ${_inherited}
            "${CMAKE_CURRENT_SOURCE_DIR}/bin/diameterc"
            "${CMAKE_CURRENT_SOURCE_DIR}/include/diameter.hrl"
            "${CMAKE_CURRENT_SOURCE_DIR}/include/diameter_gen.hrl"
            otp_diameter_compiler ${_dictionary_command_INPUTS}
    )
    otp_add_compile_job(TARGET otp_diameter_dictionary_${_dictionary} APP diameter
        OUT "${_compiler}" GENERATED "${_generated}/gen"
        SOURCES "${_generated}/gen/${_module}.erl"
        OPTIONS warnings_as_errors warn_missing_doc_function warn_missing_doc_callback
            warn_missing_spec_documented ${_diameter_options}
        PATHS "${_compiler}" "${_syntax}"
        DEPENDS otp_diameter_generate_${_dictionary} otp_diameter_compiler
            "${_generated}/gen/${_module}.hrl"
            "${CMAKE_CURRENT_SOURCE_DIR}/include/diameter.hrl"
            "${CMAKE_CURRENT_SOURCE_DIR}/include/diameter_gen.hrl")
    list(APPEND _dictionary_targets otp_diameter_dictionary_${_dictionary})
    list(APPEND _dictionary_sources "${_generated}/gen/${_module}.erl")
    list(APPEND _dictionary_headers "${_generated}/gen/${_module}.hrl")
endforeach()

set(_sources ${_compiler_sources}
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_callback.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_capx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_config_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_codec.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_dist.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_gen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_misc_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_peer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_peer_fsm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_peer_fsm_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_reg.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_service.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_service_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_session.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_stats.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_sync.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_traffic.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_types.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_watchdog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_watchdog_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/transport/diameter_etcp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/transport/diameter_etcp_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/transport/diameter_tcp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/transport/diameter_tcp_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/transport/diameter_sctp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/transport/diameter_sctp_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/transport/diameter_transport.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/transport/diameter_transport_sup.erl"
    ${_dictionary_sources}
    "${CMAKE_CURRENT_SOURCE_DIR}/src/info/diameter_dbg.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/info/diameter_info.erl"
)
set(_runtime_modules "diameter,diameter_app,diameter_callback,diameter_capx,diameter_config,diameter_config_sup,diameter_codec,diameter_dist,diameter_gen,diameter_lib,diameter_misc_sup,diameter_peer,diameter_peer_fsm,diameter_peer_fsm_sup,diameter_reg,diameter_service,diameter_service_sup,diameter_session,diameter_stats,diameter_sup,diameter_sync,diameter_traffic,diameter_types,diameter_watchdog,diameter_watchdog_sup,diameter_etcp,diameter_etcp_sup,diameter_tcp,diameter_tcp_sup,diameter_sctp,diameter_sctp_sup,diameter_transport,diameter_transport_sup,diameter_gen_base_rfc3588,diameter_gen_base_rfc6733,diameter_gen_base_accounting,diameter_gen_acct_rfc6733,diameter_gen_doic_rfc7683,diameter_gen_relay")
set(_compiler_modules "diameter_codegen,diameter_exprecs,diameter_dict_scanner,diameter_dict_util,diameter_make,diameter_dict_parser")
set(_info_modules "diameter_dbg,diameter_info")
otp_add_application(APP diameter
    SOURCES ${_sources}
    OPTIONS ${_diameter_options}
    DEPENDS ${_dictionary_targets} otp_bootstrap_syntax_tools
    OWN_CODE_PATH
    PRESERVE_SOURCE_LAYOUT
    SUBSTITUTIONS
        "%MODULES%" "${_runtime_modules}"
        "%COMPILER%" "${_compiler_modules}"
        "%INFO%" "${_info_modules}"
        "%REGISTERED%" "diameter_config,diameter_peer,diameter_reg,diameter_stats,diameter_sync"
)
install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/bin/diameterc" DESTINATION "lib/diameter-${_version}/bin")
install(FILES ${_dictionary_headers} DESTINATION "lib/diameter-${_version}/include")
foreach(_dictionary IN LISTS _dictionaries)
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/dict/${_dictionary}.dia"
        DESTINATION "lib/diameter-${_version}/src/dict")
endforeach()
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/base/diameter_internal.hrl"
    DESTINATION "lib/diameter-${_version}/src/base")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_forms.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_vsn.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compiler/diameter_dict_parser.yrl"
    DESTINATION "lib/diameter-${_version}/src/compiler")
