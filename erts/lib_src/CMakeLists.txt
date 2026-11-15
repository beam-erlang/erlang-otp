# Shared command formatting and the yielding-C source transformation tool.
add_library(otp_command_format STATIC
    common/erl_printf.c
    common/erl_printf_format.c
)
target_include_directories(otp_command_format PUBLIC "${PROJECT_SOURCE_DIR}/erts/include/internal")
target_link_libraries(otp_command_format PUBLIC otp_native_config)
if(NOT WIN32)
    target_link_libraries(otp_command_format PUBLIC m)
endif()

add_executable(otp_yielding_c_fun
    yielding_c_fun/ycf_lexer.c
    yielding_c_fun/ycf_main.c
    yielding_c_fun/ycf_node.c
    yielding_c_fun/ycf_parser.c
    yielding_c_fun/ycf_printers.c
    yielding_c_fun/ycf_string.c
    yielding_c_fun/ycf_symbol.c
    yielding_c_fun/ycf_utils.c
    yielding_c_fun/ycf_yield_fun.c
)
target_link_libraries(otp_yielding_c_fun PRIVATE otp_command_format)
otp_linux_native_flags(otp_command_format HIDDEN NO_LINK_HARDENING)
otp_linux_native_flags(otp_yielding_c_fun HIDDEN)
if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
    # Both targets inherit lib_src's optimization policy upstream.
    foreach(_target IN ITEMS otp_command_format otp_yielding_c_fun)
        target_compile_options(${_target} PRIVATE -g
            "$<$<CONFIG:Release>:-O3>" "$<$<CONFIG:Debug>:-Og>"
            "$<$<AND:$<CONFIG:Release>,$<STREQUAL:${OTP_BEAM_FLAVOR},jit>>:-fno-omit-frame-pointer>"
            -Werror=undef -Werror=implicit -Werror=return-type -Wall -Wpointer-arith)
        target_compile_definitions(${_target} PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
    endforeach()
    # Upstream YCF filters these three lib_src warnings in main_target.mk.
    target_compile_options(otp_command_format PRIVATE -Wstrict-prototypes
        -Wmissing-prototypes -Wdeclaration-after-statement)
endif()
set_target_properties(otp_yielding_c_fun PROPERTIES
    OUTPUT_NAME yielding_c_fun
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
install(TARGETS otp_yielding_c_fun RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
