# EDoc parser, documentation generator and runtime assets.

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_cli.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_data.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_doclet.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_doclet_chunks.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_extract.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_layout.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_layout_chunks.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_macros.erl"
    "${OTP_GENERATED_ROOT}/edoc/src/edoc_parser.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_refs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_report.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_run.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_scanner.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_specs.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_tags.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_types.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_wiki.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_html_to_markdown.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_doclet_markdown.erl"
)

set(_generated "${OTP_GENERATED_ROOT}/edoc/src")
get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_parser.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${_generated}/edoc_parser.erl"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_parser.yrl")
otp_generator(TARGET otp_edoc_parser
    COMMANDS ${_parser_command}
    OUTPUTS "${_generated}/edoc_parser.erl"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_parser.yrl" otp_bootstrap_parsetools ${_parser_command_INPUTS}
)
otp_add_application(APP edoc
    NO_SOURCE_SUPPORT_INSTALL
    SOURCES ${_sources}
    OPTIONS warnings_as_errors warn_unused_vars warn_unused_import warn_deprecated_guard
        no_docs nowarn_missing_spec_documented warn_deprecated_catch
        "{i,\"${PROJECT_SOURCE_DIR}/lib/xmerl/include\"}"
    INPUTS "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc.hrl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_types.hrl"
        "${CMAKE_CURRENT_SOURCE_DIR}/include/edoc_doclet.hrl"
        "${PROJECT_SOURCE_DIR}/lib/xmerl/include/xmerl.hrl"
    DEPENDS otp_edoc_parser otp_app_syntax_tools otp_app_xmerl otp_app_inets
)
otp_application_version(edoc _version)
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/edoc_doclet.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/edoc_types.hrl"
    DESTINATION "lib/edoc-${_version}/src")
install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/bin/edoc" DESTINATION "lib/edoc-${_version}/bin")
install(PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/priv/edoc_generate" DESTINATION "lib/edoc-${_version}/priv")
install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/stylesheet.css"
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/erlang.png"
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/edoc.dtd"
    DESTINATION "lib/edoc-${_version}/priv")
