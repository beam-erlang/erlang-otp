# OTP's process entry and ERTS-owned distribution components.
if(WIN32)
    # OTP owns the distribution's PE host; the sole VM and preload resources
    # come from the installed public SDK.
    add_library(otp_emulator SHARED windows_host.c)
    set(_otp_emulator_name beam.smp)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(_otp_emulator_name beam.debug.smp)
    endif()
else()
    add_executable(otp_emulator main.c)
    set(_otp_emulator_name beam.smp)
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(_otp_emulator_name beam.debug.smp)
    endif()
endif()
target_link_libraries(otp_emulator PRIVATE BEAM::Runtime)
otp_linux_native_flags(otp_emulator HIDDEN)
if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
    # The entry host follows the selected VM's optimization/debug convention.
    target_compile_options(otp_emulator PRIVATE -g
        "$<$<CONFIG:Release>:-O3>" "$<$<CONFIG:Debug>:-Og>")
    target_compile_definitions(otp_emulator PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
endif()
set_target_properties(otp_emulator PROPERTIES
    OUTPUT_NAME "${_otp_emulator_name}"
    PREFIX ""
    RUNTIME_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
    LIBRARY_OUTPUT_DIRECTORY "${OTP_COMMAND_BIN}"
    ARCHIVE_OUTPUT_DIRECTORY "${OTP_INTERNAL_ROOT}/native/import"
)
install(TARGETS otp_emulator
    RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin"
    LIBRARY DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # erlexec retains upstream's explicit emulator type/flavor selection. A
    # single-configuration distribution also keeps its ordinary erl command.
    set(_otp_emulator_aliases "beam.${OTP_BEAM_FLAVOR}")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(_otp_emulator_aliases beam.smp "beam.${OTP_BEAM_FLAVOR}"
            "beam.debug.${OTP_BEAM_FLAVOR}")
    endif()
    foreach(_alias IN LISTS _otp_emulator_aliases)
        add_custom_command(TARGET otp_emulator POST_BUILD
            BYPRODUCTS "${OTP_COMMAND_BIN}/${_alias}"
            COMMAND "${CMAKE_COMMAND}" -E rm -f "${OTP_COMMAND_BIN}/${_alias}"
            COMMAND "${CMAKE_COMMAND}" -E create_symlink "$<TARGET_FILE_NAME:otp_emulator>"
                "${OTP_COMMAND_BIN}/${_alias}" VERBATIM)
        install(FILES "${OTP_COMMAND_BIN}/${_alias}"
            DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
    endforeach()
endif()
if(WIN32)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(_otp_flavor_name "beam.debug.${OTP_BEAM_FLAVOR}.dll")
    else()
        set(_otp_flavor_name "beam.${OTP_BEAM_FLAVOR}.dll")
    endif()
    add_custom_command(TARGET otp_emulator POST_BUILD
        BYPRODUCTS "${OTP_COMMAND_BIN}/${_otp_flavor_name}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:otp_emulator>"
            "${OTP_COMMAND_BIN}/${_otp_flavor_name}" VERBATIM)
    install(FILES "$<TARGET_FILE:otp_emulator>"
        DESTINATION "erts-${OTP_ERTS_VERSION}/bin" RENAME "${_otp_flavor_name}")
    install(FILES "$<TARGET_PDB_FILE:otp_emulator>"
        DESTINATION "erts-${OTP_ERTS_VERSION}/bin" CONFIGURATIONS Debug)
endif()
if(NOT WIN32)
    beam_install_child_setup(DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
endif()
beam_install_preloaded_modules(DESTINATION "lib/erts-${OTP_ERTS_VERSION}/ebin")
# Match the original preloaded release source inventory using public SDK assets.
# Build-only metadata and zip_internal.hrl remain available in the SDK.
set(_preloaded_sources atomics.erl counters.erl erl_init.erl erl_prim_loader.erl
    erl_tracer.erl erlang.erl erts_code_purger.erl
    erts_dirty_process_signal_handler.erl erts_internal.erl
    erts_literal_area_collector.erl erts_trace_cleaner.erl init.erl
    persistent_term.erl prim_buffer.erl prim_eval.erl prim_eval.S prim_file.erl
    prim_inet.erl prim_net.erl prim_socket.erl prim_zip.erl socket_registry.erl zlib.erl)
list(TRANSFORM _preloaded_sources PREPEND "${BEAM_SDK_PRELOAD_SOURCE_DIR}/")
install(FILES ${_preloaded_sources} DESTINATION "lib/erts-${OTP_ERTS_VERSION}/src"
    PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
beam_install_native_headers(DESTINATION usr/include)
beam_install_native_headers(DESTINATION "erts-${OTP_ERTS_VERSION}/include")

add_subdirectory(lib_src)
add_subdirectory(epmd)
add_subdirectory(etc)
