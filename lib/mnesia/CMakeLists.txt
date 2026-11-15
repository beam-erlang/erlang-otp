# mnesia application sources, generation and release rules.
otp_application_version(mnesia _version)
install(DIRECTORY DESTINATION "lib/mnesia-${_version}/include")
set(_mnesia_debug_options)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(_mnesia_debug_options "{d,debug}")
endif()

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_app.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_backend_type.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_backup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_bup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_checkpoint.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_checkpoint_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_controller.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_dumper.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_event.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_ext_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_frag.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_frag_hash.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_index.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_kernel_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_late_loader.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_loader.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_locker.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_log.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_monitor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_recover.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_registry.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_rpc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_schema.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_snmp_hook.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_subscr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_sup.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_sp.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_text.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/mnesia_tm.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP mnesia
    SOURCES ${_sources}
    OPTIONS
        ${_mnesia_debug_options}
        warn_obsolete_bool_op nowarn_deprecated_catch
        "{parse_transform,sys_pre_attributes}"
        "{attribute,insert,vsn,\"mnesia_${_version}\"}"
    INPUTS ${_headers}
)
