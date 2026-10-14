# SPDX-License-Identifier: Apache-2.0
# Existing upstream release resources; this does not enable GUI acceptance.
set(_installed_example_outputs)
foreach(_group IN ITEMS common_test/proper_ext wx/examples/demo wx/examples/sudoku wx/examples/simple)
    string(REPLACE "/" ";" _parts "${_group}")
    list(GET _parts 0 _app)
    otp_application_version("${_app}" _version)
    set(_input "${PROJECT_SOURCE_DIR}/lib/${_group}")
    set(_output "${PROJECT_BINARY_DIR}/generated/installed-examples/${_group}")
    string(FIND "${_group}" "/" _slash)
    math(EXPR _after "${_slash} + 1")
    string(SUBSTRING "${_group}" ${_after} -1 _relative)
    if(_app STREQUAL wx)
        set(_relative "doc/${_relative}")
    endif()
    set(_destination "lib/${_app}-${_version}/${_relative}")
    file(GLOB _sources CONFIGURE_DEPENDS "${_input}/*.erl")
    file(GLOB _resources CONFIGURE_DEPENDS "${_input}/*.hrl" "${_input}/*.png"
        "${_input}/*.jpg" "${_input}/*.html")
    install(FILES ${_sources} ${_resources} DESTINATION "${_destination}")
    if(NOT _group STREQUAL wx/examples/simple)
        set(_outputs)
        foreach(_file IN LISTS _sources)
            get_filename_component(_module "${_file}" NAME_WE)
            list(APPEND _outputs "${_output}/${_module}.beam")
        endforeach()
        add_custom_command(OUTPUT ${_outputs}
            COMMAND ${OTP_BUILD_COMMAND} script
                "${PROJECT_SOURCE_DIR}/tools/compile_installed_examples.escript" "${OTP_BUILD_ROOT}"
                "${_output}" "${PROJECT_BINARY_DIR}/otp/lib/${_app}-${_version}/ebin" ${_sources}
            DEPENDS otp_${_app} otp_build_host ${_sources} ${_resources}
                "${PROJECT_SOURCE_DIR}/tools/compile_installed_examples.escript"
            COMMENT "Compiling upstream installed resources: ${_group}" VERBATIM)
        install(FILES ${_outputs} DESTINATION "${_destination}")
        list(APPEND _installed_example_outputs ${_outputs})
    endif()
endforeach()
add_custom_target(otp_installed_examples ALL DEPENDS ${_installed_example_outputs})
