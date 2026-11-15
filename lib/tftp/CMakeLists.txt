# Behaviour modules precede their implementations.

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp_logger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp_binary.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp_engine.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp_file.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp_sup.erl"
)

otp_add_application(APP tftp
    SOURCES ${_sources}
    OPTIONS warn_unused_vars nowarn_missing_spec_documented warn_obsolete_bool_op nowarn_deprecated_catch
    INPUTS "${CMAKE_CURRENT_SOURCE_DIR}/src/tftp.hrl"
    OWN_CODE_PATH
)
