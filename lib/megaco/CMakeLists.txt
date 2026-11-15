# Megaco owns its parsers, BER/PER codecs and both public-interface scanner drivers.

otp_application_version(megaco _version)
set(_megaco_debug_options)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(_megaco_debug_options "{d,debug}")
endif()
set(_generated "${OTP_GENERATED_ROOT}/megaco/src")
set(_parser_targets)
set(_parser_names megaco_text_parser_v1 megaco_text_parser_v2 megaco_text_parser_v3 megaco_text_mini_parser)
foreach(_parser IN LISTS _parser_names)
    get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/text/${_parser}.yrl" DIRECTORY)
    otp_erlc_command(_parser_command "${_parser_source_dir}" "${_generated}/text/${_parser}.erl"
        SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/${_parser}.yrl")
    otp_generator(TARGET otp_megaco_${_parser}
        COMMANDS ${_parser_command}
        OUTPUTS "${_generated}/text/${_parser}.erl"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/text/${_parser}.yrl" otp_bootstrap_parsetools ${_parser_command_INPUTS}
    )
    list(APPEND _parser_targets otp_megaco_${_parser})
endforeach()
set(_asn1_targets)
set(_asn1_headers)
foreach(_schema_version RANGE 1 3)
    foreach(_encoding ber per)
        set(_module "megaco_${_encoding}_media_gateway_control_v${_schema_version}")
        set(_schema "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/${_module}.set.asn")
        set(_asn1_options +noobj +legacy_erlang_types)
        set(_asn1_inputs "${_schema}"
            "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/MEDIA-GATEWAY-CONTROL-v${_schema_version}.asn")
        if(_encoding STREQUAL ber)
            list(APPEND _asn1_options +asn1config)
            list(APPEND _asn1_inputs "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/${_module}.asn1config")
        endif()
        # Select the frontend encoding explicitly: +per alone would coexist
        # with erl_compile's default ber option, which ASN.1 prefers.
        otp_command(_asn1_command "${CMAKE_CURRENT_SOURCE_DIR}/src/binary"
            "${OTP_BOOTSTRAP_ROOT}/bin/erlc" -no-server "-b${_encoding}"
            -o "${_generated}/binary" ${_asn1_options} "${_schema}")
        otp_generator(TARGET otp_megaco_${_module}
            COMMANDS ${_asn1_command}
            OUTPUTS "${_generated}/binary/${_module}.erl" "${_generated}/binary/${_module}.hrl"
                "${_generated}/binary/${_module}.asn1db"
            DEPENDS ${_asn1_inputs} otp_bootstrap_asn1 ${_asn1_command_INPUTS}
        )
        list(APPEND _asn1_targets otp_megaco_${_module})
        list(APPEND _asn1_headers "${_generated}/binary/${_module}.hrl")
    endforeach()
endforeach()

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/app/megaco.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_edist_compress.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_encoder.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_user.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_transport.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_config_misc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_digit_map.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_erl_dist_encoder.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_erl_dist_encoder_mc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_filter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_messenger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_messenger_misc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_misc_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_monitor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_sdp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_stats.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_timer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_trans_sender.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_trans_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_user_default.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_compact_text_encoder.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_compact_text_encoder_v1.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_compact_text_encoder_v2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_compact_text_encoder_v3.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_pretty_text_encoder.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_pretty_text_encoder_v1.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_pretty_text_encoder_v2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_pretty_text_encoder_v3.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_mini_decoder.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_scanner.erl"
    "${_generated}/text/megaco_text_parser_v1.erl"
    "${_generated}/text/megaco_text_parser_v2.erl"
    "${_generated}/text/megaco_text_parser_v3.erl"
    "${_generated}/text/megaco_text_mini_parser.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/flex/megaco_flex_scanner.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/flex/megaco_flex_scanner_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_encoder.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_encoder_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_ber_encoder.erl"
    "${_generated}/binary/megaco_ber_media_gateway_control_v1.erl"
    "${_generated}/binary/megaco_ber_media_gateway_control_v2.erl"
    "${_generated}/binary/megaco_ber_media_gateway_control_v3.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_per_encoder.erl"
    "${_generated}/binary/megaco_per_media_gateway_control_v1.erl"
    "${_generated}/binary/megaco_per_media_gateway_control_v2.erl"
    "${_generated}/binary/megaco_per_media_gateway_control_v3.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_name_resolver_v1.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_name_resolver_v2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_name_resolver_v3.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_term_id.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_term_id_gen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_transformer_v1.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_transformer_v2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/megaco_binary_transformer_v3.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tcp/megaco_tcp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tcp/megaco_tcp_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tcp/megaco_tcp_accept.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tcp/megaco_tcp_accept_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tcp/megaco_tcp_connection.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tcp/megaco_tcp_connection_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/udp/megaco_udp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/udp/megaco_udp_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/udp/megaco_udp_server.erl"
)
set_property(SOURCE
    "${CMAKE_CURRENT_SOURCE_DIR}/src/flex/megaco_flex_scanner.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/flex/megaco_flex_scanner_handler.erl"
    PROPERTY OTP_COMPILE_OPTIONS
        "{d,'ENABLE_MEGACO_FLEX_SCANNER',true}"
        "{d,'MEGACO_REENTRANT_FLEX_SCANNER',true}")
