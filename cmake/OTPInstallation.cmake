# Whole-product release metadata and finalization follow all component installs.
if(WIN32)
    # This build helper holds replacement permissions over the complete existing
    # leaf set before invoking the ordinary CMake publisher. It is not installed.
    add_executable(otp_install_guard "${CMAKE_CURRENT_LIST_DIR}/otp_windows_publish.c")
    set_target_properties(otp_install_guard PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${OTP_INTERNAL_ROOT}/install"
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    set(OTP_INSTALL_GUARD "$<TARGET_FILE:otp_install_guard>")
    set(OTP_WINDOWS_RUNTIME_DLLS "" CACHE STRING "Explicit Release CRT and optional dependency DLL files to deploy")
    set(_runtime_inputs "")
    set(_runtime_names)
    foreach(_dll IN LISTS OTP_WINDOWS_RUNTIME_DLLS)
        if(NOT IS_ABSOLUTE "${_dll}" OR NOT EXISTS "${_dll}" OR IS_DIRECTORY "${_dll}")
            message(FATAL_ERROR "OTP_WINDOWS_RUNTIME_DLLS entries must be existing absolute DLL paths: ${_dll}")
        endif()
        get_filename_component(_name "${_dll}" NAME)
        string(TOLOWER "${_name}" _lower)
        if(NOT _lower MATCHES "[.]dll$")
            message(FATAL_ERROR "Runtime deployment input is not a DLL: ${_dll}")
        endif()
        if(_lower MATCHES "^((vcruntime|msvcp|concrt|vccorlib|vcamp)[0-9_]*d(_.*)?|ucrtbased)[.]dll$")
            message(FATAL_ERROR "Developer Debug CRT DLLs must not be redistributed: ${_dll}")
        endif()
        # Debug is a developer distribution using its selected Debug CRT.
        if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND
                _lower MATCHES "^(vcruntime|msvcp|concrt|vccorlib|vcamp)")
            continue()
        endif()
        if(_lower IN_LIST _runtime_names)
            message(FATAL_ERROR "Duplicate Windows runtime DLL name: ${_name}")
        endif()
        list(APPEND _runtime_names "${_lower}")
        file(SHA256 "${_dll}" _hash)
        string(APPEND _runtime_inputs "${_hash}  ${_dll}\n")
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_dll}")
        install(FILES "${_dll}" DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
        install(FILES "${_dll}" DESTINATION bin)
    endforeach()
    file(WRITE "${OTP_INTERNAL_ROOT}/install/windows-runtime-inputs.txt" "${_runtime_inputs}")
endif()
set(_release_directory "releases/${PROJECT_VERSION_MAJOR}")

foreach(_name start_clean no_dot_erlang start_sasl)
    foreach(_extension rel script boot)
        install(FILES "${PROJECT_BINARY_DIR}/erts/start_scripts/${_name}.${_extension}"
            DESTINATION "${_release_directory}"
        )
    endforeach()
endforeach()

install(FILES
    "${PROJECT_BINARY_DIR}/erts/start_scripts/start.boot"
    "${PROJECT_BINARY_DIR}/erts/start_scripts/start.script"
    "${PROJECT_BINARY_DIR}/erts/start_scripts/start_all_example.rel"
    DESTINATION "${_release_directory}"
)

install(FILES
    "${PROJECT_SOURCE_DIR}/OTP_VERSION"
    "${PROJECT_SOURCE_DIR}/sys.config"
    DESTINATION "${_release_directory}"
)
install(FILES "${PROJECT_BINARY_DIR}/erts/start_scripts/RELEASES.src" DESTINATION releases)
set(_installed_versions "")

foreach(_app IN LISTS OTP_APPLICATIONS)
    otp_application_version("${_app}" _version)
    string(APPEND _installed_versions "${_app}-${_version}\n")
endforeach()

string(APPEND _installed_versions "erts-${OTP_ERTS_VERSION}\n")
file(WRITE
    "${OTP_INTERNAL_ROOT}/install/installed_application_versions" "${_installed_versions}"
)
install(FILES "${OTP_INTERNAL_ROOT}/install/installed_application_versions"
    DESTINATION "${_release_directory}"
)

# Finalize the staged tree, then atomically replace installed files. Keep the
# upstream launcher/resource logic and DESTDIR's logical-prefix convention.
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/templates/install_finalize.cmake.in"
    "${OTP_INTERNAL_ROOT}/install/install_finalize.cmake.in"
    @ONLY
)
file(GENERATE OUTPUT "${OTP_INTERNAL_ROOT}/install/install_finalize.cmake"
    INPUT "${OTP_INTERNAL_ROOT}/install/install_finalize.cmake.in")
install(SCRIPT "${OTP_INTERNAL_ROOT}/install/install_finalize.cmake")

# The source-shaped build is directly runnable. Assemble a versioned release
# only when explicitly requested, through the same atomic installation path.
function(otp_distribution_targets output directory)
    get_property(_targets DIRECTORY "${directory}" PROPERTY BUILDSYSTEM_TARGETS)
    set(_result)
    foreach(_target IN LISTS _targets)
        get_target_property(_type "${_target}" TYPE)
        get_target_property(_excluded "${_target}" EXCLUDE_FROM_ALL)
        if(_target MATCHES "^otp_" AND NOT _type STREQUAL "INTERFACE_LIBRARY" AND NOT _excluded)
            list(APPEND _result "${_target}")
        endif()
    endforeach()
    get_property(_directories DIRECTORY "${directory}" PROPERTY SUBDIRECTORIES)
    foreach(_directory IN LISTS _directories)
        otp_distribution_targets(_children "${_directory}")
        list(APPEND _result ${_children})
    endforeach()
    set(${output} "${_result}" PARENT_SCOPE)
endfunction()
otp_distribution_targets(_otp_release_dependencies "${PROJECT_SOURCE_DIR}")
add_custom_target(otp_release
    COMMAND "${CMAKE_COMMAND}" --install "${PROJECT_BINARY_DIR}"
        --prefix "${PROJECT_BINARY_DIR}/release/${OTP_TARGET}" --config "$<CONFIG>"
    DEPENDS ${_otp_release_dependencies}
    COMMENT "Assembling release/${OTP_TARGET}" VERBATIM)
