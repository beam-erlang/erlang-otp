# Release-management tools and their wx interface.

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_app_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_fgraph.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_fgraph_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_mod_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_sys_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_target.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_utils.erl"
)

otp_application_version(reltool _version)
otp_add_application(APP reltool
    SOURCES ${_sources}
    OPTIONS warnings_as_errors nowarn_deprecated_catch
        "{parse_transform,sys_pre_attributes}"
        "{attribute,insert,app_vsn,\"reltool-${_version}\"}"
    INPUTS "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool.hrl"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/reltool_fgraph.hrl"
        "${PROJECT_SOURCE_DIR}/lib/wx/include/wx.hrl"
    DEPENDS otp_app_wx otp_app_tools otp_app_sasl
)
