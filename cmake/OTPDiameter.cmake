# Diameter owns its parser, dictionary compiler and generated protocol modules.
set(_dia_runtime
    diameter diameter_app diameter_callback diameter_capx diameter_config
    diameter_config_sup diameter_codec diameter_dist diameter_gen diameter_lib
    diameter_misc_sup diameter_peer diameter_peer_fsm diameter_peer_fsm_sup
    diameter_reg diameter_service diameter_service_sup diameter_session
    diameter_stats diameter_sup diameter_sync diameter_traffic diameter_types
    diameter_watchdog diameter_watchdog_sup
    diameter_etcp diameter_etcp_sup diameter_tcp diameter_tcp_sup diameter_sctp
    diameter_sctp_sup diameter_transport diameter_transport_sup)
set(_dia_compiler diameter_codegen diameter_exprecs diameter_dict_scanner
    diameter_dict_util diameter_make)
set(_dia_info diameter_dbg diameter_info)
set(_dia_dicts base_rfc3588 base_rfc6733 base_accounting acct_rfc6733 doic_rfc7683 relay)
set(_dia_parser "${_generated}/diameter_dict_parser.erl")
add_custom_command(OUTPUT "${_dia_parser}"
    COMMAND ${OTP_BUILD_COMMAND}
        parser "${PROJECT_SOURCE_DIR}" "${_otp_tools}"
        "${_source}/compiler/diameter_dict_parser.yrl" "${_dia_parser}" "${OTP_BUILD_ROOT}"
    DEPENDS "${_source}/compiler/diameter_dict_parser.yrl" ${_tool_outputs} "${_otp_driver}" otp_build_host
    COMMENT "Generating the Diameter dictionary parser" VERBATIM)
set(_sources)
foreach(_module IN LISTS _dia_compiler)
    list(APPEND _sources "${_source}/compiler/${_module}.erl")
endforeach()
list(APPEND _sources "${_dia_parser}")
set(_dia_tool_sources ${_sources})
foreach(_module IN LISTS _dia_runtime)
    if(_module MATCHES "^diameter_(etcp|tcp|sctp|transport)(_sup)?$")
        set(_subdir transport)
    else()
        set(_subdir base)
    endif()
    list(APPEND _sources "${_source}/${_subdir}/${_module}.erl")
endforeach()
foreach(_module IN LISTS _dia_info)
    list(APPEND _sources "${_source}/info/${_module}.erl")
endforeach()
set(_dia_outputs)
set(_dia_schemas)
set(_dia_dict_modules)
foreach(_dict IN LISTS _dia_dicts)
    list(APPEND _dia_schemas "${_source}/dict/${_dict}.dia")
    list(APPEND _dia_dict_modules "diameter_gen_${_dict}")
    list(APPEND _sources "${_generated}/diameter_gen_${_dict}.erl")
    list(APPEND _dia_outputs "${_generated}/diameter_gen_${_dict}.erl"
        "${_generated}/diameter_gen_${_dict}.hrl")
    install(FILES "${_generated}/diameter_gen_${_dict}.hrl" DESTINATION "lib/diameter-${_version}/include")
    install(FILES "${_generated}/diameter_gen_${_dict}.erl" DESTINATION "lib/diameter-${_version}/src/gen")
endforeach()
otp_application_version(syntax_tools _syntax_version)
set(_dia_syntax "${PROJECT_BINARY_DIR}/otp/lib/syntax_tools-${_syntax_version}/ebin")
add_custom_command(OUTPUT ${_dia_outputs}
    COMMAND ${OTP_BUILD_COMMAND}
        diameter "${PROJECT_SOURCE_DIR}" "${_generated}" "${_ebin}" "${_dia_syntax}"
        "${OTP_BUILD_ROOT}" --tools ${_dia_tool_sources} --dictionaries ${_dia_schemas}
    DEPENDS ${_dia_schemas} ${_dia_tool_sources} ${_otp_headers} ${_otp_syntax_outputs}
        "${_otp_driver}" otp_build_host
    COMMENT "Generating Diameter dictionaries with their source-built compiler" VERBATIM)
list(APPEND _extra_dependencies ${_dia_outputs} ${_otp_syntax_outputs})
list(APPEND _code_dependencies "${_dia_syntax}")

# Keep compiler/info entries commented, as in the upstream resource template.
set(_resources "${_generated}/resources")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_source}/diameter.app.src")
file(READ "${_source}/diameter.app.src" _dia_resource)
list(JOIN _dia_runtime "," _dia_runtime_text)
list(JOIN _dia_dict_modules "," _dia_dict_text)
list(JOIN _dia_compiler "," _dia_compiler_text)
list(JOIN _dia_info "," _dia_info_text)
string(REPLACE "%MODULES%" "${_dia_runtime_text},${_dia_dict_text}" _dia_resource "${_dia_resource}")
string(REPLACE "%COMPILER%" "${_dia_compiler_text},diameter_dict_parser" _dia_resource "${_dia_resource}")
string(REPLACE "%INFO%" "${_dia_info_text}" _dia_resource "${_dia_resource}")
string(REPLACE "%REGISTERED%" "diameter_config,diameter_peer,diameter_reg,diameter_stats,diameter_sync"
    _dia_resource "${_dia_resource}")
file(CONFIGURE OUTPUT "${_resources}/diameter.app.src" CONTENT "${_dia_resource}" @ONLY)
configure_file("${_source}/diameter.appup.src" "${_resources}/diameter.appup.src" COPYONLY)
install(PROGRAMS "${PROJECT_SOURCE_DIR}/lib/diameter/bin/diameterc" DESTINATION "lib/diameter-${_version}/bin")
install(DIRECTORY "${_source}/" DESTINATION "lib/diameter-${_version}/src"
    FILES_MATCHING PATTERN "*.erl" PATTERN "*.hrl" PATTERN "*.yrl")
install(FILES ${_dia_schemas} DESTINATION "lib/diameter-${_version}/src/dict")
install(FILES "${_dia_parser}" DESTINATION "lib/diameter-${_version}/src/gen")