foreach(_source IN LISTS _sources)
    if(_source MATCHES "/src/(tcp|udp)/")
        set_property(SOURCE "${_source}" APPEND PROPERTY OTP_COMPILE_OPTIONS nowarn_missing_spec_documented)
    endif()
endforeach()
otp_add_application(APP megaco
    SOURCES ${_sources}
    OPTIONS ${_megaco_debug_options} "{d,megaco_parser_inline}"
        "{parse_transform,sys_pre_attributes}"
        "{attribute,insert,app_vsn,\"megaco-${_version}\"}"
        warn_obsolete_bool_op nowarn_deprecated_catch
        "{i,\"${CMAKE_CURRENT_SOURCE_DIR}/src/app\"}"
        "{i,\"${CMAKE_CURRENT_SOURCE_DIR}/src/engine\"}"
    DEPENDS ${_parser_targets} ${_asn1_targets} otp_app_et
    RESOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/app"
    OWN_CODE_PATH
    PRESERVE_SOURCE_LAYOUT
)

set(FLEX_EXECUTABLE "$ENV{FLEX_EXECUTABLE}" CACHE FILEPATH "Explicit installed flex executable")
if(NOT IS_ABSOLUTE "${FLEX_EXECUTABLE}" OR NOT EXISTS "${FLEX_EXECUTABLE}" OR IS_DIRECTORY "${FLEX_EXECUTABLE}")
    message(FATAL_ERROR "Set FLEX_EXECUTABLE to an explicit absolute installed flex executable")
endif()
execute_process(COMMAND "${FLEX_EXECUTABLE}" --version
    RESULT_VARIABLE _flex_status OUTPUT_VARIABLE _flex_version ERROR_VARIABLE _flex_error
    OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT _flex_status EQUAL 0)
    message(FATAL_ERROR "Selected flex failed: ${_flex_error}")
