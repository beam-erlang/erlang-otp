# SPDX-License-Identifier: Apache-2.0
include("${CMAKE_CURRENT_LIST_DIR}/OTPInetCapabilities.cmake")
otp_application_version(erts _inet_erts_version)
set(_inet_directory "erts-${_inet_erts_version}/lib")
set(OTP_INET_PROTOCOLS tcp udp)
if(OTP_INET_HAVE_SCTP_H)
    list(APPEND OTP_INET_PROTOCOLS sctp)
endif()
foreach(_protocol IN LISTS OTP_INET_PROTOCOLS)
    string(TOUPPER "${_protocol}" _upper)
    set(_target "otp_${_protocol}_inet_driver")
    add_library("${_target}" OBJECT
        "${PROJECT_SOURCE_DIR}/erts/emulator/drivers/common/inet_drv.c")
    target_compile_features("${_target}" PRIVATE c_std_11)
    target_compile_definitions("${_target}" PRIVATE
        STATIC_ERLANG_DRIVER "OTP_INET_DRIVER_${_upper}=1" _GNU_SOURCE _FILE_OFFSET_BITS=64
        "$<$<CONFIG:Debug>:DEBUG>")
    target_include_directories("${_target}" PRIVATE
        "${PROJECT_BINARY_DIR}/generated"
        "${PROJECT_SOURCE_DIR}/erts/emulator/nifs/common")
    target_link_libraries("${_target}" PRIVATE BEAM::Driver BEAM::NIF)
    if(_protocol STREQUAL sctp)
        target_link_libraries("${_target}" PRIVATE "${OTP_SCTP_LIBRARY}")
    endif()
    set_target_properties("${_target}" PROPERTIES PREFIX "" OUTPUT_NAME "${_protocol}_inet"
        C_VISIBILITY_PRESET hidden
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/otp/${_inet_directory}")
    otp_register_native("${_target}" builtin-driver "${_protocol}_inet"
        "${PROJECT_SOURCE_DIR}/erts/emulator/drivers/common/inet_drv.c"
        "${_inet_directory}/${_protocol}_inet${CMAKE_SHARED_MODULE_SUFFIX}")
endforeach()
