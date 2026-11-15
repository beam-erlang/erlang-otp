# public_key application sources, generation and release rules.
otp_application_version(public_key _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_cert.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_cert_records.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_crl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_ocsp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_os_cacerts.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_pbe.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_pem.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_policy_tree.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_translation.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/public_key.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKCS-FRAME.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/AlgorithmInformation-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/AttributeCertificateVersion1-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/CryptographicMessageSyntax-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/CryptographicMessageSyntaxAlgorithms-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/CMSAesRsaesOaep-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/DSS.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/ECPrivateKey.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/KEMAlgorithmInformation-2023.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/X509-ML-DSA-2025.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/X509-ML-KEM-2025.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/SLH-DSA-Module-2024.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/OCSP-2024-08.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/OTP-PKIX.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/OTP-PKIX-Relaxed.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKCS-1.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKCS-3.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKCS-10.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIX-CommonTypes-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIX-X400Address-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIX1-PSS-OAEP-Algorithms-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIX1Explicit-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIX1Implicit-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIXAlgs-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIXCMP-2023.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIXCRMF-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/EnrollmentMessageSyntax-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/PKIXAttributeCertificate-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/RFC5639.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/Safecurves-pkix-18.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/SecureMimeMessageV3dot1-2009.erl"
    "${OTP_GENERATED_ROOT}/public_key/src/pubkey_ssh.erl"
)