endif()
set(_scanner_template "${CMAKE_CURRENT_SOURCE_DIR}/src/flex/megaco_flex_scanner_drv.flex.src")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${FLEX_EXECUTABLE}" "${_scanner_template}")
file(READ "${_scanner_template}" _scanner_contents)
foreach(_kind standard reentrant)
    set(_driver megaco_flex_scanner_drv)
    set(_reentrant "/* %option reentrant */")
    set(_flex_flags -Ca)
    if(_kind STREQUAL reentrant)
        set(_driver megaco_flex_scanner_drv_mt)
        set(_reentrant "%option reentrant")
        list(APPEND _flex_flags -R --yylineno)
    endif()
    set(_spec "${OTP_GENERATED_ROOT}/megaco/src/flex/${_driver}.flex")
    set(_scanner "${OTP_GENERATED_ROOT}/megaco/src/flex/${_driver}.c")
    set(_contents "${_scanner_contents}")
    string(REPLACE "%FLEX_VERSION%" "${_flex_version}" _contents "${_contents}")
    string(REPLACE "%MEGACO_YY_LINENO_OPTION%" "%option yylineno" _contents "${_contents}")
    string(REPLACE "%MEGACO_YY_REENTRANT_OPTION%" "${_reentrant}" _contents "${_contents}")
    string(REPLACE "%MEGACO_DUMMY_DECL_YY_LINENO%" "/* static int yylineno = 1; */" _contents "${_contents}")
    file(CONFIGURE OUTPUT "${_spec}" CONTENT "${_contents}" @ONLY)
    add_custom_command(OUTPUT "${_scanner}"
        COMMAND "${FLEX_EXECUTABLE}" ${_flex_flags} "-P${_driver}" "-o${_scanner}" "${_spec}"
        DEPENDS "${_spec}" "${FLEX_EXECUTABLE}"
        VERBATIM
    )
    add_library(otp_${_driver} MODULE "${_scanner}")
    target_compile_definitions(otp_${_driver} PRIVATE
        MEGACO_LINENO MFS_FLEX_DEBUG=0 "MEGACO_DRV_NAME=\"${_driver}\"")
    if(_kind STREQUAL reentrant)
        target_compile_definitions(otp_${_driver} PRIVATE MEGACO_REENTRANT_FLEX_SCANNER)
    endif()
    if(MSVC)
        target_compile_definitions(otp_${_driver} PRIVATE YY_NO_UNISTD_H __WIN32__)
        target_compile_options(otp_${_driver} PRIVATE /W3)
    else()
        target_compile_options(otp_${_driver} PRIVATE -funroll-loops -Wall)
    endif()
    target_link_libraries(otp_${_driver} PRIVATE BEAM::Driver otp_native_config)
    otp_linux_native_flags(otp_${_driver} DED)
    if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
        target_compile_options(otp_${_driver} PRIVATE -g -O2)
        if(_kind STREQUAL reentrant)
            target_compile_definitions(otp_${_driver} PRIVATE
                _THREAD_SAFE _REENTRANT POSIX_THREADS _POSIX_THREAD_SAFE_FUNCTIONS)
        endif()
    endif()
    set_target_properties(otp_${_driver} PROPERTIES
        PREFIX "" OUTPUT_NAME "${_driver}"
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/megaco/priv/lib/${OTP_TARGET}"
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/megaco/priv/lib/${OTP_TARGET}")
    install(TARGETS otp_${_driver} LIBRARY DESTINATION "lib/megaco-${_version}/priv/lib"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        RUNTIME DESTINATION "lib/megaco-${_version}/priv/lib")
    install(FILES "${_spec}" "${_scanner}" DESTINATION "lib/megaco-${_version}/src/flex")
endforeach()
install(FILES ${_asn1_headers} DESTINATION "lib/megaco-${_version}/src/binary")
install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/MEDIA-GATEWAY-CONTROL-v1.asn"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/MEDIA-GATEWAY-CONTROL-v2.asn"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/binary/MEDIA-GATEWAY-CONTROL-v3.asn"
    DESTINATION "lib/megaco-${_version}/src/binary")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/app/megaco_internal.hrl"
    DESTINATION "lib/megaco-${_version}/src/app")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/megaco_message_internal.hrl"
    DESTINATION "lib/megaco-${_version}/src/engine")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_gen_v1.hrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_gen_v2.hrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_gen_v3.hrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_parser_v1.hrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_parser_v2.hrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_parser_v3.hrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_mini_parser.hrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_tokens.hrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/tcp/megaco_tcp.hrl"
    DESTINATION "lib/megaco-${_version}/src/tcp")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/udp/megaco_udp.hrl"
    DESTINATION "lib/megaco-${_version}/src/udp")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_parser_v1.yrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_parser_v2.yrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_parser_v3.yrl"
    DESTINATION "lib/megaco-${_version}/src/text")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/text/megaco_text_mini_parser.yrl"
    DESTINATION "lib/megaco-${_version}/src/text")
