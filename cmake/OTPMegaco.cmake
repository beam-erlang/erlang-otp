# Megaco owns its protocol generators and ordinary public-API scanner drivers.
set(_resources "${_source}/app")
set(_sources)
foreach(_part IN ITEMS app engine text flex binary tcp udp)
    file(GLOB _part_sources CONFIGURE_DEPENDS "${_source}/${_part}/*.erl")
    list(APPEND _sources ${_part_sources})
    install(DIRECTORY "${_source}/${_part}/" DESTINATION "lib/megaco-${_version}/src/${_part}"
        FILES_MATCHING PATTERN "*.erl" PATTERN "*.hrl" PATTERN "*.yrl"
        PATTERN "*.asn" PATTERN "*.set.asn" EXCLUDE)
endforeach()
set(_megaco_first)
foreach(_module IN ITEMS megaco_edist_compress megaco_encoder megaco_user megaco_transport)
    list(APPEND _megaco_first "${_source}/engine/${_module}.erl")
endforeach()
list(REMOVE_ITEM _sources ${_megaco_first})
list(PREPEND _sources ${_megaco_first})
foreach(_parser IN ITEMS megaco_text_parser_v1 megaco_text_parser_v2 megaco_text_parser_v3 megaco_text_mini_parser)
    set(_output "${_generated}/${_parser}.erl")
    add_custom_command(OUTPUT "${_output}"
        COMMAND ${OTP_BUILD_COMMAND}
            parser "${PROJECT_SOURCE_DIR}" "${_otp_tools}"
            "${_source}/text/${_parser}.yrl" "${_output}" "${OTP_BUILD_ROOT}"
        DEPENDS "${_source}/text/${_parser}.yrl" ${_tool_outputs} "${_otp_driver}" otp_build_host
        COMMENT "Generating ${_parser}" VERBATIM)
    list(APPEND _sources "${_output}")
    install(FILES "${_output}" DESTINATION "lib/megaco-${_version}/src/text")
endforeach()
set(_megaco_codecs)
set(_megaco_generated)
foreach(_rule IN ITEMS ber per)
    foreach(_protocol IN ITEMS 1 2 3)
        set(_module "megaco_${_rule}_media_gateway_control_v${_protocol}")
        list(APPEND _megaco_codecs "${_module}")
        list(APPEND _sources "${_generated}/${_module}.erl")
        list(APPEND _megaco_generated "${_generated}/${_module}.erl" "${_generated}/${_module}.hrl")
    endforeach()
endforeach()
file(GLOB _megaco_schemas CONFIGURE_DEPENDS "${_source}/binary/*.asn" "${_source}/binary/*.asn1config")
otp_application_version(asn1 _asn1_version)
add_custom_command(OUTPUT ${_megaco_generated}
    COMMAND ${OTP_BUILD_COMMAND}
        megaco "${_source}/binary" "${_generated}"
        "${PROJECT_BINARY_DIR}/otp/lib/asn1-${_asn1_version}/ebin" "${OTP_BUILD_ROOT}" ${_megaco_codecs}
    DEPENDS ${_megaco_schemas} ${_otp_asn1_outputs} "${_otp_driver}" otp_build_host
    COMMENT "Generating Megaco BER/PER codecs for protocol versions 1, 2 and 3" VERBATIM)
list(APPEND _extra_dependencies ${_megaco_generated})
install(FILES ${_megaco_generated} DESTINATION "lib/megaco-${_version}/src/binary")

find_package(FLEX 2.6 REQUIRED)
execute_process(COMMAND "${FLEX_EXECUTABLE}" --version OUTPUT_VARIABLE _megaco_flex_version
    OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
set(_megaco_flex_template "${_source}/flex/megaco_flex_scanner_drv.flex.src")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_megaco_flex_template}")
file(READ "${_megaco_flex_template}" _megaco_flex)
string(REPLACE "%FLEX_VERSION%" "${_megaco_flex_version}" _megaco_flex "${_megaco_flex}")
string(REPLACE "%MEGACO_YY_LINENO_OPTION%" "%option yylineno" _megaco_flex "${_megaco_flex}")
string(REPLACE "%MEGACO_DUMMY_DECL_YY_LINENO%" "/* static int yylineno = 1; */" _megaco_flex "${_megaco_flex}")
foreach(_variant IN ITEMS standard reentrant)
    set(_name megaco_flex_scanner_drv)
    set(_flags -Ca)
    if(WIN32)
        list(APPEND _flags --wincompat)
    endif()
    if(_variant STREQUAL reentrant)
        string(APPEND _name _mt)
        set(_reentrant "%option reentrant")
        list(APPEND _flags -R --yylineno)
    else()
        set(_reentrant "/* %option reentrant */")
    endif()
    string(REPLACE "%MEGACO_YY_REENTRANT_OPTION%" "${_reentrant}" _flex "${_megaco_flex}")
    file(CONFIGURE OUTPUT "${_generated}/${_name}.flex" CONTENT "${_flex}" @ONLY)
    add_custom_command(OUTPUT "${_generated}/${_name}.c"
        COMMAND "${FLEX_EXECUTABLE}" ${_flags} "-P${_name}" "-o${_generated}/${_name}.c"
            "${_generated}/${_name}.flex"
        DEPENDS "${_generated}/${_name}.flex" "${FLEX_EXECUTABLE}"
        COMMENT "Generating the ${_variant} Megaco scanner" VERBATIM)
    add_library(otp_${_name} MODULE "${_generated}/${_name}.c")
    target_link_libraries(otp_${_name} PRIVATE BEAM::Driver)
    target_compile_definitions(otp_${_name} PRIVATE "MEGACO_DRV_NAME=\"${_name}\"" MEGACO_LINENO MFS_FLEX_DEBUG=0)
    if(_variant STREQUAL reentrant)
        target_compile_definitions(otp_${_name} PRIVATE MEGACO_REENTRANT_FLEX_SCANNER)
    endif()
    set_target_properties(otp_${_name} PROPERTIES PREFIX "" OUTPUT_NAME "${_name}"
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/lib/megaco-${_version}/priv/lib")
    install(TARGETS otp_${_name}
        LIBRARY DESTINATION "lib/megaco-${_version}/priv/lib"
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        RUNTIME DESTINATION "lib/megaco-${_version}/priv/lib"
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    install(FILES "${_generated}/${_name}.flex" "${_generated}/${_name}.c"
        DESTINATION "lib/megaco-${_version}/src/flex")
endforeach()
