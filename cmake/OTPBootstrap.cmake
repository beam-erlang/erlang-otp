# Upstream's ordinary bootstrap uses the supplied core compiler throughout.
# Source-built supplementary tools are copied into this single host as needed.
set(OTP_BOOTSTRAP_ROOT "${PROJECT_BINARY_DIR}/bootstrap")
set(OTP_BOOTSTRAP_ERL "${OTP_BOOTSTRAP_ROOT}/bin/erl${CMAKE_EXECUTABLE_SUFFIX}")
set(OTP_BOOTSTRAP_ERLC "${OTP_BOOTSTRAP_ROOT}/bin/erlc${CMAKE_EXECUTABLE_SUFFIX}")
set(OTP_BOOTSTRAP_ESCRIPT "${OTP_BOOTSTRAP_ROOT}/bin/escript${CMAKE_EXECUTABLE_SUFFIX}")
set(OTP_BUILD_ERL "${PROJECT_BINARY_DIR}/bin/erl${CMAKE_EXECUTABLE_SUFFIX}")
set(OTP_VALIDATOR_ROOT "${OTP_INTERNAL_ROOT}/validator")
set(OTP_TOOLS_ROOT "${OTP_BOOTSTRAP_ROOT}/lib/parsetools/ebin")
set(OTP_SECONDARY_APPLICATIONS parsetools sasl asn1)
set(OTP_TERTIARY_APPLICATIONS wx public_key erl_interface syntax_tools snmp)
set(OTP_BOOTSTRAP_HEADER_APPLICATIONS runtime_tools xmerl common_test)
file(MAKE_DIRECTORY "${OTP_INTERNAL_ROOT}/stamps" "${OTP_INTERNAL_ROOT}/commands"
    "${PROJECT_BINARY_DIR}/bin" "${OTP_BOOTSTRAP_ROOT}/bin" "${OTP_COMMAND_BIN}")
file(GENERATE OUTPUT "${OTP_INTERNAL_ROOT}/bootstrap-inetrc"
    CONTENT "{lookup,[file]}.\n{domain,\"beam.test\"}.\n")
include("${CMAKE_CURRENT_LIST_DIR}/OTPApplication.cmake")

if(BEAM_SDK_BUILD_TYPE STREQUAL "Debug")
    set(_otp_runtime_type debug)
    set(_otp_debug_compiled true)
    set(_otp_lock_checking true)
else()
    set(_otp_runtime_type opt)
    set(_otp_debug_compiled false)
    set(_otp_lock_checking false)
endif()
set(_otp_runtime_diagnostics "{${_otp_runtime_type},${_otp_debug_compiled},${_otp_lock_checking}}")
foreach(_key root erts_version otp_release architecture flavor build_type runtime_type)
    if(_key STREQUAL root)
        set(_value "${OTP_BOOTSTRAP_ROOT}")
    elseif(_key STREQUAL erts_version)
        set(_value "${OTP_ERTS_VERSION}")
    elseif(_key STREQUAL otp_release)
        set(_value "${PROJECT_VERSION_MAJOR}")
    elseif(_key STREQUAL architecture)
        set(_value "${BEAM_SDK_HOST_TRIPLE}")
    elseif(_key STREQUAL flavor)
        set(_value "${BEAM_SDK_FLAVOR}")
    elseif(_key STREQUAL build_type)
        set(_value "${BEAM_SDK_BUILD_TYPE}")
    else()
        set(_value "${_otp_runtime_type}")
    endif()
    otp_erlang_string(_${_key} "${_value}")
endforeach()
file(GENERATE OUTPUT "${OTP_INTERNAL_ROOT}/bootstrap-runtime.json" CONTENT
    "{\"root\":${_root},\"erts_version\":${_erts_version},\"otp_release\":${_otp_release},\"architecture\":${_architecture},\"flavor\":${_flavor},\"build_type\":${_build_type},\"runtime_type\":${_runtime_type},\"debug_compiled\":${_otp_debug_compiled},\"lock_checking\":${_otp_lock_checking}}\n")

