# ssh application sources, generation and release rules.
otp_application_version(ssh _version)
install(DIRECTORY DESTINATION "lib/ssh-${_version}/include")

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_options.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_bits.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_channel_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_client_key_api.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_channel.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_connection.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_fsm_userauth_client.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_fsm_userauth_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_daemon_channel.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_dbg.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_lsocket_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_lsocket.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_io.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_info.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_no_io.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_server_channel.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_server_key_api.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_sftpd.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_sftpd_file_api.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_connection_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_tcpip_forward_srv.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_tcpip_forward_acceptor_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_tcpip_forward_acceptor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_system_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_transport.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_xfer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_acceptor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_acceptor_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_agent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_auth.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_message.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_cli.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_client_channel.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_connection_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_fsm_kexinit.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_shell.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_file.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_sftp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_sftpd_file.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ssh_tcpip_forward_client.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP ssh
    SOURCES ${_sources}
    OPTIONS warn_unused_vars nowarn_deprecated_callback warn_obsolete_bool_op nowarn_deprecated_catch
    INPUTS ${_headers}
    OWN_CODE_PATH
)
