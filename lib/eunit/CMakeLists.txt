# eunit application sources, generation and release rules.
otp_application_version(eunit _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_autoexport.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_listener.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_data.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_proc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_serial.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_striptests.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_surefire.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_test.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_tests.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/eunit_tty.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP eunit
    SOURCES ${_sources}
    OPTIONS warn_deprecated_catch warn_obsolete_bool_op warn_unused_import
    INPUTS ${_headers}
    OWN_CODE_PATH
)
