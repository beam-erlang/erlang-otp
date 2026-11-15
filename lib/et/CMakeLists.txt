# et application sources, generation and release rules.
otp_application_version(et _version)
set(_et_debug_options)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(_et_debug_options "{d,debug}")
endif()

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/et.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/et_collector.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/et_selector.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/et_viewer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/et_wx_contents_viewer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/et_wx_viewer.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP et
    SOURCES ${_sources}
    OPTIONS
        ${_et_debug_options}
        "warnings_as_errors"
        "warn_unused_vars"
        "warn_obsolete_bool_op"
        "nowarn_deprecated_catch"
    INPUTS ${_headers}
)
