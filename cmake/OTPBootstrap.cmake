# SPDX-License-Identifier: Apache-2.0
# Private OTP hosts use the same public SDK lifecycle and startup inventory as
# the product. Neither the SDK command nor a sibling compiler is a build input.
find_package(Python3 3.9 REQUIRED COMPONENTS Interpreter)
set(_otp_bootstrap "${PROJECT_SOURCE_DIR}/bootstrap")
set(_otp_bootstrap_tool "${PROJECT_SOURCE_DIR}/tools/otp_bootstrap.py")
set(_otp_boot_resource "${PROJECT_SOURCE_DIR}/tools/otp_boot_resource.escript")
set(OTP_SEED_ROOT "${PROJECT_BINARY_DIR}/bootstrap/seed")
set(OTP_BUILD_ROOT "${PROJECT_BINARY_DIR}/bootstrap/source")
execute_process(COMMAND "${Python3_EXECUTABLE}" "${_otp_bootstrap_tool}"
    verify --source "${PROJECT_SOURCE_DIR}" --seeds-only
    COMMAND_ERROR_IS_FATAL ANY)
file(READ "${_otp_bootstrap}/manifest.json" _otp_bootstrap_manifest)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${_otp_bootstrap}/manifest.json")
set(_otp_seed_files)
set(_otp_source_inputs)
set(_otp_generated_inputs)
foreach(_group IN ITEMS files sources generated)
    string(JSON _count LENGTH "${_otp_bootstrap_manifest}" "${_group}")
    math(EXPR _last "${_count}-1")
    foreach(_index RANGE 0 ${_last})
        string(JSON _name MEMBER "${_otp_bootstrap_manifest}" "${_group}" ${_index})
        if(_group STREQUAL files)
            list(APPEND _otp_seed_files "${_otp_bootstrap}/seeds/${_name}")
        elseif(_group STREQUAL sources)
            list(APPEND _otp_source_inputs "${PROJECT_SOURCE_DIR}/${_name}")
        else()
            list(APPEND _otp_generated_inputs "${PROJECT_BINARY_DIR}/generated/${_name}")
        endif()
    endforeach()
endforeach()
if(WIN32)
    # Changes to private-host launch semantics invalidate generated inputs too.
    list(APPEND _otp_source_inputs "${PROJECT_SOURCE_DIR}/tools/run_windows_host.py")
endif()
set(_seed_preloads)
string(JSON _count LENGTH "${_otp_bootstrap_manifest}" preloads)
math(EXPR _last "${_count}-1")
foreach(_index RANGE 0 ${_last})
    string(JSON _name GET "${_otp_bootstrap_manifest}" preloads ${_index})
    list(APPEND _seed_preloads "${_name}")
endforeach()
if(NOT _seed_preloads STREQUAL _preloads)
    message(FATAL_ERROR "OTP bootstrap and host preload inventories differ")
endif()

