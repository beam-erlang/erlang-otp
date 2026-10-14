# SNMP's compiler seed generates MIB resources before the full application.
set(_resources "${_source}/app")
set(_snmp_parser "${_generated}/snmpc_mib_gram.erl")
add_custom_command(OUTPUT "${_snmp_parser}"
    COMMAND ${OTP_BUILD_COMMAND}
        parser "${PROJECT_SOURCE_DIR}" "${_otp_tools}"
        "${_source}/compile/snmpc_mib_gram.yrl" "${_snmp_parser}" "${OTP_BUILD_ROOT}"
    DEPENDS "${_source}/compile/snmpc_mib_gram.yrl" ${_tool_outputs} "${_otp_driver}" otp_build_host
    COMMENT "Generating the SNMP MIB parser" VERBATIM)
set(_snmp_tools "${_snmp_parser}" "${_source}/misc/snmp_misc.erl")
foreach(_module IN ITEMS snmpc snmpc_lib snmpc_mib_to_hrl snmpc_misc snmpc_tok)
    list(APPEND _snmp_tools "${_source}/compile/${_module}.erl")
endforeach()
set(_snmp_mibs RFC1213-MIB STANDARD-MIB SNMPv2-TM SNMPv2-MIB
    SNMP-FRAMEWORK-MIB SNMP-MPD-MIB SNMP-TARGET-MIB SNMP-NOTIFICATION-MIB
    SNMP-COMMUNITY-MIB SNMP-USER-BASED-SM-MIB SNMP-VIEW-BASED-ACM-MIB
    SNMP-USM-AES-MIB INET-ADDRESS-MIB TRANSPORT-ADDRESS-MIB
    SNMP-USM-HMAC-SHA2-MIB OTP-REG OTP-TC OTP-SNMPEA-MIB)
set(_snmp_app "${PROJECT_BINARY_DIR}/otp/lib/snmp-${_version}")
set(_snmp_schema_dir "${PROJECT_SOURCE_DIR}/lib/snmp/mibs")
set(_snmp_schemas)
set(_snmp_generated "${_generated}/snmp_pdus_basic.erl")
foreach(_mib IN LISTS _snmp_mibs)
    list(APPEND _snmp_schemas "${_snmp_schema_dir}/${_mib}.mib")
    list(APPEND _snmp_generated "${_snmp_app}/priv/mibs/${_mib}.bin"
        "${_generated}/${_mib}.hrl" "${_snmp_app}/include/${_mib}.hrl")
    install(FILES "${_snmp_app}/priv/mibs/${_mib}.bin" DESTINATION "lib/snmp-${_version}/priv/mibs")
    install(FILES "${_snmp_app}/include/${_mib}.hrl" DESTINATION "lib/snmp-${_version}/include")
endforeach()
file(GLOB _snmp_funcs CONFIGURE_DEPENDS "${_snmp_schema_dir}/*.funcs")
otp_application_version(asn1 _asn1_version)
add_custom_command(OUTPUT ${_snmp_generated}
    COMMAND ${OTP_BUILD_COMMAND}
        snmp "${PROJECT_SOURCE_DIR}" "${_generated}" "${_snmp_app}"
        "${PROJECT_BINARY_DIR}/otp/lib/asn1-${_asn1_version}/ebin" "${_version}"
        "${OTP_BUILD_ROOT}" --tools ${_snmp_tools} --mibs ${_snmp_schemas}
    DEPENDS ${_snmp_tools} ${_snmp_schemas} ${_snmp_funcs} ${_otp_asn1_outputs}
        ${_otp_headers} "${_source}/misc/snmp_pdus_basic.set.asn"
        "${_source}/misc/snmp_pdus_basic.asn" "${_otp_driver}" otp_build_host
    COMMENT "Generating SNMP ASN.1 codec, compiled MIBs and headers" VERBATIM)
list(APPEND _extra_dependencies ${_snmp_generated})
set(_sources "${_snmp_parser}" "${_generated}/snmp_pdus_basic.erl")
foreach(_part IN ITEMS compile misc app agent manager)
    file(GLOB _part_sources CONFIGURE_DEPENDS "${_source}/${_part}/*.erl")
    list(APPEND _sources ${_part_sources})
    if(_part STREQUAL compile)
        set(_destination compiler)
    else()
        set(_destination "${_part}")
    endif()
    install(DIRECTORY "${_source}/${_part}/" DESTINATION "lib/snmp-${_version}/src/${_destination}"
        FILES_MATCHING PATTERN "*.erl" PATTERN "*.hrl" PATTERN "*.yrl"
        PATTERN "snmpc.src" PATTERN "snmpa_general_db.erl" EXCLUDE)