# These targets are available to application declarations before their concrete
# file rules are completed after all source-local declarations have been read.
foreach(_stage otp_bootstrap_setup otp_secondary_bootstrap_ready otp_bootstrap_ready)
    set(_stamp "${OTP_INTERNAL_ROOT}/stamps/${_stage}.stamp")
    add_custom_target(${_stage} DEPENDS "${_stamp}")
    set_property(TARGET ${_stage} PROPERTY OTP_STAMP "${_stamp}")
endforeach()
foreach(_app IN LISTS OTP_SECONDARY_APPLICATIONS OTP_TERTIARY_APPLICATIONS
        OTP_BOOTSTRAP_HEADER_APPLICATIONS)
    set(_stamp "${OTP_INTERNAL_ROOT}/stamps/otp_bootstrap_${_app}.stamp")
    add_custom_target(otp_bootstrap_${_app} DEPENDS "${_stamp}")
    set_property(TARGET otp_bootstrap_${_app} PROPERTY OTP_STAMP "${_stamp}")
endforeach()

# The VM resolves its child helper in the native bindir. This independent rule
# is required before the very first erlc or Erlang generator process can start.
if(NOT WIN32)
add_custom_command(OUTPUT "${OTP_COMMAND_BIN}/erl_child_setup"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "$<TARGET_FILE:BEAM::ChildSetup>" "${OTP_COMMAND_BIN}/erl_child_setup"
    DEPENDS BEAM::ChildSetup "${PROJECT_BINARY_DIR}/sdk-selection.txt"
    COMMENT "Staging the selected SDK child helper" VERBATIM)
set(_otp_helper_outputs "${OTP_COMMAND_BIN}/erl_child_setup")
if(BEAM_SDK_BUILD_TYPE STREQUAL "Debug")
    # A declared output is regenerated if removed independently of the binary.
    add_custom_command(OUTPUT "${OTP_COMMAND_BIN}/erl_child_setup.debug"
        COMMAND "${CMAKE_COMMAND}" -E rm -f "${OTP_COMMAND_BIN}/erl_child_setup.debug"
        COMMAND "${CMAKE_COMMAND}" -E create_symlink
            erl_child_setup "${OTP_COMMAND_BIN}/erl_child_setup.debug"
        DEPENDS "${OTP_COMMAND_BIN}/erl_child_setup" "${PROJECT_BINARY_DIR}/sdk-selection.txt"
        COMMENT "Staging the Debug child helper alias" VERBATIM)
    list(APPEND _otp_helper_outputs "${OTP_COMMAND_BIN}/erl_child_setup.debug")
else()
    file(REMOVE "${OTP_COMMAND_BIN}/erl_child_setup.debug")
endif()
add_custom_target(otp_native_helpers DEPENDS ${_otp_helper_outputs})
else()
    set(_otp_helper_outputs)
    add_custom_target(otp_native_helpers)
endif()

