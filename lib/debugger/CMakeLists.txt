# debugger application sources, generation and release rules.
otp_application_version(debugger _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/debugger.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/i.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/int.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_debugged.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_icmd.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_idb.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_ieval.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_iload.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_iserver.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_istk.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_break.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_break_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_code.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_filedialog_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_interpret.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_mon.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_mon_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_settings.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_src_view.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_trace.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_trace_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_view.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_win.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dbg_wx_winman.erl"
)

set(_release_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/erlang_bug.png"
)
set(_release_executables)
set(_release_outputs)
foreach(_source IN LISTS _release_sources)
    if(_source MATCHES "^${OTP_GENERATED_ROOT}/")
        file(RELATIVE_PATH _relative "${OTP_GENERATED_ROOT}/debugger" "${_source}")
    else()
        file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}" "${_source}")
    endif()
    if(_relative MATCHES "^examples/")
        set(_relative "doc/${_relative}")
    endif()
    set(_output "${PROJECT_BINARY_DIR}/lib/debugger/${_relative}")
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
    set(_copy_script "${OTP_INTERNAL_ROOT}/debugger/assets/${_copy_id}.cmake")
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
        install(PROGRAMS "${_output}" DESTINATION "lib/debugger-${_version}/${_directory}")
    else()
        install(FILES "${_output}" DESTINATION "lib/debugger-${_version}/${_directory}")
    endif()
endforeach()
add_custom_target(otp_debugger_assets ALL DEPENDS ${_release_outputs})

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP debugger
    SOURCES ${_sources}
    OPTIONS
        "warnings_as_errors"
        "nowarn_deprecated_catch"
    INPUTS ${_headers}
)
