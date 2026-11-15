# observer application sources, generation and release rules.
otp_application_version(observer _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/crashdump_viewer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_atom_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_bin_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_detail_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_dist_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_ets_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_fun_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_gen_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_html_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_info_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_int_tab_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_mem_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_mod_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_multi_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_persistent_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_port_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_proc_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_sched_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_table_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_term_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_timer_cb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_virtual_list_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cdv_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/etop.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/etop_tr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/etop_txt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_app_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_alloc_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_html_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_lib.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_perf_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_port_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_pro_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_procinfo.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_sock_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_sys_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_trace_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_traceoptions_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_tv_table.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_tv_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/observer_wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ttb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ttb_et.erl"
)

set(_release_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/bin/etop"
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/bin/cdv"
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/erlang_observer.png"
)
set(_release_executables "${CMAKE_CURRENT_SOURCE_DIR}/priv/bin/etop" "${CMAKE_CURRENT_SOURCE_DIR}/priv/bin/cdv")
set(_release_outputs)
foreach(_source IN LISTS _release_sources)
    if(_source MATCHES "^${OTP_GENERATED_ROOT}/")
        file(RELATIVE_PATH _relative "${OTP_GENERATED_ROOT}/observer" "${_source}")
    else()
        file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}" "${_source}")
    endif()
    if(_relative MATCHES "^examples/")
        set(_relative "doc/${_relative}")
    endif()
    set(_output "${PROJECT_BINARY_DIR}/lib/observer/${_relative}")
    if(_source IN_LIST _release_executables)
        set(_mode 755)
    else()
        set(_mode 644)
    endif()
    get_filename_component(_output_directory "${_output}" DIRECTORY)
    otp_cmake_literal(_source_literal "${_source}")
    otp_cmake_literal(_output_literal "${_output}")
    otp_cmake_literal(_directory_literal "${_output_directory}")
    set(_permissions OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
    if(_mode EQUAL 755)
        list(APPEND _permissions OWNER_EXECUTE GROUP_EXECUTE WORLD_EXECUTE)
    endif()
    string(JOIN " " _permissions ${_permissions})
    string(SHA256 _copy_id "${_source};${_output};${_mode}")
    set(_copy_script "${OTP_INTERNAL_ROOT}/observer/assets/${_copy_id}.cmake")
    file(GENERATE OUTPUT "${_copy_script}" CONTENT
        "file(MAKE_DIRECTORY ${_directory_literal})\nfile(COPY_FILE ${_source_literal} ${_output_literal})\nfile(CHMOD ${_output_literal} PERMISSIONS ${_permissions})\n")
    add_custom_command(OUTPUT "${_output}"
        COMMAND "${CMAKE_COMMAND}" -P "${_copy_script}"
        DEPENDS "${_source}" "${_copy_script}"
        VERBATIM
    )
    list(APPEND _release_outputs "${_output}")
    get_filename_component(_directory "${_relative}" DIRECTORY)
    if(_source IN_LIST _release_executables)
        install(PROGRAMS "${_output}" DESTINATION "lib/observer-${_version}/${_directory}")
    else()
        install(FILES "${_output}" DESTINATION "lib/observer-${_version}/${_directory}")
    endif()
endforeach()
add_custom_target(otp_observer_assets ALL DEPENDS ${_release_outputs})

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP observer
    SOURCES ${_sources}
    OPTIONS
        "warnings_as_errors"
        "nowarn_deprecated_catch"
        "{i,\"${PROJECT_SOURCE_DIR}/lib/et/include\"}"
    INPUTS ${_headers}
)