function(otp_stage_build_root output root mode)
    set(_commands COMMAND "${Python3_EXECUTABLE}" "${_otp_bootstrap_tool}"
        "${mode}" --source "${PROJECT_SOURCE_DIR}" --output "${root}")
    set(_dependencies otp_inet_gethost)
    if(NOT WIN32)
        beam_get_runtime_artifact(_helper NAME helper.child_setup KIND executable-helper)
        list(APPEND _dependencies "${_helper}")
        list(APPEND _commands
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${root}/erts-${_erts_version}/bin"
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${_helper}" "${root}/erts-${_erts_version}/bin/erl_child_setup")
    endif()
    list(APPEND _commands
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${root}/erts-${_erts_version}/bin"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "$<TARGET_FILE:otp_inet_gethost>" "${root}/erts-${_erts_version}/bin/inet_gethost${CMAKE_EXECUTABLE_SUFFIX}")
    add_custom_command(OUTPUT "${output}"
        ${_commands}
        COMMAND "${CMAKE_COMMAND}" -E touch "${output}"
        DEPENDS ${_dependencies} ${_otp_seed_files} ${_otp_source_inputs}
            "${_otp_bootstrap}/manifest.json" "${_otp_bootstrap_tool}"
        COMMENT "Staging explicit OTP ${mode} host inputs" VERBATIM)
endfunction()

otp_stage_build_root("${PROJECT_BINARY_DIR}/bootstrap/seed-stage.stamp" "${OTP_SEED_ROOT}" stage)
otp_stage_build_root("${PROJECT_BINARY_DIR}/bootstrap/source-stage.stamp" "${OTP_BUILD_ROOT}" resources)
add_custom_target(otp_seed_stage DEPENDS "${PROJECT_BINARY_DIR}/bootstrap/seed-stage.stamp")
otp_application_version(compiler _compiler_version)
foreach(_kind IN ITEMS seed build)
    if(_kind STREQUAL seed)
        set(_root "${OTP_SEED_ROOT}")
    else()
        set(_root "${OTP_BUILD_ROOT}")
    endif()
    if(_kind STREQUAL seed)
        otp_add_host(otp_seed_host "${_otp_bootstrap}/seeds/${_preload_relative}" ${_otp_seed_files})
    else()
        otp_add_host(otp_build_host "${OTP_BUILD_ROOT}/${_preload_relative}" otp_bootstrap_foundation)
    endif()
    set_target_properties("otp_${_kind}_host" PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${_root}/erts-${_erts_version}/bin")
    set(_command "$<TARGET_FILE:otp_${_kind}_host>" -S2:2 -SDcpu2:2 -SDio2 --
        -root "${_root}" -bindir "${_root}/erts-${_erts_version}/bin"
        -boot "${_root}/bin/bootstrap" -noshell -noinput
        -pa "${_root}/lib/compiler-${_compiler_version}/ebin"
        -pa "${_root}/build/ebin" -s otp_bootstrap -extra)
    if(WIN32)
        set(_command "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/run_windows_host.py" ${_command})
    endif()
    if(_kind STREQUAL seed)
        set(OTP_SEED_COMMAND ${_command})
    else()
        set(OTP_BUILD_COMMAND ${_command})
    endif()
endforeach()
add_dependencies(otp_seed_host otp_seed_stage)

# Application definitions supply the foundation generator outputs. Defer this
# dependency edge until those rules exist; the generators use only the seed host.
function(otp_finalize_bootstrap)
    set(_foundation "${PROJECT_BINARY_DIR}/bootstrap/foundation.stamp")
    add_custom_command(OUTPUT "${_foundation}"
        COMMAND "${Python3_EXECUTABLE}" "${_otp_bootstrap_tool}" verify
            --source "${PROJECT_SOURCE_DIR}" --generated "${PROJECT_BINARY_DIR}/generated"
        COMMAND ${OTP_SEED_COMMAND} seeds "${OTP_SEED_ROOT}"
            "${_otp_bootstrap}/recipe.term" "${PROJECT_SOURCE_DIR}"
            "${PROJECT_BINARY_DIR}/generated" "${OTP_BUILD_ROOT}"
        COMMAND ${OTP_SEED_COMMAND} script "${_otp_boot_resource}" "${OTP_SEED_ROOT}"
            "${_otp_bootstrap}/boot.script" "${OTP_BUILD_ROOT}/bin/bootstrap.boot"
        COMMAND "${Python3_EXECUTABLE}" "${_otp_bootstrap_tool}" reproduced
            --source "${PROJECT_SOURCE_DIR}" --generated "${PROJECT_BINARY_DIR}/generated"
            --output "${OTP_BUILD_ROOT}"
        COMMAND "${CMAKE_COMMAND}" -E touch "${_foundation}"
        DEPENDS otp_seed_host "${PROJECT_BINARY_DIR}/bootstrap/source-stage.stamp"
            ${_otp_source_inputs} ${_otp_generated_inputs} "${_otp_bootstrap}/manifest.json"
        COMMENT "Reproducing the source-attested OTP compiler foundation" VERBATIM)
    add_custom_target(otp_bootstrap_foundation DEPENDS "${_foundation}")
    add_dependencies(otp_build_host otp_bootstrap_foundation)
    if(BUILD_TESTING)
        add_test(NAME otp-bootstrap-integrity
            COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/check_bootstrap.py"
                --source "${PROJECT_SOURCE_DIR}" --generated "${PROJECT_BINARY_DIR}/generated"
                --root "${OTP_BUILD_ROOT}" --host "$<TARGET_FILE:otp_build_host>"
                --compiler-version "${_compiler_version}" --tools "${_otp_tools}"
                --work "${PROJECT_BINARY_DIR}/checks/bootstrap")
        set_tests_properties(otp-bootstrap-integrity PROPERTIES TIMEOUT 240)
    endif()
    set(_candidates "${PROJECT_BINARY_DIR}/bootstrap/candidates")
    add_custom_target(otp_refresh_bootstrap_seeds
        COMMAND "${CMAKE_COMMAND}" -E rm -rf "${_candidates}"
        COMMAND ${OTP_SEED_COMMAND} seeds "${OTP_SEED_ROOT}"
            "${_otp_bootstrap}/recipe.term" "${PROJECT_SOURCE_DIR}"
            "${PROJECT_BINARY_DIR}/generated" "${_candidates}"
        COMMAND ${OTP_SEED_COMMAND} script "${_otp_boot_resource}" "${OTP_SEED_ROOT}"
            "${_otp_bootstrap}/boot.script" "${_candidates}/bin/bootstrap.boot"
        COMMAND "${Python3_EXECUTABLE}" "${_otp_bootstrap_tool}" candidate
            --source "${PROJECT_SOURCE_DIR}" --generated "${PROJECT_BINARY_DIR}/generated"
            --output "${_candidates}"
        DEPENDS otp_seed_host ${_otp_generated_inputs}
        COMMENT "Writing reviewable OTP bootstrap seed candidates" VERBATIM)
endfunction()
