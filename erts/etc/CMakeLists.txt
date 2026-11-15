# OTP launchers, port helpers and installation scripts.

if(WIN32)
    include("${PROJECT_SOURCE_DIR}/cmake/WindowsCommands.cmake")
    return()
endif()

add_executable(otp_erlc
    common/erlc.c
)
target_link_libraries(otp_erlc PRIVATE otp_command_format otp_ei)
set_target_properties(otp_erlc PROPERTIES
    OUTPUT_NAME erlc
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_erlc RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
install(TARGETS otp_erlc RUNTIME DESTINATION bin)

add_executable(otp_escript
    common/escript.c
)
target_link_libraries(otp_escript PRIVATE otp_command_format)
set_target_properties(otp_escript PROPERTIES
    OUTPUT_NAME escript
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_escript RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
install(TARGETS otp_escript RUNTIME DESTINATION bin)

add_executable(otp_ct_run
    common/ct_run.c
)
target_link_libraries(otp_ct_run PRIVATE otp_command_format)
set_target_properties(otp_ct_run PROPERTIES
    OUTPUT_NAME ct_run
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_ct_run RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
install(TARGETS otp_ct_run RUNTIME DESTINATION bin)

add_executable(otp_erlexec
    common/erlexec.c
)
target_link_libraries(otp_erlexec PRIVATE otp_command_format BEAM::Driver)
target_compile_definitions(otp_erlexec PRIVATE OTP_SYSTEM_VERSION="${PROJECT_VERSION_MAJOR}")
set_target_properties(otp_erlexec PROPERTIES
    OUTPUT_NAME erlexec
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_erlexec RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")

add_executable(otp_inet_gethost
    common/inet_gethost.c
)
target_link_libraries(otp_inet_gethost PRIVATE otp_command_format)
set_target_properties(otp_inet_gethost PROPERTIES
    OUTPUT_NAME inet_gethost
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_inet_gethost RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")

add_executable(otp_heart
    common/heart.c
)
target_link_libraries(otp_heart PRIVATE otp_command_format)
set_target_properties(otp_heart PROPERTIES
    OUTPUT_NAME heart
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_heart RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")

add_executable(otp_run_erl
    unix/run_erl.c
    unix/safe_string.c
)
target_link_libraries(otp_run_erl PRIVATE otp_command_format)
set_target_properties(otp_run_erl PROPERTIES
    OUTPUT_NAME run_erl
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_run_erl RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")

add_executable(otp_to_erl
    unix/to_erl.c
    unix/safe_string.c
)
target_link_libraries(otp_to_erl PRIVATE otp_command_format)
set_target_properties(otp_to_erl PROPERTIES
    OUTPUT_NAME to_erl
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_to_erl RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")

foreach(_command IN ITEMS otp_erlc otp_escript otp_ct_run otp_erlexec
        otp_inet_gethost otp_heart otp_run_erl otp_to_erl)
    otp_linux_native_flags(${_command} HIDDEN)
    if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
        # Upstream etc/common retains its configured -O2 in Linux Debug.
        target_compile_options(${_command} PRIVATE -O2 -g
            -Werror=undef -Werror=implicit -Werror=return-type
            -Wall -Wstrict-prototypes -Wpointer-arith -Wmissing-prototypes
            -Wdeclaration-after-statement)
        target_compile_definitions(${_command} PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
    endif()
endforeach()
if(OTP_OPENPTY_LIBRARIES)
    target_link_libraries(otp_run_erl PRIVATE ${OTP_OPENPTY_LIBRARIES})
endif()

set(_otp_release "${PROJECT_VERSION_MAJOR}")
# Upstream Install -minimal owns the final erl launcher, links and start data.
foreach(_script IN ITEMS erl.src.src Install.src)
    set(_input "${PROJECT_SOURCE_DIR}/erts/etc/unix/${_script}")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_input}")
    file(READ "${_input}" _contents)
    string(REPLACE "%VSN%" "${OTP_ERTS_VERSION}" _contents "${_contents}")
    string(REPLACE "%I_VSN%" "${OTP_ERTS_VERSION}" _contents "${_contents}")
    string(REPLACE "%I_SYSTEM_VSN%" "${_otp_release}" _contents "${_contents}")
    string(REPLACE "%EMULATOR%" "beam" _contents "${_contents}")
    string(REPLACE "%EMULATOR_NUMBER%" "" _contents "${_contents}")

    if(_script STREQUAL Install.src)
        set(_output "${OTP_INTERNAL_ROOT}/install/Install")
        set(_destination .)
    else()
        set(_output "${OTP_INTERNAL_ROOT}/install/erl.src")
        set(_destination "erts-${OTP_ERTS_VERSION}/bin")
    endif()

    file(CONFIGURE OUTPUT "${_output}" CONTENT "${_contents}" @ONLY)
    file(CHMOD "${_output}"
        PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE
            WORLD_READ WORLD_EXECUTE
    )
    install(PROGRAMS "${_output}" DESTINATION "${_destination}")
endforeach()

foreach(_script IN ITEMS start.src start_erl.src)
    configure_file(
        "${PROJECT_SOURCE_DIR}/erts/etc/unix/${_script}"
        "${OTP_COMMAND_BIN}/${_script}"
        COPYONLY
    )
    install(PROGRAMS "${PROJECT_SOURCE_DIR}/erts/etc/unix/${_script}"
        DESTINATION "erts-${OTP_ERTS_VERSION}/bin"
    )
endforeach()

install(PROGRAMS "${PROJECT_SOURCE_DIR}/erts/etc/unix/format_man_pages" DESTINATION misc)
install(FILES "${PROJECT_SOURCE_DIR}/erts/etc/unix/setuid_socket_wrap.c"
    DESTINATION "erts-${OTP_ERTS_VERSION}/src"
)
