# Public Key owns its schemas and generator policy; ASN.1 is source-built above.
set(_pk_asn1 "${PROJECT_SOURCE_DIR}/lib/public_key/asn1")
set(_pk_generated "${PROJECT_BINARY_DIR}/generated/public_key")
set(_pk_modules PKCS-FRAME AlgorithmInformation-2009 AttributeCertificateVersion1-2009
    CryptographicMessageSyntax-2009 CryptographicMessageSyntaxAlgorithms-2009
    CMSAesRsaesOaep-2009 DSS ECPrivateKey KEMAlgorithmInformation-2023
    X509-ML-DSA-2025 X509-ML-KEM-2025 SLH-DSA-Module-2024 OCSP-2024-08
    OTP-PKIX OTP-PKIX-Relaxed PKCS-1 PKCS-3 PKCS-10 PKIX-CommonTypes-2009
    PKIX-X400Address-2009 PKIX1-PSS-OAEP-Algorithms-2009 PKIX1Explicit-2009
    PKIX1Implicit-2009 PKIXAlgs-2009 PKIXCMP-2023 PKIXCRMF-2009
    EnrollmentMessageSyntax-2009 PKIXAttributeCertificate-2009 RFC5639
    Safecurves-pkix-18 SecureMimeMessageV3dot1-2009)
file(GLOB _pk_inputs CONFIGURE_DEPENDS "${_pk_asn1}/*.asn1"
    "${_pk_asn1}/*.asn1config" "${_pk_asn1}/*.set.asn")
set(_pk_outputs)
foreach(_module IN LISTS _pk_modules)
    list(APPEND _pk_outputs "${_pk_generated}/${_module}.erl")
    # This information-object schema declares no record/value header output.
    if(NOT _module STREQUAL KEMAlgorithmInformation-2023)
        list(APPEND _pk_outputs "${_pk_generated}/${_module}.hrl")
    endif()
    list(APPEND _sources "${_pk_generated}/${_module}.erl")
endforeach()
otp_application_version(asn1 _asn1_version)
add_custom_command(OUTPUT ${_pk_outputs}
    COMMAND ${OTP_BUILD_COMMAND}
        public-key "${_pk_asn1}" "${_pk_generated}"
        "${PROJECT_BINARY_DIR}/otp/lib/asn1-${_asn1_version}/ebin" "${OTP_BUILD_ROOT}" ${_pk_modules}
    DEPENDS ${_pk_inputs} ${_otp_asn1_outputs} "${_otp_driver}" otp_build_host
    COMMENT "Generating Public Key sources from retained ASN.1 schemas" VERBATIM)
add_custom_command(OUTPUT "${_pk_generated}/pubkey_moduli.hrl"
    COMMAND ${OTP_BUILD_COMMAND}
        script "${PROJECT_SOURCE_DIR}/lib/public_key/priv/convert.escript" "${OTP_BUILD_ROOT}"
        "${PROJECT_SOURCE_DIR}/lib/public_key/priv/moduli" "${_pk_generated}/pubkey_moduli.hrl"
    DEPENDS "${PROJECT_SOURCE_DIR}/lib/public_key/priv/convert.escript"
        "${PROJECT_SOURCE_DIR}/lib/public_key/priv/moduli" "${_otp_driver}" otp_build_host
    COMMENT "Generating Public Key Diffie-Hellman group constants" VERBATIM)
# Erlang searches beside a source file before -I directories. A byte-identical
# build copy ensures this module consumes the newly generated moduli header.
configure_file("${_source}/pubkey_ssh.erl" "${_pk_generated}/pubkey_ssh.erl" COPYONLY)
list(REMOVE_ITEM _sources "${_source}/pubkey_ssh.erl")
list(APPEND _sources "${_pk_generated}/pubkey_ssh.erl")
set(_pk_public_header "${PROJECT_BINARY_DIR}/otp/lib/public_key-${_version}/include/PKCS-FRAME.hrl")
add_custom_command(OUTPUT "${_pk_public_header}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${_pk_generated}/PKCS-FRAME.hrl" "${_pk_public_header}"
    DEPENDS "${_pk_generated}/PKCS-FRAME.hrl" VERBATIM)
list(APPEND _extra_dependencies ${_pk_outputs} "${_pk_generated}/pubkey_moduli.hrl" "${_pk_public_header}")
install(FILES "${_pk_generated}/PKCS-FRAME.hrl" DESTINATION "lib/public_key-${_version}/include")
set(_pk_installed_schemas ${_pk_inputs})
list(REMOVE_ITEM _pk_installed_schemas "${_pk_asn1}/AsymmetricKeyPackageModuleV1.asn1"
    "${_pk_asn1}/PKCS-FRAME.set.asn" "${_pk_asn1}/PKCS5v2-0.asn1")
install(FILES ${_pk_installed_schemas} DESTINATION "lib/public_key-${_version}/asn1")
