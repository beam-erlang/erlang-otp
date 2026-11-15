# tools application sources, generation and release rules.
otp_application_version(tools _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cover.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cprof.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/crashdump.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eprof.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/fprof.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/lcnt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/make.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tags.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tprof.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xref.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xref_base.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xref_compiler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xref_reader.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xref_scanner.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/xref_utils.erl"
    "${OTP_GENERATED_ROOT}/tools/src/xref_parser.erl"
)

get_filename_component(_parser_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/src/xref_parser.yrl" DIRECTORY)
otp_erlc_command(_parser_command "${_parser_source_dir}" "${OTP_GENERATED_ROOT}/tools/src/xref_parser.erl"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/xref_parser.yrl")
otp_generator(TARGET otp_generate_xref_parser
    COMMANDS ${_parser_command}
    OUTPUTS "${OTP_GENERATED_ROOT}/tools/src/xref_parser.erl"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/xref_parser.yrl"
        otp_bootstrap_parsetools ${_parser_command_INPUTS}
)

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP tools
    SOURCES ${_sources}
    OPTIONS nowarn_deprecated_catch
    DEPENDS otp_generate_xref_parser
    INPUTS ${_headers}
)


# Normal release resources from lib/tools/emacs/Makefile at the selected OTP pin.
# Upstream installs these source files; .elc compilation is not a release step.

otp_application_version(tools _tools_version)
set(_tools_emacs_files
    erldoc.el
    erlang-skels.el
    erlang-start.el
    erlang-eunit.el
    erlang-edoc.el
    erlang-flymake.el
    erlang-test.el
    erlang.el
    README
)
set(_tools_emacs_sources)

foreach(_file IN LISTS _tools_emacs_files)
    list(APPEND _tools_emacs_sources "${PROJECT_SOURCE_DIR}/lib/tools/emacs/${_file}")
endforeach()

install(FILES ${_tools_emacs_sources} DESTINATION "lib/tools-${_tools_version}/emacs")

# cover:analyse_to_file(..., [html]) loads this runtime stylesheet.
install(FILES "${PROJECT_SOURCE_DIR}/lib/tools/priv/styles.css"
    DESTINATION "lib/tools-${_tools_version}/priv"
)
