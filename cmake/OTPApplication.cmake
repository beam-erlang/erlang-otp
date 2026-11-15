# Shared execution mechanics. Source selections and product rules belong to applications.
include(CMakeParseArguments)
include("${CMAKE_CURRENT_LIST_DIR}/OTPExecution.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/OTPStaging.cmake")

function(otp_erlang_string output value)
    string(REPLACE "\\" "\\\\" _value "${value}")
    string(REPLACE "\"" "\\\"" _value "${_value}")
    string(REPLACE "\n" "\\n" _value "${_value}")
    string(REPLACE "\r" "\\r" _value "${_value}")
    string(REPLACE "\t" "\\t" _value "${_value}")
    set(${output} "\"${_value}\"" PARENT_SCOPE)
endfunction()

function(otp_erlang_strings output)
    set(_values)
    foreach(_value IN LISTS ARGN)
        otp_erlang_string(_quoted "${_value}")
        list(APPEND _values "${_quoted}")
    endforeach()
    string(JOIN "," _values ${_values})
    set(${output} "[${_values}]" PARENT_SCOPE)
endfunction()

# Generator processes use the supplied bootstrap host. Each rule declares the
# copied tools it executes; application order is not an implicit dependency.
function(otp_dependency_stamps output)
    set(_files)
    foreach(_dependency IN LISTS ARGN)
        if(TARGET "${_dependency}")
            get_target_property(_stamp "${_dependency}" OTP_STAMP)
            if(_stamp)
                list(APPEND _files "${_stamp}")
            endif()
        elseif(_dependency MATCHES "^otp_(bootstrap_.*|secondary_bootstrap_ready|headers_.*|application_validator)$")
            # Copy targets are completed after the source-local declarations.
            # Retain file freshness as well as their target-level ordering.
            list(APPEND _files "${OTP_INTERNAL_ROOT}/stamps/${_dependency}.stamp")
        endif()
    endforeach()
    set(${output} "${_files}" PARENT_SCOPE)
endfunction()

