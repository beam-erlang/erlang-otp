# Native Windows commands retain upstream sources and argument handling.
set(_win32 "${PROJECT_SOURCE_DIR}/erts/etc/win32")
set(_common "${PROJECT_SOURCE_DIR}/erts/etc/common")
set(_windows_generated "${OTP_INTERNAL_ROOT}/windows")
file(MAKE_DIRECTORY "${_windows_generated}")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${_win32}/version.h.src" "${_win32}/Install.src")

file(READ "${_win32}/version.h.src" _version_header)
string(REPLACE "." "," _erts_integers "${OTP_ERTS_VERSION}")
string(REPLACE "." "," _otp_integers "${PROJECT_VERSION}")
foreach(_pair IN ITEMS "ERTS_VERSION|${OTP_ERTS_VERSION}" "OTP_VERSION|${PROJECT_VERSION}"
        "ERTS_VERSION_INTS|${_erts_integers}" "OTP_VERSION_INTS|${_otp_integers}" "YEAR|2026")
    string(REPLACE "|" ";" _parts "${_pair}")
    list(GET _parts 0 _name)
    list(GET _parts 1 _value)
    string(REPLACE "%${_name}%" "${_value}" _version_header "${_version_header}")
endforeach()
file(CONFIGURE OUTPUT "${_windows_generated}/version.h" CONTENT "${_version_header}" @ONLY)
file(CONFIGURE OUTPUT "${_windows_generated}/erl_version.h"
    CONTENT "#define ERLANG_VERSION \"${OTP_ERTS_VERSION}\"\n" @ONLY)

