# kernel application sources, generation and release rules.
otp_application_version(kernel _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/application.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/application_controller.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/application_master.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/application_starter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/auth.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/code.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/code_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/data_publisher.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/disk_log.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/disk_log_1.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/disk_log_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/disk_log_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dist_ac.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dist_util.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_boot_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_compile_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_ddll.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_debugger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_distribution.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_epmd.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_erts_errors.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_kernel_errors.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_reply.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_signal_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erpc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/error_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/error_logger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erts_debug.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/file.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/file_io_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/file_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_sctp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_tcp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_tcp_socket.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_udp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen_udp_socket.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/global.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/global_group.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/global_search.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/group.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/group_history.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/heart.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet6_sctp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet6_tcp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet6_tcp_dist.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet6_udp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_db.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_dns.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_dns_tsig.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_epmd_dist.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_epmd_socket.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_gethost_native.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_hosts.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_parse.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_res.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_sctp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_tcp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_tcp_dist.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_udp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/kernel.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/kernel_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/kernel_refc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/local_tcp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/local_udp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_backend.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_config.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_disk_log_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_filters.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_formatter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_h_common.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_handler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_handler_watcher.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_olp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_proxy.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_simple_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_std_h.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/logger_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/net.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/net_adm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/net_kernel.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/os.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pg.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pg2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/prim_tty.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/prim_tty_sighandler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ram_file.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/raw_file_io.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/raw_file_io_compressed.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/raw_file_io_deflate.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/raw_file_io_delayed.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/raw_file_io_inflate.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/raw_file_io_list.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/rpc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/seq_trace.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/socket.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/standard_error.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/trace.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/user_drv.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/user_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/wrap_log_reader.erl"
)

otp_capture_command(_dns_command "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${OTP_GENERATED_ROOT}/kernel/src/inet_dns_record_adts.hrl"
    "${PERL_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_dns_record_adts.pl")
add_custom_command(
    OUTPUT
        "${OTP_GENERATED_ROOT}/kernel/src/inet_dns_record_adts.hrl"
    ${_dns_command}
    DEPENDS ${_dns_command_INPUTS}
        "${CMAKE_CURRENT_SOURCE_DIR}/src/inet_dns_record_adts.pl"
    VERBATIM
)
add_custom_target(otp_kernel_dns DEPENDS
    "${OTP_GENERATED_ROOT}/kernel/src/inet_dns_record_adts.hrl"
)

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_epmd.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,epmd_port_no,4369}" "{d,epmd_node_type,110}" "{d,epmd_dist_low,5}" "{d,epmd_dist_high,6}" "{d,erlang_daemon_port,4369}")
otp_add_application(
    APP kernel
    NO_SOURCE_SUPPORT_INSTALL
    SOURCES ${_sources}
    OPTIONS warn_deprecated_catch warn_obsolete_bool_op
    DEPENDS otp_kernel_dns
    INPUTS ${_headers} "${OTP_GENERATED_ROOT}/kernel/src/inet_dns_record_adts.hrl"
)

# The original release installs INTERNAL_HRL_FILES, excluding socket_int.hrl.
set(_release_headers application_master.hrl disk_log.hrl erl_epmd.hrl file_int.hrl
    inet_dns.hrl inet_res.hrl inet_boot.hrl inet_config.hrl inet_int.hrl
    logger_internal.hrl logger_olp.hrl logger_h_common.hrl)
list(TRANSFORM _release_headers PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/src/")
install(FILES ${_release_headers} "${OTP_GENERATED_ROOT}/kernel/src/inet_dns_record_adts.hrl"
    DESTINATION "lib/kernel-${_version}/src")