# Adapt the retained upstream launcher to the binary tree. Quote fixed paths
# as shell assignments so they cannot become shell syntax.
if(NOT WIN32)
function(otp_build_launcher output root inspection)
    set(_input "${PROJECT_SOURCE_DIR}/erts/etc/unix/erl.src.src")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_input}")
    file(READ "${_input}" _contents)
    string(REPLACE "'" "'\"'\"'" _root_shell "${root}")
    string(REPLACE "'" "'\"'\"'" _bindir_shell "${OTP_COMMAND_BIN}")
    string(REPLACE "ROOTDIR=$(find_rootdir \"$0\" \"%FINAL_ROOTDIR%\")"
        "ROOTDIR='${_root_shell}'" _contents "${_contents}")
    string(REPLACE "BINDIR=\"$ROOTDIR/erts-%VSN%/bin\""
        "BINDIR='${_bindir_shell}'" _contents "${_contents}")
    string(REPLACE "%VSN%" "${OTP_ERTS_VERSION}" _contents "${_contents}")
    string(REPLACE "%EMULATOR%" "beam" _contents "${_contents}")
    string(REPLACE "%EMULATOR_NUMBER%" "" _contents "${_contents}")
    if(inspection)
        string(REPLACE "exec \"$BINDIR/erlexec\""
            "exec \"$BINDIR/erlexec\" -pz \"$ROOTDIR/erts/ebin\"" _contents "${_contents}")
    else()
        # Check the selected compiler before ensure_loaded can run its on_load.
        otp_erlang_string(_compiler "${root}/lib/compiler/ebin/compile.beam")
        set(_guard "case {code:which(compile),erlang:system_info(version),erlang:system_info(otp_release),erlang:system_info(system_architecture),erlang:system_info(emu_flavor),{erlang:system_info(build_type),erlang:system_info(debug_compiled),erlang:system_info(lock_checking)}} of {${_compiler},${_erts_version},${_otp_release},${_architecture},${BEAM_SDK_FLAVOR},${_otp_runtime_diagnostics}} -> {module,compile}=code:ensure_loaded(compile),ok; Actual -> io:format(standard_error,\"OTP bootstrap selection mismatch: ~tp~n\",[Actual]),halt(1) end.")
        string(REPLACE "'" "'\"'\"'" _guard_shell "${_guard}")
        string(REPLACE "exec \"$BINDIR/erlexec\""
            "exec \"$BINDIR/erlexec\" -boot \"$ROOTDIR/bin/no_dot_erlang\" +SDcpu 1 +SDio 1 -eval '${_guard_shell}'"
            _contents "${_contents}")
    endif()
    file(CONFIGURE OUTPUT "${output}" CONTENT "${_contents}" @ONLY)
    file(CHMOD "${output}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endfunction()
otp_build_launcher("${OTP_BOOTSTRAP_ROOT}/bin/erl" "${OTP_BOOTSTRAP_ROOT}" FALSE)
otp_build_launcher("${PROJECT_BINARY_DIR}/bin/erl" "${PROJECT_BINARY_DIR}" TRUE)
set(_otp_launcher_inputs "${PROJECT_SOURCE_DIR}/erts/etc/unix/erl.src.src"
    "${OTP_BOOTSTRAP_ERL}")
else()
    # Build-tree ini files deliberately select the installed SDK-linked host.
    # The installed product is finalized separately with its logical prefix.
    foreach(_kind bootstrap product)
        if(_kind STREQUAL bootstrap)
            set(_root "${OTP_BOOTSTRAP_ROOT}")
        else()
            set(_root "${PROJECT_BINARY_DIR}")
        endif()
        file(CONFIGURE OUTPUT "${_root}/bin/erl.ini" CONTENT
            "[erlang]\nBindir=${OTP_COMMAND_BIN}\nRootdir=${_root}\nProgname=erl\n" @ONLY)
        list(APPEND _otp_launcher_inputs "${_root}/bin/erl.ini")
    endforeach()
endif()

# The only local Erlang helper reads Erlang application terms and BEAM chunks.
set(_validator_stamp "${OTP_INTERNAL_ROOT}/stamps/otp_application_validator.stamp")
otp_erlc_command(_validator "${PROJECT_SOURCE_DIR}/cmake" "${OTP_VALIDATOR_ROOT}"
    OPTIONS debug_info SOURCES otp_application_validator.erl)
add_custom_command(OUTPUT "${_validator_stamp}"
    BYPRODUCTS "${OTP_VALIDATOR_ROOT}/otp_application_validator.beam"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_VALIDATOR_ROOT}"
    ${_validator}
    COMMAND "${CMAKE_COMMAND}" -E touch "${_validator_stamp}"
    DEPENDS otp_bootstrap_setup "${OTP_INTERNAL_ROOT}/stamps/otp_bootstrap_setup.stamp"
        "${PROJECT_SOURCE_DIR}/cmake/otp_application_validator.erl" ${_validator_INPUTS}
        "${OTP_INTERNAL_ROOT}/bootstrap-runtime.json"
    COMMENT "Compiling the application validator with bootstrap erlc" VERBATIM)
