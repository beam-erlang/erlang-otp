# inets application sources, generation and release rules.
otp_application_version(inets _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inets_app/inets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inets_app/inets_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inets_app/inets_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inets_app/inets_service.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inets_app/inets_trace.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inets_app/inets_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc_handler_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc_manager.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc_profile_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc_request.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc_response.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_client/httpc_cookie.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_lib/http_chunk.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_lib/http_request.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_lib/http_response.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_lib/http_transport.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_lib/http_util.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_lib/http_uri.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_acceptor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_acceptor_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_cgi.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_connection_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_conf.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_custom_api.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_esi.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_example.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_file.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_instance_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_log.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_logger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_manager.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_misc_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_request.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_request_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_response.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_script_env.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_socket.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_util.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_alias.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth_dets.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth_mnesia.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth_plain.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_dir.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_disk_log.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_esi.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_get.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_head.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_log.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_range.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_responsecontrol.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_security.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_security_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_trace.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_cgi.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_actions.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_custom.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_acceptor.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_acceptor_sup.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_cgi.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_connection_sup.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_conf.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_custom_api.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_esi.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_example.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_file.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_instance_sup.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_log.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_logger.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_manager.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_misc_sup.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_request.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_request_handler.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_response.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_script_env.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_socket.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_sup.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_util.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_alias.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth_dets.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth_mnesia.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth_plain.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_auth_server.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_dir.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_disk_log.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_esi.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_get.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_head.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_log.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_range.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_responsecontrol.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_security.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_security_server.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_trace.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_cgi.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/mod_actions.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/http_server/httpd_custom.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'SERVER_SOFTWARE',\"inets/${_version}\"}")
otp_add_application(
    APP inets
    SOURCES ${_sources}
    OPTIONS
        warn_obsolete_bool_op nowarn_deprecated_catch
        "{parse_transform,sys_pre_attributes}"
        "{attribute,insert,app_vsn,\"inets-${_version}\"}"
    INPUTS ${_headers}
    RESOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/inets_app"
    OWN_CODE_PATH
    PRESERVE_SOURCE_LAYOUT
)


file(GLOB_RECURSE _support_sources CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.yrl"
)
foreach(_support IN LISTS _support_sources)
    file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}/src" "${_support}")
    get_filename_component(_directory "${_relative}" DIRECTORY)
    install(FILES "${_support}" DESTINATION "lib/inets-${_version}/src/${_directory}")
endforeach()
