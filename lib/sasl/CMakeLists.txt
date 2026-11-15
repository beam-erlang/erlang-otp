# sasl application sources, generation and release rules.
otp_application_version(sasl _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/alarm_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erlsrv.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/format_lib_supp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc_supp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/rb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/rb_format_supp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/release_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/release_handler_1.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sasl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sasl_report.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sasl_report_file_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/sasl_report_tty_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/systools.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/systools_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/systools_make.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/systools_rc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/systools_relup.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP sasl
    SOURCES ${_sources}
    OPTIONS nowarn_deprecated_catch
    INPUTS ${_headers}
)