function(otp_windows_command target name)
    add_executable(${target} ${ARGN})
    target_link_libraries(${target} PRIVATE otp_command_format)
    target_include_directories(${target} PRIVATE "${_common}" "${_win32}" "${_windows_generated}")
    set_target_properties(${target} PROPERTIES OUTPUT_NAME "${name}"
        RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}")
    install(TARGETS ${target} RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
endfunction()

otp_windows_command(otp_erl erl "${_win32}/erl.c" "${_win32}/init_file.c" "${_win32}/erl.rc")
otp_windows_command(otp_erlc erlc "${_common}/erlc.c")
target_link_libraries(otp_erlc PRIVATE otp_ei)
otp_windows_command(otp_escript escript "${_common}/escript.c")
otp_windows_command(otp_ct_run ct_run "${_common}/ct_run.c")
otp_windows_command(otp_inet_gethost inet_gethost "${_common}/inet_gethost.c")
otp_windows_command(otp_heart heart "${_common}/heart.c")
foreach(_port otp_inet_gethost otp_heart)
    target_sources(${_port} PRIVATE "${_win32}/port_entry.c")
    target_link_options(${_port} PRIVATE "LINKER:/ENTRY:erl_port_entry")
endforeach()
otp_windows_command(otp_start_erl start_erl "${_win32}/start_erl.c")
otp_windows_command(otp_erl_log erl_log "${_win32}/erl_log.c")

add_library(otp_erlexec SHARED "${_common}/erlexec.c" "${_win32}/init_file.c"
    "${PROJECT_SOURCE_DIR}/erts/etc/windows_erlexec.c")
set_property(SOURCE "${_common}/erlexec.c" APPEND PROPERTY
    COMPILE_DEFINITIONS win_erlexec=otp_upstream_win_erlexec)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set_property(SOURCE "${_common}/erlexec.c" APPEND PROPERTY COMPILE_DEFINITIONS WIN32_ALWAYS_DEBUG)
endif()
target_link_libraries(otp_erlexec PRIVATE otp_command_format BEAM::Driver shell32 ole32)
target_compile_definitions(otp_erlexec PRIVATE OTP_SYSTEM_VERSION="${PROJECT_VERSION_MAJOR}")
target_include_directories(otp_erlexec PRIVATE "${_common}" "${_win32}" "${_windows_generated}")
set_target_properties(otp_erlexec PROPERTIES PREFIX "" OUTPUT_NAME erlexec
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
    ARCHIVE_OUTPUT_DIRECTORY "${OTP_INTERNAL_ROOT}/native/import")
install(TARGETS otp_erlexec RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")

otp_erlang_string(_bootstrap_compiler "${OTP_BOOTSTRAP_ROOT}/lib/compiler/ebin/compile.beam")
set(_guard "Compiler=code:which(compile),ExpectedCompiler=${_bootstrap_compiler},Match=case Compiler of F when is_list(F) -> string:casefold(F)=:=string:casefold(ExpectedCompiler); _ -> false end,case {Match,erlang:system_info(version),erlang:system_info(otp_release),erlang:system_info(system_architecture),erlang:system_info(emu_flavor),{erlang:system_info(build_type),erlang:system_info(debug_compiled),erlang:system_info(lock_checking)}} of {true,${_erts_version},${_otp_release},${_architecture},${BEAM_SDK_FLAVOR},${_otp_runtime_diagnostics}} -> {module,compile}=code:ensure_loaded(compile),ok; Actual -> io:format(standard_error,\"OTP bootstrap selection mismatch: ~tp ~tp~n\",[Compiler,Actual]),halt(1) end.")
foreach(_name bootstrap_executable product_executable bootstrap_boot inspection guard)
    if(_name STREQUAL bootstrap_executable)
        set(_value "${OTP_BOOTSTRAP_ERL}")
    elseif(_name STREQUAL product_executable)
        set(_value "${PROJECT_BINARY_DIR}/bin/erl.exe")
    elseif(_name STREQUAL bootstrap_boot)
        set(_value "${OTP_BOOTSTRAP_ROOT}/bin/no_dot_erlang")
    elseif(_name STREQUAL inspection)
        set(_value "${PROJECT_BINARY_DIR}/erts/ebin")
    else()
        set(_value "${_guard}")
    endif()
    # A JSON string is also a valid C string for these UTF-8 paths and expression.
    otp_erlang_string(_literal "${_value}")
    string(APPEND _launcher_config "static const char otp_${_name}[] = ${_literal};\n")
endforeach()
file(CONFIGURE OUTPUT "${_windows_generated}/otp_windows_launcher.h" CONTENT "${_launcher_config}" @ONLY)

add_executable(otp_install "${_win32}/Install.c" "${_win32}/init_file.c")
target_link_libraries(otp_install PRIVATE otp_native_config)
target_include_directories(otp_install PRIVATE "${_win32}")
set_target_properties(otp_install PROPERTIES OUTPUT_NAME Install RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}")
install(TARGETS otp_install RUNTIME DESTINATION .)
file(READ "${_win32}/Install.src" _install_ini)
string(REPLACE "%I_VSN%" "${OTP_ERTS_VERSION}" _install_ini "${_install_ini}")
string(REPLACE "%I_SYSTEM_VSN%" "${PROJECT_VERSION_MAJOR}" _install_ini "${_install_ini}")
file(CONFIGURE OUTPUT "${_windows_generated}/Install.ini" CONTENT "${_install_ini}" @ONLY)
install(FILES "${_windows_generated}/Install.ini" DESTINATION .)

get_filename_component(_sdk_bin "${CMAKE_RC_COMPILER}" DIRECTORY)
find_program(OTP_MESSAGE_COMPILER NAMES mc.exe mc HINTS "${_sdk_bin}" REQUIRED)
set(_message_root "${_windows_generated}/messages")
file(MAKE_DIRECTORY "${_message_root}")
add_custom_command(OUTPUT "${_message_root}/erlsrv_logmess.h" "${_message_root}/erlsrv_logmess.rc"
    COMMAND "${OTP_MESSAGE_COMPILER}" -h "${_message_root}" -r "${_message_root}"
        "${_win32}/erlsrv/erlsrv_logmess.mc"
    DEPENDS "${_win32}/erlsrv/erlsrv_logmess.mc" VERBATIM)
set(_erlsrv_sources "${_message_root}/erlsrv_logmess.rc")
foreach(_part registry service interactive main util)
    list(APPEND _erlsrv_sources "${_win32}/erlsrv/erlsrv_${_part}.c")
endforeach()
otp_windows_command(otp_erlsrv erlsrv ${_erlsrv_sources})
target_include_directories(otp_erlsrv PRIVATE "${_message_root}")
set_target_properties(otp_erlsrv PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set_source_files_properties("${_win32}/erlsrv/erlsrv_util.c" PROPERTIES
    OBJECT_DEPENDS "${_message_root}/erlsrv_logmess.h")
install(FILES "${_win32}/beam_icon.ico" "${_win32}/erl_icon.ico" "${_win32}/hrl_icon.ico"
    DESTINATION usr/lib/icons)
install(FILES "${_win32}/start_erl.c" DESTINATION "erts-${OTP_ERTS_VERSION}/src")
foreach(_target otp_erl otp_erlc otp_escript otp_ct_run)
    install(TARGETS ${_target} RUNTIME DESTINATION bin)
endforeach()