file(GLOB _asn1_inputs CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/asn1/*")
set(_asn1_schemas
    "PKCS-FRAME.set.asn"
    "AlgorithmInformation-2009.asn1"
    "AttributeCertificateVersion1-2009.asn1"
    "CryptographicMessageSyntax-2009.asn1"
    "CryptographicMessageSyntaxAlgorithms-2009.asn1"
    "CMSAesRsaesOaep-2009.asn1"
    "DSS.asn1"
    "ECPrivateKey.asn1"
    "KEMAlgorithmInformation-2023.asn1"
    "X509-ML-DSA-2025.asn1"
    "X509-ML-KEM-2025.asn1"
    "SLH-DSA-Module-2024.asn1"
    "OCSP-2024-08.asn1"
    "OTP-PKIX.asn1"
    "OTP-PKIX-Relaxed.asn1"
    "PKCS-1.asn1"
    "PKCS-3.asn1"
    "PKCS-10.asn1"
    "PKIX-CommonTypes-2009.asn1"
    "PKIX-X400Address-2009.asn1"
    "PKIX1-PSS-OAEP-Algorithms-2009.asn1"
    "PKIX1Explicit-2009.asn1"
    "PKIX1Implicit-2009.asn1"
    "PKIXAlgs-2009.asn1"
    "PKIXCMP-2023.asn1"
    "PKIXCRMF-2009.asn1"
    "EnrollmentMessageSyntax-2009.asn1"
    "PKIXAttributeCertificate-2009.asn1"
    "RFC5639.asn1"
    "Safecurves-pkix-18.asn1"
    "SecureMimeMessageV3dot1-2009.asn1"
)
set(_schema_commands)
set(_schema_inputs)
foreach(_schema IN LISTS _asn1_schemas)
    otp_erlc_command(_schema_command "${CMAKE_CURRENT_SOURCE_DIR}/asn1"
        "${OTP_GENERATED_ROOT}/public_key/src"
        FLAGS -bber OPTIONS der noobj asn1config SOURCES "${_schema}")
    list(APPEND _schema_commands ${_schema_command})
    list(APPEND _schema_inputs ${_schema_command_INPUTS})
endforeach()
otp_generator(
    TARGET otp_public_key_schemas
    COMMANDS ${_schema_commands}
    OUTPUTS
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-FRAME.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/AlgorithmInformation-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/AttributeCertificateVersion1-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/CryptographicMessageSyntax-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/CryptographicMessageSyntaxAlgorithms-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/CMSAesRsaesOaep-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/DSS.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/ECPrivateKey.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/KEMAlgorithmInformation-2023.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/X509-ML-DSA-2025.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/X509-ML-KEM-2025.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/SLH-DSA-Module-2024.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/OCSP-2024-08.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/OTP-PKIX.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/OTP-PKIX-Relaxed.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-1.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-3.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-10.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX-CommonTypes-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX-X400Address-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX1-PSS-OAEP-Algorithms-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX1Explicit-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX1Implicit-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIXAlgs-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIXCMP-2023.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIXCRMF-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/EnrollmentMessageSyntax-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIXAttributeCertificate-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/RFC5639.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/Safecurves-pkix-18.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/SecureMimeMessageV3dot1-2009.erl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-FRAME.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/AlgorithmInformation-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/AttributeCertificateVersion1-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/CryptographicMessageSyntax-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/CryptographicMessageSyntaxAlgorithms-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/CMSAesRsaesOaep-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/DSS.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/ECPrivateKey.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/X509-ML-DSA-2025.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/X509-ML-KEM-2025.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/SLH-DSA-Module-2024.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/OCSP-2024-08.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/OTP-PKIX.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/OTP-PKIX-Relaxed.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-1.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-3.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-10.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX-CommonTypes-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX-X400Address-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX1-PSS-OAEP-Algorithms-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX1Explicit-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIX1Implicit-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIXAlgs-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIXCMP-2023.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIXCRMF-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/EnrollmentMessageSyntax-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/PKIXAttributeCertificate-2009.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/RFC5639.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/Safecurves-pkix-18.hrl"
        "${OTP_GENERATED_ROOT}/public_key/src/SecureMimeMessageV3dot1-2009.hrl"
    DEPENDS ${_schema_inputs}
        otp_bootstrap_asn1
        "${_asn1_inputs}"
)
otp_command(_moduli_command "${CMAKE_CURRENT_SOURCE_DIR}/priv"
    "${OTP_BOOTSTRAP_ROOT}/bin/escript" "${CMAKE_CURRENT_SOURCE_DIR}/priv/convert.escript"
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/moduli" "${OTP_GENERATED_ROOT}/public_key/src/pubkey_moduli.hrl")
otp_generator(
    TARGET otp_public_key_moduli
    COMMANDS ${_moduli_command}
    OUTPUTS
        "${OTP_GENERATED_ROOT}/public_key/src/pubkey_moduli.hrl"
    DEPENDS ${_moduli_command_INPUTS}
        "${CMAKE_CURRENT_SOURCE_DIR}/priv/convert.escript"
        "${CMAKE_CURRENT_SOURCE_DIR}/priv/moduli"
)
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/public_key/src/pubkey_ssh.erl"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_GENERATED_ROOT}/public_key/src"
    COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_ssh.erl" "${OTP_GENERATED_ROOT}/public_key/src/pubkey_ssh.erl"
    DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_ssh.erl"
    VERBATIM
)
add_custom_target(otp_public_key_ssh DEPENDS
    "${OTP_GENERATED_ROOT}/public_key/src/pubkey_ssh.erl"
)
add_custom_command(
    OUTPUT
        "${PROJECT_BINARY_DIR}/lib/public_key/include/PKCS-FRAME.hrl"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${PROJECT_BINARY_DIR}/lib/public_key/include"
    COMMAND "${CMAKE_COMMAND}" -E copy "${OTP_GENERATED_ROOT}/public_key/src/PKCS-FRAME.hrl" "${PROJECT_BINARY_DIR}/lib/public_key/include/PKCS-FRAME.hrl"
    DEPENDS
        "${OTP_GENERATED_ROOT}/public_key/src/PKCS-FRAME.hrl"
        otp_public_key_schemas

    VERBATIM
)
add_custom_target(otp_public_key_frame_header DEPENDS
    "${PROJECT_BINARY_DIR}/lib/public_key/include/PKCS-FRAME.hrl"
)

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_cert.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_cert_records.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_crl.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_ocsp.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_os_cacerts.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_pbe.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_pem.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_policy_tree.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/pubkey_translation.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/public_key.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
set_property(SOURCE "${OTP_GENERATED_ROOT}/public_key/src/pubkey_ssh.erl" PROPERTY OTP_COMPILE_OPTIONS "{parse_transform,sys_pre_attributes}" "{attribute,insert,app_vsn,\"public_key-${_version}\"}")
foreach(_source IN LISTS _sources)
    if(_source MATCHES "/(pubkey_[^/]+|public_key)[.]erl$")
        set_property(SOURCE "${_source}" APPEND PROPERTY OTP_COMPILE_OPTIONS warn_obsolete_bool_op)
    else()
        set_property(SOURCE "${_source}" APPEND PROPERTY OTP_COMPILE_OPTIONS nowarn_deprecated_catch)
    endif()
endforeach()
otp_add_application(
    APP public_key
    SOURCES ${_sources}
    DEPENDS otp_public_key_schemas otp_public_key_moduli otp_public_key_ssh otp_public_key_frame_header
    INPUTS ${_headers} "${OTP_GENERATED_ROOT}/public_key/src/pubkey_moduli.hrl"
)

install(FILES "${OTP_GENERATED_ROOT}/public_key/src/PKCS-FRAME.hrl" DESTINATION "lib/public_key-${_version}/include")
# ASN_ASNS and ASN_CONFIGS in the original release recipe omit the set file
# and its two build-only imported schemas.
set(_release_schemas ${_asn1_schemas})
list(REMOVE_ITEM _release_schemas PKCS-FRAME.set.asn)
list(APPEND _release_schemas OTP-PKIX.asn1config OTP-PKIX-Relaxed.asn1config
    PKIX1Explicit-2009.asn1config)
list(TRANSFORM _release_schemas PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/asn1/")
install(FILES ${_release_schemas} DESTINATION "lib/public_key-${_version}/asn1")
install(FILES "${OTP_GENERATED_ROOT}/public_key/src/pubkey_moduli.hrl"
    DESTINATION "lib/public_key-${_version}/src")

set_property(TARGET otp_app_public_key APPEND PROPERTY OTP_PUBLIC_HEADERS
    "${PROJECT_BINARY_DIR}/lib/public_key/include/PKCS-FRAME.hrl")
