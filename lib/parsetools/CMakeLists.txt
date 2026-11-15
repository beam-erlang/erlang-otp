# parsetools application sources, generation and release rules.
otp_application_version(parsetools _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/leex.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/yecc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/yeccparser.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/yeccscan.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP parsetools
    NO_SOURCE_SUPPORT_INSTALL
    SOURCES ${_sources}
    OPTIONS warn_obsolete_bool_op nowarn_deprecated_catch
    INPUTS ${_headers}
)
