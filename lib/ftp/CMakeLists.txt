# ftp application sources, generation and release rules.
otp_application_version(ftp _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ftp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ftp_internal.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ftp_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ftp_progress.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ftp_response.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ftp_sup.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP ftp
    NO_SOURCE_SUPPORT_INSTALL
    SOURCES ${_sources}
    OPTIONS
        "{d,'VSN',\"${_version}\"}"
        "warn_unused_vars"
        "nowarn_deprecated_catch"
    INPUTS ${_headers}
)
