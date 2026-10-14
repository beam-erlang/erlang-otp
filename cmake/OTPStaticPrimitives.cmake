# SPDX-License-Identifier: Apache-2.0
# OTP-owned replacements for the VM's transitional static native registrations.
include("${CMAKE_CURRENT_LIST_DIR}/OTPTerminalCapabilities.cmake")
otp_application_version(erts _static_erts_version)
set(_static_directory "erts-${_static_erts_version}/lib")

foreach(_module IN ITEMS prim_tty zstd)
    set(_target "otp_${_module}_nif")
    add_library("${_target}" OBJECT
        "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common/${_module}_nif.c")
    target_compile_features("${_target}" PRIVATE c_std_11)
    target_compile_definitions("${_target}" PRIVATE _GNU_SOURCE "$<$<CONFIG:Debug>:DEBUG>")
    target_link_libraries("${_target}" PRIVATE BEAM::NIF)
    target_compile_definitions("${_target}" PRIVATE "STATIC_ERLANG_NIF_LIBNAME=otp_${_module}")
    set_target_properties("${_target}" PROPERTIES PREFIX "" OUTPUT_NAME "${_module}"
        C_VISIBILITY_PRESET hidden
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/${_static_directory}")
endforeach()
target_include_directories(otp_prim_tty_nif PRIVATE
    "${PROJECT_BINARY_DIR}/generated" ${CURSES_INCLUDE_DIRS})
target_link_libraries(otp_prim_tty_nif PRIVATE BEAM::Driver ${CURSES_LIBRARIES})
otp_register_native(otp_prim_tty_nif builtin-nif prim_tty
    "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common/prim_tty_nif.c"
    "${_static_directory}/prim_tty${CMAKE_SHARED_MODULE_SUFFIX}")

# Preserve the retained vendor implementation and assembly optimization. Its
# objects belong only to this extension; no VM source or configuration is used.
set(_zstd_root "${PROJECT_SOURCE_DIR}/erts/emulator/zstd")
set(_zstd_sources)
foreach(_source IN ITEMS
        common/debug.c common/entropy_common.c common/error_private.c
        common/fse_decompress.c common/pool.c common/threading.c common/xxhash.c
        common/zstd_common.c compress/fse_compress.c compress/hist.c
        compress/huf_compress.c compress/zstd_compress.c
        compress/zstd_compress_literals.c compress/zstd_compress_sequences.c
        compress/zstd_compress_superblock.c compress/zstd_double_fast.c
        compress/zstd_fast.c compress/zstd_lazy.c compress/zstd_ldm.c
        compress/zstdmt_compress.c compress/zstd_opt.c compress/zstd_preSplit.c
        decompress/huf_decompress.c decompress/zstd_ddict.c
        decompress/zstd_decompress_block.c decompress/zstd_decompress.c)
    list(APPEND _zstd_sources "${_zstd_root}/${_source}")
endforeach()
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)$" AND NOT WIN32)
    enable_language(ASM)
    list(APPEND _zstd_sources "${_zstd_root}/decompress/huf_decompress_amd64.S")
endif()
if(WIN32)
    target_compile_definitions(otp_zstd_nif PRIVATE ZSTD_DISABLE_ASM)
endif()
target_sources(otp_zstd_nif PRIVATE ${_zstd_sources})
target_include_directories(otp_zstd_nif PRIVATE "${_zstd_root}")
target_compile_definitions(otp_zstd_nif PRIVATE ERTS_USE_BUILTIN_ZSTD)
otp_register_native(otp_zstd_nif builtin-nif zstd
    "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common/zstd_nif.c"
    "${_static_directory}/zstd${CMAKE_SHARED_MODULE_SUFFIX}" ${_zstd_sources})

add_library(otp_ram_file_drv_driver OBJECT
    "${PROJECT_SOURCE_DIR}/erts/emulator/drivers/common/ram_file_drv.c")
target_compile_features(otp_ram_file_drv_driver PRIVATE c_std_11)
target_compile_definitions(otp_ram_file_drv_driver PRIVATE STATIC_ERLANG_DRIVER "$<$<CONFIG:Debug>:DEBUG>")
target_link_libraries(otp_ram_file_drv_driver PRIVATE BEAM::Driver)
set_target_properties(otp_ram_file_drv_driver PROPERTIES PREFIX "" OUTPUT_NAME ram_file_drv
    C_VISIBILITY_PRESET hidden
    LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/${_static_directory}")
otp_register_native(otp_ram_file_drv_driver builtin-driver ram_file_drv
    "${PROJECT_SOURCE_DIR}/erts/emulator/drivers/common/ram_file_drv.c"
    "${_static_directory}/ram_file_drv${CMAKE_SHARED_MODULE_SUFFIX}")
if(WIN32)
    add_library(otp_registry_driver OBJECT "${PROJECT_SOURCE_DIR}/erts/emulator/drivers/win32/registry_drv.c")
    target_link_libraries(otp_registry_driver PRIVATE BEAM::Driver)
    target_include_directories(otp_registry_driver PRIVATE "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common")
    target_compile_definitions(otp_registry_driver PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
    otp_register_native(otp_registry_driver builtin-driver registry__drv__
        "${PROJECT_SOURCE_DIR}/erts/emulator/drivers/win32/registry_drv.c"
        "${_static_directory}/registry${CMAKE_SHARED_MODULE_SUFFIX}")
endif()