add_custom_target(otp_application_validator DEPENDS "${_validator_stamp}")
set_property(TARGET otp_application_validator PROPERTY OTP_STAMP "${_validator_stamp}")

function(otp_bootstrap_copy app)
    if(app MATCHES "^(kernel|stdlib|compiler)$")
        message(FATAL_ERROR "The supplied ${app} bootstrap must not be replaced")
    endif()
    cmake_parse_arguments(B "HEADERS_ONLY" "" "" ${ARGN})
    set(_deps otp_bootstrap_setup "${OTP_INTERNAL_ROOT}/stamps/otp_bootstrap_setup.stamp")
    if(TARGET otp_headers_${app})
        get_target_property(_header_stamp otp_headers_${app} OTP_STAMP)
        list(APPEND _deps otp_headers_${app} "${_header_stamp}")
    endif()
    set(_beams)
    if(NOT B_HEADERS_ONLY)
        get_target_property(_beams otp_app_${app} OTP_BEAM_OUTPUTS)
        if(NOT _beams)
            set(_beams)
        endif()
        get_target_property(_app_stamp otp_app_${app} OTP_STAMP)
        list(APPEND _deps otp_app_${app} "${_app_stamp}" ${_beams})
    endif()
    file(GLOB _headers CONFIGURE_DEPENDS
        "${PROJECT_SOURCE_DIR}/lib/${app}/include/*.hrl"
        "${PROJECT_SOURCE_DIR}/lib/${app}/include/*.h")
    if(TARGET otp_app_${app})
        get_target_property(_public_headers otp_app_${app} OTP_PUBLIC_HEADERS)
        if(_public_headers)
            list(APPEND _headers ${_public_headers})
        endif()
    endif()
    list(REMOVE_DUPLICATES _headers)
    set(_outputs)
    foreach(_beam IN LISTS _beams)
        get_filename_component(_name "${_beam}" NAME)
        list(APPEND _outputs "${OTP_BOOTSTRAP_ROOT}/lib/${app}/ebin/${_name}")
    endforeach()
    foreach(_header IN LISTS _headers)
        get_filename_component(_name "${_header}" NAME)
        list(APPEND _outputs "${OTP_BOOTSTRAP_ROOT}/lib/${app}/include/${_name}")
    endforeach()
    set(_stamp "${OTP_INTERNAL_ROOT}/stamps/otp_bootstrap_${app}.stamp")
    otp_staging_command(_copy "${OTP_BOOTSTRAP_ROOT}" "${OTP_INTERNAL_ROOT}/bootstrap-${app}.json"
        SOURCES ${_beams} ${_headers} OUTPUTS ${_outputs})
    add_custom_command(OUTPUT "${_stamp}" BYPRODUCTS ${_outputs}
        ${_copy}
        COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
        DEPENDS ${_deps} ${_headers} ${_copy_INPUTS}
        COMMENT "Copying ${app} into the bootstrap host" VERBATIM)
endfunction()