function(otp_generator)
    cmake_parse_arguments(J "" "TARGET" "COMMANDS;OUTPUTS;DEPENDS" ${ARGN})
    if(J_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognized generator arguments: ${J_UNPARSED_ARGUMENTS}")
    endif()
    set(_deps otp_bootstrap_setup ${J_DEPENDS})
    otp_dependency_stamps(_dependency_files ${_deps})
    set(_stamp "${OTP_INTERNAL_ROOT}/stamps/${J_TARGET}.stamp")
    set_property(GLOBAL APPEND PROPERTY OTP_RETIRED_BUILD_FILES
        "${OTP_INTERNAL_ROOT}/build-jobs/${J_TARGET}.term")
    set(_directories)
    foreach(_output IN LISTS J_OUTPUTS)
        get_filename_component(_directory "${_output}" DIRECTORY)
        list(APPEND _directories "${_directory}")
    endforeach()
    list(REMOVE_DUPLICATES _directories)
    add_custom_command(OUTPUT "${_stamp}"
        BYPRODUCTS ${J_OUTPUTS}
        COMMAND "${CMAKE_COMMAND}" -E make_directory ${_directories}
        ${J_COMMANDS}
        COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
        DEPENDS ${_deps} ${_dependency_files}
        COMMENT "Generating ${J_TARGET}" VERBATIM)
    add_custom_target(${J_TARGET} DEPENDS "${_stamp}")
    set_property(TARGET ${J_TARGET} PROPERTY OTP_STAMP "${_stamp}")
endfunction()

# One invocation executes one freshly built erlc. Paths are given in
# lookup order; -pa prepends each directory, so emit them in reverse order.
function(otp_erlc_command output directory out)
    cmake_parse_arguments(C "" "" "FLAGS;OPTIONS;PATHS;SOURCES" ${ARGN})
    set(_paths ${C_PATHS})
    list(REVERSE _paths)
    set(_args -o "${out}" ${C_FLAGS})
    foreach(_path IN LISTS _paths)
        list(APPEND _args -pa "${_path}")
    endforeach()
    foreach(_option IN LISTS C_OPTIONS)
        list(APPEND _args "+${_option}")
    endforeach()
    list(APPEND _args ${C_SOURCES})
    otp_command(_command "${directory}" "${OTP_BOOTSTRAP_ERLC}" -no-server ${_args})
    set(${output} "${_command}" PARENT_SCOPE)
    set(${output}_INPUTS "${_command_INPUTS}" PARENT_SCOPE)
endfunction()

# CMake owns source order and option grouping. Only adjacent sources with the
# same directory/options share an erlc process; no source selection runs in Python.
function(otp_erlang_compile_commands output)
    cmake_parse_arguments(C "OWN_CODE_PATH" "APP;OUT;GENERATED;SELF_TRANSFORM"
        "SOURCES;OPTIONS;PATHS" ${ARGN})
    set(_source_dirs)
    foreach(_source IN LISTS C_SOURCES)
        get_filename_component(_directory "${_source}" DIRECTORY)
        list(APPEND _source_dirs "${_directory}")
    endforeach()
    list(REMOVE_DUPLICATES _source_dirs)
    list(SORT _source_dirs)
    set(_includes "${C_GENERATED}" "${PROJECT_BINARY_DIR}/lib" "${PROJECT_SOURCE_DIR}/lib")
    foreach(_app kernel stdlib compiler parsetools)
        list(APPEND _includes "${PROJECT_SOURCE_DIR}/lib/${_app}/src" "${PROJECT_SOURCE_DIR}/lib/${_app}/include")
    endforeach()
    list(APPEND _includes ${_source_dirs} "${PROJECT_BINARY_DIR}/lib/${C_APP}/include"
        "${PROJECT_SOURCE_DIR}/lib/${C_APP}/src" "${PROJECT_SOURCE_DIR}/lib/${C_APP}/include")
    list(REMOVE_DUPLICATES _includes)
    set(_base debug_info)
    foreach(_include IN LISTS _includes)
        otp_erlang_string(_term "${_include}")
        list(APPEND _base "{i,${_term}}")
    endforeach()
    set(_paths ${C_PATHS})
    if(C_OWN_CODE_PATH)
        list(PREPEND _paths "${C_OUT}")
    endif()
    set(_commands COMMAND "${CMAKE_COMMAND}" -E make_directory "${C_OUT}")
    set(_inputs)
    set(_batch_sources)
    set(_batch_options)
    set(_batch_directory)
    foreach(_source IN LISTS C_SOURCES)
        get_filename_component(_directory "${_source}" DIRECTORY)
        get_filename_component(_basename "${_source}" NAME)
        get_filename_component(_module "${_source}" NAME_WE)
        get_source_file_property(_specific "${_source}" OTP_COMPILE_OPTIONS)
        if(NOT _specific)
            set(_specific)
        endif()
        set(_options ${_specific} ${_base} ${C_OPTIONS})
        if(_batch_sources AND (NOT _directory STREQUAL _batch_directory OR
                NOT "${_options}" STREQUAL "${_batch_options}" OR _module STREQUAL C_SELF_TRANSFORM))
            otp_erlc_command(_command "${_batch_directory}" "${C_OUT}"
                OPTIONS ${_batch_options} PATHS ${_paths} SOURCES ${_batch_sources})
            list(APPEND _commands ${_command})
            list(APPEND _inputs ${_command_INPUTS})
            set(_batch_sources)
        endif()
        if(_module STREQUAL C_SELF_TRANSFORM)
            set(_bootstrap "${OTP_INTERNAL_ROOT}/${C_APP}/transform-bootstrap")
            list(APPEND _commands COMMAND "${CMAKE_COMMAND}" -E make_directory "${_bootstrap}")
            otp_erlc_command(_command "${_directory}" "${_bootstrap}"
                OPTIONS "{d,'MERL_NO_TRANSFORM'}" ${_options} PATHS ${_paths} SOURCES "${_basename}")
            list(APPEND _commands ${_command})
            list(APPEND _inputs ${_command_INPUTS})
            otp_erlc_command(_command "${_directory}" "${C_OUT}"
                OPTIONS ${_options} PATHS "${_bootstrap}" "${C_OUT}" ${_paths} SOURCES "${_basename}")
            list(APPEND _commands ${_command})
            list(APPEND _inputs ${_command_INPUTS})
        else()
            set(_batch_directory "${_directory}")
            set(_batch_options ${_options})
            list(APPEND _batch_sources "${_basename}")
        endif()
    endforeach()
    if(_batch_sources)
        otp_erlc_command(_command "${_batch_directory}" "${C_OUT}"
            OPTIONS ${_batch_options} PATHS ${_paths} SOURCES ${_batch_sources})
        list(APPEND _commands ${_command})
        list(APPEND _inputs ${_command_INPUTS})
    endif()
    set(${output} "${_commands}" PARENT_SCOPE)
    set(${output}_INPUTS "${_inputs}" PARENT_SCOPE)
endfunction()

function(otp_add_compile_job)
    cmake_parse_arguments(C "OWN_CODE_PATH" "TARGET;APP;OUT;GENERATED;STAGE"
        "SOURCES;OPTIONS;PATHS;DEPENDS" ${ARGN})
    if(C_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognized compile job arguments: ${C_UNPARSED_ARGUMENTS}")
    endif()
    set(_own)
    if(C_OWN_CODE_PATH)
        set(_own OWN_CODE_PATH)
    endif()
    otp_erlang_compile_commands(_commands APP "${C_APP}" OUT "${C_OUT}" GENERATED "${C_GENERATED}"
        SOURCES ${C_SOURCES} OPTIONS ${C_OPTIONS} PATHS ${C_PATHS} ${_own})
    set(_outputs)
    foreach(_source IN LISTS C_SOURCES)
        get_filename_component(_module "${_source}" NAME_WE)
        list(APPEND _outputs "${C_OUT}/${_module}.beam")
    endforeach()
    set(_stamp "${OTP_INTERNAL_ROOT}/stamps/${C_TARGET}.stamp")
    if(NOT C_STAGE)
        set(C_STAGE otp_bootstrap_ready)
    endif()
    set(_deps ${C_STAGE} otp_erlc ${C_DEPENDS})
    otp_dependency_stamps(_dependency_files ${_deps})
    add_custom_command(OUTPUT "${_stamp}" BYPRODUCTS ${_outputs}
        ${_commands}
        COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
        DEPENDS ${C_SOURCES} ${_deps} ${_dependency_files} ${_commands_INPUTS}
        COMMENT "Compiling ${C_TARGET} with erlc" VERBATIM)
    add_custom_target(${C_TARGET} DEPENDS "${_stamp}")
    set_target_properties(${C_TARGET} PROPERTIES OTP_STAMP "${_stamp}" OTP_BEAM_OUTPUTS "${_outputs}")
endfunction()

# Public build-tree headers have a separate owner from generated application
# headers and from the immutable copied bootstrap fixture.
function(otp_stage_public_headers app)
    set(_source "${PROJECT_SOURCE_DIR}/lib/${app}/include")
    set(_out "${PROJECT_BINARY_DIR}/lib/${app}/include")
    file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${_source}/*.hrl" "${_source}/*.h")
    set(_outputs)
    foreach(_header IN LISTS _headers)
        file(RELATIVE_PATH _relative "${_source}" "${_header}")
        list(APPEND _outputs "${_out}/${_relative}")
    endforeach()
    otp_staging_command(_copy "${_out}" "${OTP_INTERNAL_ROOT}/headers-${app}.json"
        SOURCES ${_headers} OUTPUTS ${_outputs})
    set(_stamp "${OTP_INTERNAL_ROOT}/stamps/otp_headers_${app}.stamp")
    set_property(GLOBAL APPEND PROPERTY OTP_RETIRED_BUILD_FILES
        "${OTP_INTERNAL_ROOT}/build-jobs/otp_headers_${app}.list")
    add_custom_command(OUTPUT "${_stamp}" BYPRODUCTS ${_outputs}
        ${_copy}
        COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
        DEPENDS ${_headers} ${_copy_INPUTS}
        COMMENT "Staging ${app} public headers" VERBATIM)
    add_custom_target(otp_headers_${app} DEPENDS "${_stamp}")
    set_target_properties(otp_headers_${app} PROPERTIES OTP_STAMP "${_stamp}"
        OTP_HEADER_OUTPUTS "${_outputs}")
endfunction()

function(otp_add_application)
    cmake_parse_arguments(A "OWN_CODE_PATH;NO_SOURCE_INSTALL;NO_INCLUDE_INSTALL;NO_SOURCE_SUPPORT_INSTALL;PRESERVE_SOURCE_LAYOUT"
        "APP;RESOURCE_DIR;SELF_TRANSFORM"
        "SOURCES;OPTIONS;DEPENDS;INPUTS;SUBSTITUTIONS" ${ARGN})
    if(A_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognized ${A_APP} application arguments: ${A_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT A_APP IN_LIST OTP_APPLICATIONS)
        return()
    endif()
    otp_application_version("${A_APP}" _version)
    set(_app_source "${PROJECT_SOURCE_DIR}/lib/${A_APP}")
    if(NOT A_RESOURCE_DIR)
        set(A_RESOURCE_DIR "${_app_source}/src")
    endif()
    set(_sources)
    set(_modules)
    foreach(_source IN LISTS A_SOURCES)
        get_filename_component(_source "${_source}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        get_filename_component(_module "${_source}" NAME_WE)
        if(_module IN_LIST _modules)
            message(FATAL_ERROR "Duplicate module ${_module} in ${A_APP}")
        endif()
        list(APPEND _modules "${_module}")
        list(APPEND _sources "${_source}")
    endforeach()
    file(GLOB_RECURSE _support CONFIGURE_DEPENDS
        "${_app_source}/*.hrl" "${_app_source}/*.yrl" "${_app_source}/*.asn1"
        "${_app_source}/*.asn1config" "${_app_source}/*.asn" "${_app_source}/*.funcs"
        "${_app_source}/*.erlsrc" "${_app_source}/*.app.src" "${_app_source}/*.appup.src"
        "${_app_source}/*.txt" "${_app_source}/*.src" "${_app_source}/*.conf"
        "${_app_source}/*.pl" "${_app_source}/*.sed" "${_app_source}/*.escript")
    set(_generated "${PROJECT_BINARY_DIR}/lib/${A_APP}/src")
    file(MAKE_DIRECTORY "${_generated}")
    otp_stage_public_headers("${A_APP}")
    set(_out "${PROJECT_BINARY_DIR}/lib/${A_APP}/ebin")
    # Source generators can use an application's code path before its first
    # compilation job, while the selected bootstrap remains the compiler host.
    file(MAKE_DIRECTORY "${_out}")
    set(_target "otp_app_${A_APP}")
    set_property(GLOBAL APPEND PROPERTY OTP_RETIRED_BUILD_FILES
        "${OTP_INTERNAL_ROOT}/build-jobs/${_target}.term")
    if(A_APP MATCHES "^(parsetools|sasl|asn1)$")
        set(_stage otp_bootstrap_setup)
    elseif(A_APP MATCHES "^(wx|public_key|erl_interface|syntax_tools|snmp)$")
        set(_stage otp_secondary_bootstrap_ready)
    else()
        set(_stage otp_bootstrap_ready)
    endif()
    set(_outputs "${_out}/${A_APP}.app" "${_out}/${A_APP}.appup" "${_out}/build.term")
    set(_beams)
    foreach(_module IN LISTS _modules)
        list(APPEND _beams "${_out}/${_module}.beam")
    endforeach()
    list(APPEND _outputs ${_beams})
    if(A_SELF_TRANSFORM)
        list(APPEND _outputs "${OTP_INTERNAL_ROOT}/${A_APP}/transform-bootstrap/${A_SELF_TRANSFORM}.beam")
    endif()
    otp_staging_command(_prune "${_out}" "${OTP_INTERNAL_ROOT}/application-${A_APP}.json"
        PRUNE_ONLY OUTPUTS ${_beams})
    otp_command(_migrate "${PROJECT_BINARY_DIR}" "${OTP_BOOTSTRAP_ERL}"
        +S 2:2 -noshell -noinput -pa "${OTP_VALIDATOR_ROOT}"
        -s otp_application_validator migrate -extra "${_out}"
        "${OTP_INTERNAL_ROOT}/application-${A_APP}.json")
    list(GET _migrate_INPUTS 0 _migration_script)
    list(GET _prune_INPUTS 0 _prune_script)
    otp_cmake_literal(_migration_script "${_migration_script}")
    otp_cmake_literal(_prune_script "${_prune_script}")
    otp_cmake_literal(_receipt "${OTP_INTERNAL_ROOT}/application-${A_APP}.json")
    otp_cmake_literal(_previous_record "${_out}/build.term")
    set(_prepare "${OTP_INTERNAL_ROOT}/commands/${_target}-prepare.cmake")
    file(GENERATE OUTPUT "${_prepare}" CONTENT
        "if(NOT EXISTS ${_receipt} AND EXISTS ${_previous_record})\n  include(${_migration_script})\nendif()\ninclude(${_prune_script})\n")
    set(_substitutions "%VSN%" "${_version}" ${A_SUBSTITUTIONS})
    list(LENGTH _substitutions _substitution_count)
    math(EXPR _odd "${_substitution_count} % 2")
    if(_odd)
        message(FATAL_ERROR "Application substitutions must be key/value pairs: ${A_APP}")
    endif()
    math(EXPR _last_substitution "${_substitution_count} - 1")
    set(_metadata_contents "")
    foreach(_extension .app .appup)
        otp_cmake_literal(_input "${A_RESOURCE_DIR}/${A_APP}${_extension}.src")
        otp_cmake_literal(_output "${_out}/${A_APP}${_extension}")
        string(APPEND _metadata_contents "file(READ ${_input} _contents)\n")
        foreach(_index RANGE 0 ${_last_substitution} 2)
            math(EXPR _next "${_index} + 1")
            list(GET _substitutions ${_index} _key)
            list(GET _substitutions ${_next} _value)
            otp_cmake_literal(_key "${_key}")
            otp_cmake_literal(_value "${_value}")
            string(APPEND _metadata_contents "string(REPLACE ${_key} ${_value} _contents \"\${_contents}\")\n")
        endforeach()
        string(APPEND _metadata_contents "file(WRITE ${_output} \"\${_contents}\")\n")
    endforeach()
    set(_metadata "${OTP_INTERNAL_ROOT}/commands/${_target}-metadata.cmake")
    file(GENERATE OUTPUT "${_metadata}" CONTENT "${_metadata_contents}")
    set(_own)
    if(A_OWN_CODE_PATH)
        set(_own OWN_CODE_PATH)
    endif()
    otp_erlang_compile_commands(_commands APP "${A_APP}" OUT "${_out}" GENERATED "${_generated}"
        SELF_TRANSFORM "${A_SELF_TRANSFORM}" SOURCES ${_sources}
        OPTIONS warnings_as_errors warn_missing_doc_function warn_missing_doc_callback
            warn_missing_spec_documented ${A_OPTIONS} ${_own})
    set(_deps ${_stage} otp_application_validator otp_erlc otp_headers_${A_APP} ${A_DEPENDS})
    otp_dependency_stamps(_dependency_files ${_deps})
    set(_stamp "${OTP_INTERNAL_ROOT}/stamps/${_target}.stamp")
    otp_command(_validate "${PROJECT_BINARY_DIR}" "${OTP_BOOTSTRAP_ERL}"
        +S 2:2 -boot "${OTP_BOOTSTRAP_ROOT}/bin/no_dot_erlang" -noshell -noinput
        -pa "${OTP_VALIDATOR_ROOT}" -s otp_application_validator run
        -extra "${A_APP}" "${_version}" "${_out}" ${_sources})
    add_custom_command(OUTPUT "${_stamp}" BYPRODUCTS ${_outputs}
        COMMAND "${CMAKE_COMMAND}" -P "${_prepare}"
        ${_commands}
        COMMAND "${CMAKE_COMMAND}" -P "${_metadata}"
        ${_validate}
        COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
        DEPENDS ${_sources} ${_support} ${A_INPUTS} ${_deps} ${_dependency_files}
            ${_commands_INPUTS} ${_prune_INPUTS} ${_migrate_INPUTS} ${_validate_INPUTS}
            "${_metadata}" "${_prepare}"
        COMMENT "Compiling ${A_APP} with the supplied bootstrap compiler through erlc" VERBATIM)
    add_custom_target(${_target} DEPENDS "${_stamp}")
    file(GLOB_RECURSE _public_headers CONFIGURE_DEPENDS "${_app_source}/include/*.hrl" "${_app_source}/include/*.h")
    set_target_properties(${_target} PROPERTIES OTP_STAMP "${_stamp}"
        OTP_BEAM_OUTPUTS "${_beams}" OTP_PUBLIC_HEADERS "${_public_headers}")
    set(_destination "lib/${A_APP}-${_version}")
    set(_ebin "${PROJECT_BINARY_DIR}/lib/${A_APP}/ebin")
    set(_installed "${_ebin}/${A_APP}.app" "${_ebin}/${A_APP}.appup")
    foreach(_source IN LISTS _sources)
        get_filename_component(_module "${_source}" NAME_WE)
        list(APPEND _installed "${_ebin}/${_module}.beam")
        if(NOT A_NO_SOURCE_INSTALL)
            set(_directory "")
            get_source_file_property(_source_install_directory "${_source}" OTP_INSTALL_SOURCE_DIRECTORY)
            if(_source_install_directory)
                set(_directory "${_source_install_directory}")
            elseif(A_PRESERVE_SOURCE_LAYOUT AND _source MATCHES "^${_app_source}/src/")
                file(RELATIVE_PATH _relative "${_app_source}/src" "${_source}")
                get_filename_component(_directory "${_relative}" DIRECTORY)
            elseif(A_PRESERVE_SOURCE_LAYOUT AND _source MATCHES "^${OTP_GENERATED_ROOT}/${A_APP}/")
                file(RELATIVE_PATH _relative "${PROJECT_BINARY_DIR}/lib/${A_APP}/src" "${_source}")
                get_filename_component(_directory "${_relative}" DIRECTORY)
            endif()
            install(FILES "${_source}" DESTINATION "${_destination}/src/${_directory}")
        endif()
    endforeach()
    install(FILES ${_installed} DESTINATION "${_destination}/ebin")
    if(NOT A_NO_INCLUDE_INSTALL AND IS_DIRECTORY "${_app_source}/include")
        install(DIRECTORY "${_app_source}/include/" DESTINATION "${_destination}/include")
    endif()
    if(NOT A_NO_SOURCE_SUPPORT_INSTALL)
        file(GLOB _headers CONFIGURE_DEPENDS "${_app_source}/src/*.hrl" "${_app_source}/src/*.yrl")
        if(_headers)
            install(FILES ${_headers} DESTINATION "${_destination}/src")
        endif()
    endif()
endfunction()
