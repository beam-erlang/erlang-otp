# xmerl application sources, generation and release rules.
otp_application_version(xmerl _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_b64Bin_scan.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_eventp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_html.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_otpsgml.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_old_dom.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_simple_dom.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_scan.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sgml.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_simple.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_text.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_ucs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_uri.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_validate.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xlate.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xml.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xml_indent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xpath.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xpath_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xpath_pred.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xpath_scan.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xsd.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xsd_re.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xsd_type.erl"
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_xpath_parse.erl"
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_b64Bin.erl"
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_xsd_re_parse.erl"
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_list.erl"
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_latin1.erl"
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf8.erl"
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf16be.erl"
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf16le.erl"
)

get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xpath_parse.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_xpath_parse.erl"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xpath_parse.yrl")
otp_generator(TARGET otp_generate_xmerl_xpath_parse
    COMMANDS ${_parser_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_xpath_parse.erl"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xpath_parse.yrl"
        otp_bootstrap_parsetools ${_parser_command_INPUTS}
)
get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_b64Bin.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_b64Bin.erl"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_b64Bin.yrl")
otp_generator(TARGET otp_generate_xmerl_b64Bin
    COMMANDS ${_parser_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_b64Bin.erl"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_b64Bin.yrl"
        otp_bootstrap_parsetools ${_parser_command_INPUTS}
)
get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xsd_re_parse.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_xsd_re_parse.erl"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xsd_re_parse.yrl")
otp_generator(TARGET otp_generate_xmerl_xsd_re_parse
    COMMANDS ${_parser_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_xsd_re_parse.erl"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xsd_re_parse.yrl"
        otp_bootstrap_parsetools ${_parser_command_INPUTS}
)
otp_cmake_literal(_concat_directory "${OTP_GENERATED_ROOT}/xmerl/src")
otp_cmake_literal(_concat_output "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_list.erl")
otp_cmake_literal(_concat_first "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_list.erlsrc")
otp_cmake_literal(_concat_second "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc")
set(_concat_script "${OTP_INTERNAL_ROOT}/xmerl/xmerl_sax_parser_list.cmake")
file(GENERATE OUTPUT "${_concat_script}" CONTENT
    "file(MAKE_DIRECTORY ${_concat_directory})\nfile(READ ${_concat_first} _content)\nfile(WRITE ${_concat_output} \"\${_content}\")\nfile(READ ${_concat_second} _content)\nfile(APPEND ${_concat_output} \"\${_content}\")\n")
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_list.erl"
    COMMAND "${CMAKE_COMMAND}" -P "${_concat_script}"
    DEPENDS
        "${_concat_script}"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_list.erlsrc"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc"
    VERBATIM
)
add_custom_target(otp_xmerl_sax_list DEPENDS
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_list.erl"
)
otp_cmake_literal(_concat_directory "${OTP_GENERATED_ROOT}/xmerl/src")
otp_cmake_literal(_concat_output "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_latin1.erl")
otp_cmake_literal(_concat_first "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_latin1.erlsrc")
otp_cmake_literal(_concat_second "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc")
set(_concat_script "${OTP_INTERNAL_ROOT}/xmerl/xmerl_sax_parser_latin1.cmake")
file(GENERATE OUTPUT "${_concat_script}" CONTENT
    "file(MAKE_DIRECTORY ${_concat_directory})\nfile(READ ${_concat_first} _content)\nfile(WRITE ${_concat_output} \"\${_content}\")\nfile(READ ${_concat_second} _content)\nfile(APPEND ${_concat_output} \"\${_content}\")\n")
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_latin1.erl"
    COMMAND "${CMAKE_COMMAND}" -P "${_concat_script}"
    DEPENDS
        "${_concat_script}"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_latin1.erlsrc"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc"
    VERBATIM
)
add_custom_target(otp_xmerl_sax_latin1 DEPENDS
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_latin1.erl"
)
otp_cmake_literal(_concat_directory "${OTP_GENERATED_ROOT}/xmerl/src")
otp_cmake_literal(_concat_output "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf8.erl")
otp_cmake_literal(_concat_first "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_utf8.erlsrc")
otp_cmake_literal(_concat_second "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc")
set(_concat_script "${OTP_INTERNAL_ROOT}/xmerl/xmerl_sax_parser_utf8.cmake")
file(GENERATE OUTPUT "${_concat_script}" CONTENT
    "file(MAKE_DIRECTORY ${_concat_directory})\nfile(READ ${_concat_first} _content)\nfile(WRITE ${_concat_output} \"\${_content}\")\nfile(READ ${_concat_second} _content)\nfile(APPEND ${_concat_output} \"\${_content}\")\n")
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf8.erl"
    COMMAND "${CMAKE_COMMAND}" -P "${_concat_script}"
    DEPENDS
        "${_concat_script}"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_utf8.erlsrc"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc"
    VERBATIM
)
add_custom_target(otp_xmerl_sax_utf8 DEPENDS
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf8.erl"
)
otp_cmake_literal(_concat_directory "${OTP_GENERATED_ROOT}/xmerl/src")
otp_cmake_literal(_concat_output "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf16be.erl")
otp_cmake_literal(_concat_first "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_utf16be.erlsrc")
otp_cmake_literal(_concat_second "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc")
set(_concat_script "${OTP_INTERNAL_ROOT}/xmerl/xmerl_sax_parser_utf16be.cmake")
file(GENERATE OUTPUT "${_concat_script}" CONTENT
    "file(MAKE_DIRECTORY ${_concat_directory})\nfile(READ ${_concat_first} _content)\nfile(WRITE ${_concat_output} \"\${_content}\")\nfile(READ ${_concat_second} _content)\nfile(APPEND ${_concat_output} \"\${_content}\")\n")
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf16be.erl"
    COMMAND "${CMAKE_COMMAND}" -P "${_concat_script}"
    DEPENDS
        "${_concat_script}"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_utf16be.erlsrc"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc"
    VERBATIM
)
add_custom_target(otp_xmerl_sax_utf16be DEPENDS
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf16be.erl"
)
otp_cmake_literal(_concat_directory "${OTP_GENERATED_ROOT}/xmerl/src")
otp_cmake_literal(_concat_output "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf16le.erl")
otp_cmake_literal(_concat_first "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_utf16le.erlsrc")
otp_cmake_literal(_concat_second "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc")
set(_concat_script "${OTP_INTERNAL_ROOT}/xmerl/xmerl_sax_parser_utf16le.cmake")
file(GENERATE OUTPUT "${_concat_script}" CONTENT
    "file(MAKE_DIRECTORY ${_concat_directory})\nfile(READ ${_concat_first} _content)\nfile(WRITE ${_concat_output} \"\${_content}\")\nfile(READ ${_concat_second} _content)\nfile(APPEND ${_concat_output} \"\${_content}\")\n")
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf16le.erl"
    COMMAND "${CMAKE_COMMAND}" -P "${_concat_script}"
    DEPENDS
        "${_concat_script}"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_utf16le.erlsrc"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser_base.erlsrc"
    VERBATIM
)
add_custom_target(otp_xmerl_sax_utf16le DEPENDS
    "${OTP_GENERATED_ROOT}/xmerl/src/xmerl_sax_parser_utf16le.erl"
)

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP xmerl
    SOURCES ${_sources}
    OPTIONS warn_unused_vars warn_obsolete_bool_op
    DEPENDS otp_generate_xmerl_xpath_parse otp_generate_xmerl_b64Bin otp_generate_xmerl_xsd_re_parse otp_xmerl_sax_list otp_xmerl_sax_latin1 otp_xmerl_sax_utf8 otp_xmerl_sax_utf16be otp_xmerl_sax_utf16le
    INPUTS ${_headers}
    NO_SOURCE_SUPPORT_INSTALL
)
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl.app.src"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl.appup.src"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_internal.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_old_dom.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_sax_parser.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_xpath_parse.yrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xmerl_b64Bin.yrl"
    DESTINATION "lib/xmerl-${_version}/src")