function(otp_boot_family target output)
    cmake_parse_arguments(B "LOCAL" "" "DEPENDS" ${ARGN})
    otp_application_version(kernel _kernel)
    otp_application_version(stdlib _stdlib)
    otp_application_version(sasl _sasl)
    otp_application_version(os_mon _os_mon)
    otp_application_version(inets _inets)
    otp_application_version(mnesia _mnesia)
    otp_application_version(snmp _snmp)
    set(_commands COMMAND "${CMAKE_COMMAND}" -E make_directory "${output}")
    set(_command_inputs)
    set(_outputs)
    set(_names start_clean no_dot_erlang start_sasl)
    if(NOT B_LOCAL)
        list(APPEND _names start_all_example)
    endif()
    foreach(_name IN LISTS _names)
        set(_input "${PROJECT_SOURCE_DIR}/erts/start_scripts/${_name}.rel.src")
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_input}")
        file(READ "${_input}" _contents)
        foreach(_pair "SYS;${PROJECT_VERSION_MAJOR}" "ERTS;${OTP_ERTS_VERSION}"
                "KERNEL;${_kernel}" "STDLIB;${_stdlib}" "SASL;${_sasl}"
                "OS_MON;${_os_mon}" "INETS;${_inets}" "MNESIA;${_mnesia}" "SNMP;${_snmp}")
            list(GET _pair 0 _key)
            list(GET _pair 1 _value)
            string(REPLACE "%${_key}_VSN%" "${_value}" _contents "${_contents}")
        endforeach()
        otp_cmake_literal(_rel "${output}/${_name}.rel")
        otp_cmake_literal(_contents "${_contents}")
        set(_write "${OTP_INTERNAL_ROOT}/commands/${target}-${_name}.cmake")
        file(GENERATE OUTPUT "${_write}" CONTENT "file(WRITE ${_rel} ${_contents})\n")
        list(APPEND _commands COMMAND "${CMAKE_COMMAND}" -P "${_write}")
        list(APPEND _command_inputs "${_write}")
        list(APPEND _outputs "${output}/${_name}.rel")
        list(APPEND B_DEPENDS "${_input}")
        if(_name STREQUAL start_all_example)
            # The original ships this release example without a boot script.
            continue()
        endif()
        set(_flags)
        foreach(_app kernel stdlib sasl)
            list(APPEND _flags -I "${PROJECT_BINARY_DIR}/lib/${_app}/ebin")
        endforeach()
        if(B_LOCAL)
            list(APPEND _flags +otp_build)
        endif()
        if(NOT _name STREQUAL start_sasl)
            list(APPEND _flags +no_warn_sasl)
        endif()
        if(_name STREQUAL no_dot_erlang)
            list(APPEND _flags +no_dot_erlang)
        endif()
        otp_command(_compile "${PROJECT_BINARY_DIR}" "${OTP_BOOTSTRAP_ERLC}"
            -no-server ${_flags} -o "${output}/${_name}.script" "${output}/${_name}.rel")
        list(APPEND _commands ${_compile})
        list(APPEND _command_inputs ${_compile_INPUTS})
        foreach(_ext script boot)
            list(APPEND _outputs "${output}/${_name}.${_ext}")
        endforeach()
    endforeach()
    foreach(_extension boot script)
        list(APPEND _commands COMMAND "${CMAKE_COMMAND}" -E copy
            "${output}/start_clean.${_extension}" "${output}/start.${_extension}")
    endforeach()
    list(APPEND _outputs "${output}/start.boot" "${output}/start.script")
    set(_stamp "${OTP_INTERNAL_ROOT}/stamps/${target}.stamp")
    add_custom_command(OUTPUT "${_stamp}" BYPRODUCTS ${_outputs}
        ${_commands}
        COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
        DEPENDS ${B_DEPENDS} ${_command_inputs} otp_bootstrap_ready
            "${OTP_INTERNAL_ROOT}/stamps/otp_bootstrap_ready.stamp"
            "${PROJECT_SOURCE_DIR}/otp_versions.table" "${PROJECT_SOURCE_DIR}/OTP_VERSION"
        COMMENT "Generating ${target}" VERBATIM)
    add_custom_target(${target} DEPENDS "${_stamp}")
    set_property(TARGET ${target} PROPERTY OTP_STAMP "${_stamp}")
endfunction()

