# SPDX-License-Identifier: Apache-2.0
# Explicit provenance and installed paths for OTP-owned public-SDK extensions.
function(otp_register_native target kind module source relative)
    if(WIN32 AND kind MATCHES "^builtin-")
        target_compile_definitions("${target}" PRIVATE STATIC_ERLANG_NIF STATIC_ERLANG_DRIVER)
    endif()
    set_target_properties("${target}" PROPERTIES OTP_INSTALL_PATH "${relative}")
    set(_record "{}")
    foreach(_field IN ITEMS target kind module source library installed)
        if(_field STREQUAL library)
            if(kind MATCHES "^builtin-")
                set(_value "$<JOIN:$<TARGET_OBJECTS:${target}>,;>")
            else()
                set(_value "$<TARGET_FILE:${target}>")
            endif()
        elseif(_field STREQUAL installed)
            if(kind MATCHES "^builtin-")
                set(_value "")
            else()
                set(_value "${relative}")
            endif()
        else()
            set(_value "${${_field}}")
        endif()
        _otp_json_string(_value "${_value}")
        string(JSON _record SET "${_record}" "${_field}" "${_value}")
    endforeach()
    set(_sources "[]")
    foreach(_input IN ITEMS "${source}" ${ARGN})
        string(JSON _index LENGTH "${_sources}")
        _otp_json_string(_input "${_input}")
        string(JSON _sources SET "${_sources}" ${_index} "${_input}")
    endforeach()
    string(JSON _record SET "${_record}" sources "${_sources}")
    get_property(_records GLOBAL PROPERTY OTP_NATIVE_RECORDS)
    if(NOT _records)
        set(_records "[]")
    endif()
    string(JSON _index LENGTH "${_records}")
    string(JSON _records SET "${_records}" ${_index} "${_record}")
    set_property(GLOBAL PROPERTY OTP_NATIVE_RECORDS "${_records}")
endfunction()

function(otp_write_native_inventory)
    get_property(_records GLOBAL PROPERTY OTP_NATIVE_RECORDS)
    file(GENERATE OUTPUT "${PROJECT_BINARY_DIR}/native-components.json"
        CONTENT "${_records}\n")
    if(BUILD_TESTING)
        add_test(NAME otp-native-public-boundary
            COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_native_boundary.py"
                --inventory "${PROJECT_BINARY_DIR}/native-components.json"
                --compile-commands "${PROJECT_BINARY_DIR}/compile_commands.json"
                --source-root "${PROJECT_SOURCE_DIR}"
                --sdk "${BEAM_SDK_ROOT}" --runtime "$<TARGET_FILE:BEAM::RuntimeStaticArchive>"
                --protocols ${OTP_INET_PROTOCOLS}
                --hostname-helper
                --socket-backend
                --nm "${CMAKE_NM}" --readelf "${CMAKE_READELF}")
    endif()
endfunction()
