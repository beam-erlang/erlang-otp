# syntax_tools application sources, generation and release rules.
otp_application_version(syntax_tools _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_syntax.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_prettypr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_syntax_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_comment_scan.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_recomment.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/epp_dodger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/prettypr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/merl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/merl_transform.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP syntax_tools
    SOURCES ${_sources}
    OPTIONS warn_deprecated_catch warn_obsolete_bool_op warn_unused_import
    INPUTS ${_headers}
    SELF_TRANSFORM merl_transform
)
