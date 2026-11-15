# Dialyzer and Typer, including their ordinary native command launchers.

otp_application_version(dialyzer _version)
set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/cerl_prettypr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_analysis_callgraph.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_behaviours.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_callgraph.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_cl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_cl_parse.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_clean_core.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_codeserver.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_contracts.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_dataflow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_dep.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_dot.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_incremental.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_options.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_iplt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_cplt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_plt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_succ_typings.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_timing.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_typesig.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_typegraph.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_coordinator.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_worker.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_utils.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_bif_types.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/erl_types.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/typer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/typer_core.erl"
)

set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_cl_parse.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'VSN',\"v${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_plt.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'VSN',\"v${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_cplt.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'VSN',\"v${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer_iplt.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'VSN',\"v${_version}\"}")
set_property(SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/typer.erl" PROPERTY OTP_COMPILE_OPTIONS "{d,'VSN',\"v${_version}\"}")
otp_add_application(APP dialyzer
    SOURCES ${_sources}
    OPTIONS warnings_as_errors warn_export_vars warn_unused_import warn_missing_spec warn_obsolete_bool_op
    INPUTS "${CMAKE_CURRENT_SOURCE_DIR}/src/dialyzer.hrl"
    DEPENDS otp_app_syntax_tools
)

add_executable(otp_dialyzer "${PROJECT_SOURCE_DIR}/erts/etc/common/dialyzer.c")
set_target_properties(otp_dialyzer PROPERTIES
    OUTPUT_NAME dialyzer
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
target_link_libraries(otp_dialyzer PRIVATE otp_command_format)

add_executable(otp_typer "${PROJECT_SOURCE_DIR}/erts/etc/common/typer.c")
set_target_properties(otp_typer PROPERTIES
    OUTPUT_NAME typer
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
)
target_link_libraries(otp_typer PRIVATE otp_command_format)
foreach(_command IN ITEMS otp_dialyzer otp_typer)
    otp_linux_native_flags(${_command} HIDDEN)
    if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
        target_compile_options(${_command} PRIVATE -O2 -g
            -Werror=undef -Werror=implicit -Werror=return-type
            -Wall -Wstrict-prototypes -Wpointer-arith -Wmissing-prototypes
            -Wdeclaration-after-statement)
        target_compile_definitions(${_command} PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
    endif()
endforeach()
install(TARGETS otp_dialyzer otp_typer RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
install(TARGETS otp_dialyzer otp_typer RUNTIME DESTINATION bin)
