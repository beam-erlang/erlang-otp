# LDAP's BER codec retains legacy Erlang types required by eldap.erl.

otp_application_version(eldap _version)
set(_generated "${OTP_GENERATED_ROOT}/eldap/ebin")
otp_erlc_command(_asn1_command "${CMAKE_CURRENT_SOURCE_DIR}/src" "${_generated}"
    FLAGS -bber -I../include "-I${_generated}"
    OPTIONS legacy_erlang_types warnings_as_errors debug_info
        warn_missing_doc_function warn_missing_doc_callback warn_missing_spec_documented
        warnings_as_errors nowarn_deprecated_catch noobj
    SOURCES ../asn1/ELDAPv3.asn1)
otp_generator(TARGET otp_eldap_asn1
    COMMANDS ${_asn1_command}
    OUTPUTS "${_generated}/ELDAPv3.erl" "${_generated}/ELDAPv3.hrl" "${_generated}/ELDAPv3.asn1db"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/asn1/ELDAPv3.asn1" otp_bootstrap_asn1 ${_asn1_command_INPUTS}
)
set_property(SOURCE "${_generated}/ELDAPv3.erl" PROPERTY OTP_COMPILE_OPTIONS warnings errors legacy_erlang_types)
otp_add_application(APP eldap
    SOURCES "${_generated}/ELDAPv3.erl" "${CMAKE_CURRENT_SOURCE_DIR}/src/eldap.erl"
    OPTIONS warnings_as_errors nowarn_deprecated_catch
    INPUTS "${CMAKE_CURRENT_SOURCE_DIR}/include/eldap.hrl" "${_generated}/ELDAPv3.hrl"
    DEPENDS otp_eldap_asn1 otp_app_ssl
    NO_SOURCE_INSTALL
)
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/eldap.erl" DESTINATION "lib/eldap-${_version}/src")
install(FILES "${_generated}/ELDAPv3.hrl" DESTINATION "lib/eldap-${_version}/ebin")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/asn1/ELDAPv3.asn1" DESTINATION "lib/eldap-${_version}/asn1")