function(otp_complete_distribution)
    file(GLOB_RECURSE _fixture_inputs CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/bootstrap/*")
    set(_fixture_outputs)
    foreach(_input IN LISTS _fixture_inputs)
        file(RELATIVE_PATH _relative "${PROJECT_SOURCE_DIR}/bootstrap" "${_input}")
        list(APPEND _fixture_outputs "${OTP_BOOTSTRAP_ROOT}/${_relative}")
    endforeach()
    # Explicit include roots prefer the source-shaped header mirrors. Refresh
    # core public headers before any compiler/generator can observe those paths.
    set(_core_headers)
    foreach(_app kernel stdlib compiler)
        get_target_property(_header_stamp otp_headers_${_app} OTP_STAMP)
        list(APPEND _core_headers otp_headers_${_app} "${_header_stamp}")
    endforeach()
    set(_setup_stamp "${OTP_INTERNAL_ROOT}/stamps/otp_bootstrap_setup.stamp")
    otp_staging_command(_fixture "${OTP_BOOTSTRAP_ROOT}" "${OTP_INTERNAL_ROOT}/bootstrap-fixture.json"
        SOURCES ${_fixture_inputs} OUTPUTS ${_fixture_outputs})
    set(_bootstrap_launcher_commands)
    set(_bootstrap_launcher_outputs)
    if(WIN32)
        list(APPEND _bootstrap_launcher_commands
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:otp_erl>" "${OTP_BOOTSTRAP_ERL}")
        list(APPEND _bootstrap_launcher_outputs "${OTP_BOOTSTRAP_ERL}")
        set(_bootstrap_launcher_target otp_erl)
    endif()
    add_custom_command(OUTPUT "${_setup_stamp}"
        BYPRODUCTS ${_fixture_outputs} "${OTP_BOOTSTRAP_ERLC}"
            "${OTP_BOOTSTRAP_ESCRIPT}" "${OTP_BOOTSTRAP_ROOT}/bin/${OTP_TARGET}/inet_gethost${CMAKE_EXECUTABLE_SUFFIX}"
            ${_bootstrap_launcher_outputs}
        ${_fixture}
        ${_bootstrap_launcher_commands}
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:otp_erlc>" "${OTP_BOOTSTRAP_ERLC}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:otp_escript>" "${OTP_BOOTSTRAP_ESCRIPT}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${OTP_BOOTSTRAP_ROOT}/bin/${OTP_TARGET}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:otp_inet_gethost>"
            "${OTP_BOOTSTRAP_ROOT}/bin/${OTP_TARGET}/inet_gethost${CMAKE_EXECUTABLE_SUFFIX}"
        COMMAND "${CMAKE_COMMAND}" -E touch "${_setup_stamp}"
        DEPENDS ${_fixture_inputs} ${_core_headers}
            otp_emulator otp_erlexec otp_erlc otp_escript otp_inet_gethost
            otp_native_helpers ${_otp_helper_outputs} ${_bootstrap_launcher_target}
            ${_fixture_INPUTS}
            ${_otp_launcher_inputs} "${OTP_INTERNAL_ROOT}/bootstrap-runtime.json"
            "${PROJECT_BINARY_DIR}/sdk-selection.txt"
        COMMENT "Preparing the supplied bootstrap with fresh OTP launchers" VERBATIM)

    file(GLOB_RECURSE _sdk_ebin CONFIGURE_DEPENDS "${BEAM_SDK_PRELOAD_EBIN_DIR}/*")
    file(GLOB_RECURSE _sdk_src CONFIGURE_DEPENDS "${BEAM_SDK_PRELOAD_SOURCE_DIR}/*")
    set(_sdk_outputs)
    foreach(_input IN LISTS _sdk_ebin)
        file(RELATIVE_PATH _relative "${BEAM_SDK_PRELOAD_EBIN_DIR}" "${_input}")
        list(APPEND _sdk_outputs "${PROJECT_BINARY_DIR}/erts/ebin/${_relative}")
    endforeach()
    foreach(_input IN LISTS _sdk_src)
        file(RELATIVE_PATH _relative "${BEAM_SDK_PRELOAD_SOURCE_DIR}" "${_input}")
        list(APPEND _sdk_outputs "${PROJECT_BINARY_DIR}/erts/preloaded/src/${_relative}")
    endforeach()
    set(_preloads_stamp "${OTP_INTERNAL_ROOT}/stamps/otp_sdk_preloads.stamp")
    otp_staging_command(_preloads "${PROJECT_BINARY_DIR}" "${OTP_INTERNAL_ROOT}/sdk-preloads.json"
        SOURCES ${_sdk_ebin} ${_sdk_src} OUTPUTS ${_sdk_outputs})
    add_custom_command(OUTPUT "${_preloads_stamp}" BYPRODUCTS ${_sdk_outputs}
        ${_preloads}
        COMMAND "${CMAKE_COMMAND}" -E touch "${_preloads_stamp}"
        DEPENDS ${_sdk_ebin} ${_sdk_src} ${_preloads_INPUTS}
            "${PROJECT_BINARY_DIR}/sdk-selection.txt"
        COMMENT "Staging SDK-owned preload inspection assets" VERBATIM)
    add_custom_target(otp_sdk_preloads DEPENDS "${_preloads_stamp}")
    set_property(TARGET otp_sdk_preloads PROPERTY OTP_STAMP "${_preloads_stamp}")

    foreach(_app IN LISTS OTP_SECONDARY_APPLICATIONS OTP_TERTIARY_APPLICATIONS)
        otp_bootstrap_copy("${_app}")
    endforeach()
    foreach(_app IN LISTS OTP_BOOTSTRAP_HEADER_APPLICATIONS)
        otp_bootstrap_copy("${_app}" HEADERS_ONLY)
    endforeach()
    foreach(_stage secondary complete)
        if(_stage STREQUAL secondary)
            set(_apps ${OTP_SECONDARY_APPLICATIONS})
            set(_target otp_secondary_bootstrap_ready)
        else()
            set(_apps ${OTP_TERTIARY_APPLICATIONS} ${OTP_BOOTSTRAP_HEADER_APPLICATIONS})
            set(_target otp_bootstrap_ready)
        endif()
        set(_deps)
        foreach(_app IN LISTS _apps)
            list(APPEND _deps otp_bootstrap_${_app} "${OTP_INTERNAL_ROOT}/stamps/otp_bootstrap_${_app}.stamp")
        endforeach()
        if(_stage STREQUAL complete)
            list(APPEND _deps otp_secondary_bootstrap_ready
                "${OTP_INTERNAL_ROOT}/stamps/otp_secondary_bootstrap_ready.stamp")
        endif()
        set(_stamp "${OTP_INTERNAL_ROOT}/stamps/${_target}.stamp")
        add_custom_command(OUTPUT "${_stamp}"
            COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
            DEPENDS ${_deps} COMMENT "Completing ${_target}" VERBATIM)
    endforeach()

    set(_product_targets)
    set(_product_stamps)
    foreach(_app IN LISTS OTP_APPLICATIONS)
        list(APPEND _product_targets otp_app_${_app})
        get_target_property(_stamp otp_app_${_app} OTP_STAMP)
        list(APPEND _product_stamps "${_stamp}")
    endforeach()
    otp_boot_family(otp_product_boot "${PROJECT_BINARY_DIR}/erts/start_scripts" DEPENDS ${_product_stamps})
    otp_boot_family(otp_local_boot "${PROJECT_BINARY_DIR}/bin" LOCAL DEPENDS ${_product_stamps})
    otp_erlang_string(_release "${PROJECT_BINARY_DIR}/erts/start_scripts/start_sasl.rel")
    otp_erlang_string(_scripts "${PROJECT_BINARY_DIR}/erts/start_scripts")
    otp_erlang_string(_index "${PROJECT_BINARY_DIR}/erts/start_scripts/RELEASES.src")
    set(_expression "ok=release_handler:create_RELEASES(\"%ERL_ROOT%\",${_scripts},${_release},[]),ok=file:rename(filename:join(${_scripts},\"RELEASES\"),${_index}),halt().")
    otp_command(_release_index "${PROJECT_BINARY_DIR}" "${OTP_BOOTSTRAP_ERL}"
        +S 2:2 -noshell -noinput -pa "${OTP_BOOTSTRAP_ROOT}/lib/sasl/ebin" -eval "${_expression}")
    otp_generator(TARGET otp_release_index COMMANDS ${_release_index}
        OUTPUTS "${PROJECT_BINARY_DIR}/erts/start_scripts/RELEASES.src"
        DEPENDS otp_product_boot ${_release_index_INPUTS})

    set(_local_copies)
    set(_local_commands erlc escript ct_run dialyzer typer erl_call epmd)
    if(WIN32)
        list(APPEND _local_commands erl)
    endif()
    foreach(_command IN LISTS _local_commands)
        set(_target otp_${_command})
        if(TARGET ${_target})
            set(_output "${PROJECT_BINARY_DIR}/bin/${_command}${CMAKE_EXECUTABLE_SUFFIX}")
            add_custom_command(OUTPUT "${_output}"
                COMMAND "${CMAKE_COMMAND}" -E copy_if_different "$<TARGET_FILE:${_target}>" "${_output}"
                DEPENDS ${_target} COMMENT "Publishing the local ${_command} command" VERBATIM)
            list(APPEND _local_copies "${_output}")
        endif()
    endforeach()
    # Retire only recognized files from the former build graph, after every
    # application has migrated its prior build record. Never sweep a directory.
    get_property(_retired GLOBAL PROPERTY OTP_RETIRED_BUILD_FILES)
    list(APPEND _retired "${OTP_INTERNAL_ROOT}/driver/otp_build_driver.beam"
        "${OTP_INTERNAL_ROOT}/driver/otp_generators.beam"
        "${OTP_INTERNAL_ROOT}/stamps/otp_build_driver.stamp")
    file(GLOB _old_arguments "${OTP_INTERNAL_ROOT}/commands/*.json")
    foreach(_file IN LISTS _old_arguments)
        get_filename_component(_name "${_file}" NAME_WE)
        string(LENGTH "${_name}" _length)
        if(_length EQUAL 64 AND _name MATCHES "^[0-9a-f]+$")
            file(READ "${_file}" _arguments)
            string(JSON _type ERROR_VARIABLE _error TYPE "${_arguments}")
            if(NOT _error AND _type STREQUAL ARRAY)
                string(JSON _first ERROR_VARIABLE _error GET "${_arguments}" 0)
                if(NOT _error AND _first STREQUAL "-o")
                    string(JSON _out ERROR_VARIABLE _error GET "${_arguments}" 1)
                    cmake_path(IS_PREFIX PROJECT_BINARY_DIR "${_out}" NORMALIZE _owned)
                    if(NOT _error AND _owned)
                        list(APPEND _retired "${_file}")
                    endif()
                endif()
            endif()
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _retired)
    set(_cleanup_contents "file(REMOVE")
    foreach(_file IN LISTS _retired)
        otp_cmake_literal(_file "${_file}")
        string(APPEND _cleanup_contents " ${_file}")
    endforeach()
    string(APPEND _cleanup_contents ")\n")
    set(_cleanup "${OTP_INTERNAL_ROOT}/commands/retire-build-helpers.cmake")
    file(GENERATE OUTPUT "${_cleanup}" CONTENT "${_cleanup_contents}")
    set(_cleanup_stamp "${OTP_INTERNAL_ROOT}/stamps/otp_retire_build_helpers.stamp")
    add_custom_command(OUTPUT "${_cleanup_stamp}"
        COMMAND "${CMAKE_COMMAND}" -P "${_cleanup}"
        COMMAND "${CMAKE_COMMAND}" -E touch "${_cleanup_stamp}"
        DEPENDS ${_product_stamps} "${_cleanup}"
        COMMENT "Retiring superseded CMake-owned build helper outputs" VERBATIM)
    add_custom_target(otp_retire_build_helpers DEPENDS "${_cleanup_stamp}")
    add_custom_target(otp_local_setup DEPENDS otp_local_boot otp_sdk_preloads ${_local_copies}
        "${OTP_BUILD_ERL}")
    add_custom_target(otp_applications ALL DEPENDS otp_release_index otp_local_setup
        otp_retire_build_helpers ${_product_targets})
endfunction()
