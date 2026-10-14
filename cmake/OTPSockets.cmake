# SPDX-License-Identifier: Apache-2.0
include("${CMAKE_CURRENT_LIST_DIR}/OTPSocketCapabilities.cmake")
otp_application_version(erts _socket_erts_version)
set(_socket_directory "erts-${_socket_erts_version}/lib")
set(_socket_common "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common")
set(_socket_sources
    "${_socket_common}/prim_socket_nif.c" "${_socket_common}/prim_net_nif.c"
    "${_socket_common}/socket_dbg.c" "${_socket_common}/socket_tarray.c"
    "${_socket_common}/socket_util.c")
if(WIN32)
    list(APPEND _socket_sources "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/win32/win_socket_asyncio.c")
else()
    list(APPEND _socket_sources "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/unix/unix_socket_syncio.c")
endif()
add_library(otp_socket_backend OBJECT ${_socket_sources})
target_compile_features(otp_socket_backend PRIVATE c_std_11)
target_compile_definitions(otp_socket_backend PRIVATE _GNU_SOURCE _FILE_OFFSET_BITS=64
    "$<$<CONFIG:Debug>:DEBUG>")
target_include_directories(otp_socket_backend PRIVATE
    "${_socket_common}" "${PROJECT_BINARY_DIR}/generated")
target_link_libraries(otp_socket_backend PRIVATE BEAM::NIF BEAM::Driver ${CMAKE_DL_LIBS})
if(OTP_SOCKET_HAVE_SCTP_H)
    target_link_libraries(otp_socket_backend PRIVATE "${OTP_SCTP_LIBRARY}")
endif()
set_target_properties(otp_socket_backend PROPERTIES
    C_VISIBILITY_PRESET hidden
    LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/${_socket_directory}")
list(POP_FRONT _socket_sources _socket_first_source)
otp_register_native(otp_socket_backend builtin-backend socket_backend "${_socket_first_source}"
    "${_socket_directory}/${CMAKE_SHARED_LIBRARY_PREFIX}otp_socket_backend${CMAKE_SHARED_LIBRARY_SUFFIX}"
    ${_socket_sources})
foreach(_module IN ITEMS prim_socket prim_net)
    set_source_files_properties("${_socket_common}/${_module}_nif.c" PROPERTIES
        COMPILE_DEFINITIONS "STATIC_ERLANG_NIF_LIBNAME=otp_${_module}")
endforeach()