endforeach()
# This retained experimental module is absent from upstream's product inventory
# and from snmp.app. Do not install it merely because it has an Erlang source.
list(REMOVE_ITEM _sources "${_source}/agent/snmpa_general_db.erl")
set(_snmp_first)
foreach(_module IN ITEMS snmpa snmpa_authentication_service snmpa_discovery_handler
        snmpa_error_report snmpa_get_mechanism snmpa_mib_storage snmpa_mib_data
        snmpa_network_interface snmpa_network_interface_filter
        snmpa_notification_delivery_info_receiver snmpa_notification_filter snmpa_set_mechanism)
    list(APPEND _snmp_first "${_source}/agent/${_module}.erl")
endforeach()
foreach(_module IN ITEMS snmpm_user snmpm_user_old snmpm_network_interface snmpm_network_interface_filter)
    list(APPEND _snmp_first "${_source}/manager/${_module}.erl")
endforeach()
list(REMOVE_ITEM _sources ${_snmp_first})
list(PREPEND _sources ${_snmp_first})
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_source}/compile/snmpc.src")
file(READ "${_source}/compile/snmpc.src" _snmp_command)
string(REPLACE "%VSN%" "${_version}" _snmp_command "${_snmp_command}")
file(CONFIGURE OUTPUT "${_generated}/snmpc" CONTENT "${_snmp_command}" @ONLY)
install(PROGRAMS "${_generated}/snmpc" DESTINATION "lib/snmp-${_version}/bin")
install(FILES "${_snmp_parser}" DESTINATION "lib/snmp-${_version}/src/compiler")
install(FILES "${_generated}/snmp_pdus_basic.erl" DESTINATION "lib/snmp-${_version}/src/misc")
install(FILES ${_snmp_schemas} "${_snmp_schema_dir}/SNMPv2-SMI.mib"
    "${_snmp_schema_dir}/SNMPv2-TC.mib" "${_snmp_schema_dir}/SNMPv2-CONF.mib"
    DESTINATION "lib/snmp-${_version}/mibs")
foreach(_mib IN ITEMS RFC1155-SMI RFC-1212 RFC-1215)
    install(FILES "${_snmp_schema_dir}/${_mib}.mib" DESTINATION "lib/snmp-${_version}/mibs/v1")
endforeach()
find_program(OTP_SED_EXECUTABLE sed REQUIRED)
set(_snmp_v1 "${_generated}/OTP-SNMPEA-MIB.mib.v1")
add_custom_command(OUTPUT "${_snmp_v1}"
    COMMAND "${CMAKE_COMMAND}" "-DPERL=${PERL_EXECUTABLE}" "-DSED=${OTP_SED_EXECUTABLE}"
        "-DTOOLS=${PROJECT_SOURCE_DIR}/lib/snmp/bin" "-DINPUT=${_snmp_schema_dir}/OTP-SNMPEA-MIB.mib"
        "-DOUTPUT=${_snmp_v1}" -P "${PROJECT_SOURCE_DIR}/cmake/ConvertSNMPMib.cmake"
    DEPENDS "${_snmp_schema_dir}/OTP-SNMPEA-MIB.mib"
        "${PROJECT_SOURCE_DIR}/lib/snmp/bin/snmp-v2tov1.pl"
        "${PROJECT_SOURCE_DIR}/lib/snmp/bin/snmp-v2tov1.sed"
        "${PROJECT_SOURCE_DIR}/cmake/ConvertSNMPMib.cmake"
    COMMENT "Generating the retained SNMPv1 example MIB" VERBATIM)
list(APPEND _extra_dependencies "${_snmp_v1}")
install(FILES "${_snmp_v1}" DESTINATION "lib/snmp-${_version}/mibs/v1")
install(DIRECTORY "${PROJECT_SOURCE_DIR}/lib/snmp/priv/conf/" DESTINATION "lib/snmp-${_version}/priv/conf" PATTERN "manager/usm.conf" EXCLUDE)

# Upstream ships these four instrumentation callback maps with its MIB sources.
foreach(_mib IN ITEMS SNMP-NOTIFICATION-MIB SNMP-TARGET-MIB SNMPv2-MIB STANDARD-MIB)
    install(FILES "${_snmp_schema_dir}/${_mib}.funcs" DESTINATION "lib/snmp-${_version}/mibs")
endforeach()
