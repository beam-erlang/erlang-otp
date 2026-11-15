# snmp application sources, generation and release rules.
otp_application_version(snmp _version)
set(_snmp_options warn_unused_vars nowarn_deprecated_catch
    "{parse_transform,sys_pre_attributes}"
    "{attribute,insert,app_vsn,\"snmp-${_version}\"}"
    "{d,version,\"${_version}\"}")

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_lib.erl"
    "${OTP_GENERATED_ROOT}/snmp/src/compile/snmpc_mib_gram.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_mib_to_hrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_misc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_tok.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/app/snmp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/app/snmp_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/app/snmp_app_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_authentication_service.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_discovery_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_error_report.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_get_mechanism.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mib_storage.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mib_data.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_network_interface.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_network_interface_filter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_notification_delivery_info_receiver.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_notification_filter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_set_mechanism.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_community_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_framework_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_notification_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_standard_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_target_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_user_based_sm_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_view_based_acm_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_acm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_agent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_agent_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_conf.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_discovery_handler_default.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_error.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_error_io.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_error_logger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_get.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_get_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_local_db.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mib_storage_ets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mib_storage_dets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mib_storage_mnesia.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mib_data_tttn.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mib_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_misc_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_mpd.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_net_if.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_net_if_filter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_set.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_set_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_supervisor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_svbl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_symbolic_store.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_target_cache.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_trap.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_usm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_vacm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_generic.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_generic_mnesia.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_index.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmp_shadow_table.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_user.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_user_old.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_network_interface.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_network_interface_filter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_conf.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_mpd.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_misc_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_net_if.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_net_if_mt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_net_if_filter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_server_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_supervisor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_user_default.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_usm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_conf.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_log.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_mini_mib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_misc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_note_store.erl"
    "${OTP_GENERATED_ROOT}/snmp/src/misc/snmp_pdus_basic.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_pdus.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_usm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_verbosity.erl"
)

foreach(_source IN LISTS _sources)
    if(_source MATCHES "/src/agent/")
        set_property(SOURCE "${_source}" PROPERTY OTP_COMPILE_OPTIONS
            "{d,empty_pdu_size,21}" "{d,default_verbosity,silence}" nowarn_missing_spec_documented)
    elseif(_source MATCHES "/src/app/")
        set_property(SOURCE "${_source}" PROPERTY OTP_COMPILE_OPTIONS
            "{d,default_verbosity,silence}" warn_obsolete_bool_op)
    elseif(_source MATCHES "/src/(manager|misc)/")
        set_property(SOURCE "${_source}" PROPERTY OTP_COMPILE_OPTIONS "{d,default_verbosity,silence}")
    endif()
endforeach()

