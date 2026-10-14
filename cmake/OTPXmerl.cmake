# Retained grammars and SAX fragments generate OTP-owned product sources.
set(_xmerl_generated)
foreach(_parser IN ITEMS xmerl_xpath_parse xmerl_b64Bin xmerl_xsd_re_parse)
    set(_input "${_source}/${_parser}.yrl")
    set(_output "${_generated}/${_parser}.erl")
    add_custom_command(OUTPUT "${_output}"
        COMMAND ${OTP_BUILD_COMMAND}
            parser "${PROJECT_SOURCE_DIR}" "${_otp_tools}" "${_input}" "${_output}" "${OTP_BUILD_ROOT}"
        DEPENDS "${_input}" ${_tool_outputs} "${_otp_driver}" otp_build_host
        COMMENT "Generating ${_parser} from the OTP grammar" VERBATIM)
    list(APPEND _xmerl_generated "${_output}")
endforeach()
foreach(_encoding IN ITEMS list latin1 utf8 utf16be utf16le)
    set(_input "${_source}/xmerl_sax_parser_${_encoding}.erlsrc")
    set(_base "${_source}/xmerl_sax_parser_base.erlsrc")
    set(_output "${_generated}/xmerl_sax_parser_${_encoding}.erl")
    add_custom_command(OUTPUT "${_output}"
        COMMAND "${CMAKE_COMMAND}" "-DFIRST=${_input}" "-DSECOND=${_base}" "-DOUTPUT=${_output}"
            -P "${PROJECT_SOURCE_DIR}/cmake/ConcatenateSources.cmake"
        DEPENDS "${_input}" "${_base}" "${PROJECT_SOURCE_DIR}/cmake/ConcatenateSources.cmake"
        COMMENT "Assembling the ${_encoding} SAX parser" VERBATIM)
    list(APPEND _xmerl_generated "${_output}")
endforeach()
list(APPEND _sources ${_xmerl_generated})
install(FILES ${_xmerl_generated} DESTINATION "lib/xmerl-${_version}/src")
