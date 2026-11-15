# Erlang port mapper daemon.
add_executable(otp_epmd
    src/epmd.c
    src/epmd_srv.c
    src/epmd_cli.c
)
target_link_libraries(otp_epmd PRIVATE otp_command_format)
target_compile_definitions(otp_epmd PRIVATE EPMD_PORT_NO=4369)
otp_linux_native_flags(otp_epmd HIDDEN)
if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
    target_compile_options(otp_epmd PRIVATE -O2 -g
        -Werror=undef -Werror=implicit -Werror=return-type
        -Wall -Wstrict-prototypes -Wpointer-arith -Wmissing-prototypes
        -Wdeclaration-after-statement)
    target_compile_definitions(otp_epmd PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
endif()
set_target_properties(otp_epmd PROPERTIES
    OUTPUT_NAME epmd
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_epmd RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