get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_mib_gram.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${OTP_GENERATED_ROOT}/snmp/src/compile/snmpc_mib_gram.erl"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_mib_gram.yrl")
otp_generator(TARGET otp_generate_snmpc_mib_gram
    COMMANDS ${_parser_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/snmp/src/compile/snmpc_mib_gram.erl"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_mib_gram.yrl"
        otp_bootstrap_parsetools ${_parser_command_INPUTS}
)
set(_snmp_mibs
    RFC1213-MIB
    STANDARD-MIB
    SNMPv2-TM
    SNMPv2-MIB
    SNMP-FRAMEWORK-MIB
    SNMP-MPD-MIB
    SNMP-TARGET-MIB
    SNMP-NOTIFICATION-MIB
    SNMP-COMMUNITY-MIB
    SNMP-USER-BASED-SM-MIB
    SNMP-VIEW-BASED-ACM-MIB
    SNMP-USM-AES-MIB
    INET-ADDRESS-MIB
    TRANSPORT-ADDRESS-MIB
    SNMP-USM-HMAC-SHA2-MIB
    OTP-REG
    OTP-TC
    OTP-SNMPEA-MIB
)
file(GLOB_RECURSE _snmp_resource_inputs CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/mibs/*" "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/*.asn")
# Each retained generator is an explicit native frontend invocation.
otp_erlc_command(_pdus_command "${CMAKE_CURRENT_SOURCE_DIR}/src/misc"
    "${OTP_GENERATED_ROOT}/snmp/src/misc"
    FLAGS -bber OPTIONS noobj SOURCES snmp_pdus_basic.set.asn)
otp_generator(TARGET otp_snmp_pdus_schema
    COMMANDS ${_pdus_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/snmp/src/misc/snmp_pdus_basic.erl"
        "${OTP_GENERATED_ROOT}/snmp/src/misc/snmp_pdus_basic.asn1db"
    DEPENDS otp_bootstrap_asn1 ${_snmp_resource_inputs} ${_pdus_command_INPUTS})
set(_mib_compiler "${OTP_INTERNAL_ROOT}/snmp/mib-compiler")
otp_add_compile_job(TARGET otp_snmp_mib_compiler APP snmp STAGE otp_secondary_bootstrap_ready
    OUT "${_mib_compiler}" GENERATED "${OTP_GENERATED_ROOT}/snmp/src/misc"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_misc.erl"
        "${OTP_GENERATED_ROOT}/snmp/src/compile/snmpc_mib_gram.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_lib.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_mib_to_hrl.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_misc.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_tok.erl"
    OPTIONS warnings_as_errors warn_missing_doc_function warn_missing_doc_callback
        warn_missing_spec_documented ${_snmp_options}
    OWN_CODE_PATH
    DEPENDS otp_bootstrap_asn1 otp_headers_snmp otp_generate_snmpc_mib_gram
        otp_snmp_pdus_schema ${_snmp_resource_inputs})
set(_mib_out "${PROJECT_BINARY_DIR}/lib/snmp/priv/mibs")
set(_mib_include "${PROJECT_BINARY_DIR}/lib/snmp/include")
set(_resource_commands)
set(_resource_command_inputs)
set(_compiled_mib_outputs)
# Preserve the declared order: later MIBs import earlier compiled MIBs.
foreach(_mib IN LISTS _snmp_mibs)
    otp_command(_mib_command "${CMAKE_CURRENT_SOURCE_DIR}/mibs"
        "${OTP_BOOTSTRAP_ROOT}/bin/erlc" -no-server -pa "${_mib_compiler}"
        -pz "${PROJECT_BINARY_DIR}/lib/snmp/ebin"
        -I "${_mib_out}" -o "${_mib_out}" "${_mib}.mib")
    otp_command(_hrl_command "${CMAKE_CURRENT_SOURCE_DIR}/mibs"
        "${OTP_BOOTSTRAP_ROOT}/bin/erlc" -no-server -pa "${_mib_compiler}"
        -pz "${PROJECT_BINARY_DIR}/lib/snmp/ebin"
        -o "${_mib_include}" "${_mib_out}/${_mib}.bin")
    list(APPEND _resource_commands ${_mib_command} ${_hrl_command})
    list(APPEND _resource_command_inputs ${_mib_command_INPUTS} ${_hrl_command_INPUTS})
    list(APPEND _compiled_mib_outputs "${_mib_out}/${_mib}.bin" "${_mib_include}/${_mib}.hrl")
endforeach()
otp_generator(TARGET otp_snmp_resources
    COMMANDS ${_resource_commands}
    OUTPUTS ${_compiled_mib_outputs}
    DEPENDS otp_snmp_mib_compiler ${_snmp_resource_inputs} ${_resource_command_inputs})

file(GLOB_RECURSE _mibs_inputs CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/mibs/*")
set(_mibs_outputs)
foreach(_input IN LISTS _mibs_inputs)
    file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}/mibs" "${_input}")
    list(APPEND _mibs_outputs "${PROJECT_BINARY_DIR}/lib/snmp/mibs/${_relative}")
endforeach()
add_custom_command(OUTPUT ${_mibs_outputs}
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/mibs" "${PROJECT_BINARY_DIR}/lib/snmp/mibs"
    DEPENDS ${_mibs_inputs}
    VERBATIM
)
file(GLOB_RECURSE _priv_conf_inputs CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/priv/conf/*")
set(_priv_conf_outputs)
foreach(_input IN LISTS _priv_conf_inputs)
    file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}/priv/conf" "${_input}")
    list(APPEND _priv_conf_outputs "${PROJECT_BINARY_DIR}/lib/snmp/priv/conf/${_relative}")
endforeach()
add_custom_command(OUTPUT ${_priv_conf_outputs}
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/priv/conf" "${PROJECT_BINARY_DIR}/lib/snmp/priv/conf"
    DEPENDS ${_priv_conf_inputs}
    VERBATIM
)
otp_cmake_literal(_snmpc_source "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc.src")
otp_cmake_literal(_snmpc_output "${PROJECT_BINARY_DIR}/lib/snmp/bin/snmpc")
otp_cmake_literal(_snmpc_directory "${PROJECT_BINARY_DIR}/lib/snmp/bin")
otp_cmake_literal(_snmpc_version "${_version}")
set(_snmpc_script "${OTP_INTERNAL_ROOT}/snmp/snmpc.cmake")
file(GENERATE OUTPUT "${_snmpc_script}" CONTENT
    "file(READ ${_snmpc_source} _script)\nstring(REPLACE [=[%VSN%]=] ${_snmpc_version} _script \"\${_script}\")\nfile(MAKE_DIRECTORY ${_snmpc_directory})\nfile(WRITE ${_snmpc_output} \"\${_script}\")\nfile(CHMOD ${_snmpc_output} PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)\n")
add_custom_command(OUTPUT "${PROJECT_BINARY_DIR}/lib/snmp/bin/snmpc"
    COMMAND "${CMAKE_COMMAND}" -P "${_snmpc_script}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc.src" "${_snmpc_script}"
    VERBATIM
)
add_custom_target(otp_snmpc_script DEPENDS
    "${PROJECT_BINARY_DIR}/lib/snmp/bin/snmpc"
)
add_custom_command(
    OUTPUT
        "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC1155-SMI.mib"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/mibs/RFC1155-SMI.mib" "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC1155-SMI.mib"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/mibs/RFC1155-SMI.mib"

    VERBATIM
)
add_custom_target(otp_snmp_v1_RFC1155-SMI DEPENDS
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC1155-SMI.mib"
)
add_custom_command(
    OUTPUT
        "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1212.mib"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/mibs/RFC-1212.mib" "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1212.mib"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/mibs/RFC-1212.mib"

    VERBATIM
)
add_custom_target(otp_snmp_v1_RFC-1212 DEPENDS
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1212.mib"
)
add_custom_command(
    OUTPUT
        "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1215.mib"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/mibs/RFC-1215.mib" "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1215.mib"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/mibs/RFC-1215.mib"

    VERBATIM
)
add_custom_target(otp_snmp_v1_RFC-1215 DEPENDS
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1215.mib"
)
otp_capture_command(_mib_convert "${CMAKE_CURRENT_SOURCE_DIR}/mibs"
    "${OTP_INTERNAL_ROOT}/snmp/OTP-SNMPEA-MIB.converted"
    "${PERL_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/bin/snmp-v2tov1.pl"
    "${CMAKE_CURRENT_SOURCE_DIR}/mibs/OTP-SNMPEA-MIB.mib")
otp_capture_command(_mib_filter "${CMAKE_CURRENT_SOURCE_DIR}/mibs"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/OTP-SNMPEA-MIB.mib.v1"
    "${PERL_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/cmake/snmp_v2tov1_filter.pl"
    "${OTP_INTERNAL_ROOT}/snmp/OTP-SNMPEA-MIB.converted")
add_custom_command(OUTPUT
        "${OTP_INTERNAL_ROOT}/snmp/OTP-SNMPEA-MIB.converted"
        "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/OTP-SNMPEA-MIB.mib.v1"
    COMMAND "${CMAKE_COMMAND}" -E make_directory
        "${OTP_INTERNAL_ROOT}/snmp" "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1"
    ${_mib_convert}
    ${_mib_filter}
    DEPENDS ${_mib_convert_INPUTS} ${_mib_filter_INPUTS}
        "${CMAKE_CURRENT_SOURCE_DIR}/bin/snmp-v2tov1.pl"
        "${CMAKE_CURRENT_SOURCE_DIR}/bin/snmp-v2tov1.sed"
        "${PROJECT_SOURCE_DIR}/cmake/snmp_v2tov1_filter.pl"
        "${CMAKE_CURRENT_SOURCE_DIR}/mibs/OTP-SNMPEA-MIB.mib"
    VERBATIM
)
add_custom_target(otp_snmp_v1_conversion DEPENDS
    "${OTP_INTERNAL_ROOT}/snmp/OTP-SNMPEA-MIB.converted"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/OTP-SNMPEA-MIB.mib.v1"
)
add_custom_target(otp_snmp_assets ALL DEPENDS
    "${_mibs_outputs}"
    "${_priv_conf_outputs}"
    "${PROJECT_BINARY_DIR}/lib/snmp/bin/snmpc"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC1155-SMI.mib"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1212.mib"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1215.mib"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/OTP-SNMPEA-MIB.mib.v1"
)

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP snmp
    SOURCES ${_sources}
    OPTIONS ${_snmp_options}
    DEPENDS otp_snmp_resources
    INPUTS ${_headers}
    RESOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/app"
    OWN_CODE_PATH
    NO_SOURCE_INSTALL
    NO_SOURCE_SUPPORT_INSTALL
)


foreach(_source IN LISTS _sources)
    if(_source MATCHES "^${CMAKE_CURRENT_SOURCE_DIR}/src/")
        file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}/src" "${_source}")
        get_filename_component(_directory "${_relative}" DIRECTORY)
        if(_directory STREQUAL compile)
            set(_directory compiler)
        endif()
    elseif(_source MATCHES "snmpc_mib_gram[.]erl$")
        set(_directory compiler)
    else()
        set(_directory misc)
    endif()
    install(FILES "${_source}" DESTINATION "lib/snmp-${_version}/src/${_directory}")
endforeach()
set(_support_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_atl.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_internal.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/agent/snmpa_vacm.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/app/snmp_internal.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_lib.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_mib_gram.yrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc_misc.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_atl.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_internal.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/manager/snmpm_usm.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_debug.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_usm.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc/snmp_verbosity.hrl")
foreach(_support IN LISTS _support_sources)
    file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}/src" "${_support}")
    get_filename_component(_directory "${_relative}" DIRECTORY)
    if(_directory STREQUAL compile)
        set(_directory compiler)
    endif()
    install(FILES "${_support}" DESTINATION "lib/snmp-${_version}/src/${_directory}")
endforeach()
install(DIRECTORY "${PROJECT_BINARY_DIR}/lib/snmp/include/" DESTINATION "lib/snmp-${_version}/include")
set(_release_mibs)
set(_release_mib_bins)
foreach(_mib IN LISTS _snmp_mibs)
    list(APPEND _release_mibs "${CMAKE_CURRENT_SOURCE_DIR}/mibs/${_mib}.mib")
    list(APPEND _release_mib_bins "${_mib_out}/${_mib}.bin")
endforeach()
install(FILES ${_release_mib_bins} DESTINATION "lib/snmp-${_version}/priv/mibs")
install(FILES ${_release_mibs}
    "${CMAKE_CURRENT_SOURCE_DIR}/mibs/SNMPv2-SMI.mib"
    "${CMAKE_CURRENT_SOURCE_DIR}/mibs/SNMPv2-TC.mib"
    "${CMAKE_CURRENT_SOURCE_DIR}/mibs/SNMPv2-CONF.mib"
    "${CMAKE_CURRENT_SOURCE_DIR}/mibs/STANDARD-MIB.funcs"
    "${CMAKE_CURRENT_SOURCE_DIR}/mibs/SNMPv2-MIB.funcs"
    "${CMAKE_CURRENT_SOURCE_DIR}/mibs/SNMP-NOTIFICATION-MIB.funcs"
    "${CMAKE_CURRENT_SOURCE_DIR}/mibs/SNMP-TARGET-MIB.funcs"
    DESTINATION "lib/snmp-${_version}/mibs")
install(FILES
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC1155-SMI.mib"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1212.mib"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/RFC-1215.mib"
    "${PROJECT_BINARY_DIR}/lib/snmp/mibs/v1/OTP-SNMPEA-MIB.mib.v1"
    DESTINATION "lib/snmp-${_version}/mibs/v1")
foreach(_role IN ITEMS agent manager)
    if(_role STREQUAL agent)
        set(_conf_names agent community context notify standard target_addr target_params usm vacm)
    else()
        set(_conf_names manager agents users)
    endif()
    set(_conf_files)
    foreach(_name IN LISTS _conf_names)
        list(APPEND _conf_files "${CMAKE_CURRENT_SOURCE_DIR}/priv/conf/${_role}/${_name}.conf")
    endforeach()
    install(FILES ${_conf_files} DESTINATION "lib/snmp-${_version}/priv/conf/${_role}")
endforeach()
install(PROGRAMS "${PROJECT_BINARY_DIR}/lib/snmp/bin/snmpc" DESTINATION "lib/snmp-${_version}/bin")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/compile/snmpc.src"
    DESTINATION "lib/snmp-${_version}/src/compiler")

foreach(_mib IN LISTS _snmp_mibs)
    set_property(TARGET otp_app_snmp APPEND PROPERTY OTP_PUBLIC_HEADERS
        "${PROJECT_BINARY_DIR}/lib/snmp/include/${_mib}.hrl")
endforeach()
