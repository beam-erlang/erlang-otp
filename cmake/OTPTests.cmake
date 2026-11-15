# CTest selects components; the installed-candidate Erlang runner owns their
# original specifications, preparation recipes, processes and result handling.
include_guard(GLOBAL)
option(OTP_ENABLE_TEST_SUITES "Register the complete pinned OTP test profile" OFF)
option(OTP_ENABLE_ERTS_TESTS "Register the retained ERTS corpus" OFF)
option(OTP_ENABLE_INDIVIDUAL_SUITES "Register diagnostic original suite selections" OFF)

set(_otp_type_suffix "")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(_otp_type_suffix "d")
endif()
set(OTP_TEST_WORK_ROOT "${PROJECT_SOURCE_DIR}/../tmp/u-${CMAKE_SYSTEM_NAME}-${BEAM_SDK_ARCHITECTURE}-${OTP_BEAM_FLAVOR}${_otp_type_suffix}"
    CACHE PATH "Owned scratch root for installed-candidate OTP tests")
cmake_path(NORMAL_PATH OTP_TEST_WORK_ROOT)
set(OTP_TEST_CANDIDATE "${CMAKE_INSTALL_PREFIX}" CACHE PATH "Installed candidate to test")
set(OTP_TEST_CANDIDATE_BUILD "${PROJECT_BINARY_DIR}" CACHE PATH "Build selecting the installed candidate SDK")
set(OTP_TEST_REFERENCE_GIT "$ENV{OTP_TEST_REFERENCE_GIT}" CACHE PATH "Explicit original OTP Git repository")
set(OTP_TEST_CONFIGURED_SOURCE "$ENV{OTP_TEST_CONFIGURED_SOURCE}" CACHE PATH "Explicit matching configured original source tree")
set(OTP_TEST_INPUTS "" CACHE FILEPATH "Explicit prerequisite and service inputs")
find_program(OTP_TEST_MAKE NAMES gmake make)
find_program(OTP_TEST_GIT NAMES git)
find_program(OTP_TEST_TAR NAMES tar)
find_program(OTP_TEST_CLANG NAMES clang)
find_program(OTP_TEST_BASH NAMES bash)

set(_otp_ct_entry "${PROJECT_SOURCE_DIR}/tests/otp/support/otp_ct.escript")
set(_otp_ct_home
    "HOME=${OTP_TEST_WORK_ROOT}/home" "TMPDIR=${OTP_TEST_WORK_ROOT}/tmp"
    "TMP=${OTP_TEST_WORK_ROOT}/tmp" "TEMP=${OTP_TEST_WORK_ROOT}/tmp")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_program(OTP_TEST_BWRAP NAMES bwrap REQUIRED)
    find_program(OTP_TEST_UNSHARE NAMES unshare REQUIRED)
    find_program(OTP_TEST_IP NAMES ip REQUIRED)
    set(_otp_ct_native_roots)
    if(OTP_TEST_INPUTS)
        file(READ "${OTP_TEST_INPUTS}" _otp_ct_inputs)
        string(JSON _native_count ERROR_VARIABLE _native_error LENGTH "${_otp_ct_inputs}" native_roots)
        if(NOT _native_error AND _native_count GREATER 0)
            math(EXPR _native_last "${_native_count} - 1")
            foreach(_native_index RANGE 0 ${_native_last})
                string(JSON _native_root GET "${_otp_ct_inputs}" native_roots ${_native_index} path)
                list(APPEND _otp_ct_native_roots --native-root "${_native_root}")
            endforeach()
        endif()
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${OTP_TEST_INPUTS}")
    endif()
    set(_otp_ct_launcher "${OTP_TEST_BASH}" "${PROJECT_SOURCE_DIR}/tests/otp/support/otp_ct_linux.sh"
        --work-root "${OTP_TEST_WORK_ROOT}" --candidate-prefix "${OTP_TEST_CANDIDATE}"
        --bwrap "${OTP_TEST_BWRAP}" --unshare "${OTP_TEST_UNSHARE}" --ip "${OTP_TEST_IP}"
        ${_otp_ct_native_roots})
    # The launcher supplies a fresh home and temporary directory for each job.
    set(_otp_ct_home)
endif()
set(_otp_ct_command "${CMAKE_COMMAND}" -E env
    --unset=ERL_FLAGS --unset=ERL_AFLAGS --unset=ERL_ZFLAGS
    --unset=ERL_COMPILER_OPTIONS --unset=ERL_LIBS --unset=ERL_EXTREME_TESTING
    ${_otp_ct_home}
    "${OTP_TEST_CANDIDATE}/bin/escript${CMAKE_EXECUTABLE_SUFFIX}" "${_otp_ct_entry}")
function(_otp_ct_invocation output domain)
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        set(${output} ${_otp_ct_launcher} --domain "${domain}" -- ${_otp_ct_command} PARENT_SCOPE)
    else()
        set(${output} ${_otp_ct_command} PARENT_SCOPE)
    endif()
endfunction()
_otp_ct_invocation(_otp_ct_shared_command shared)
set(_otp_ct_args
    --source-root "${PROJECT_SOURCE_DIR}"
    --candidate-prefix "${OTP_TEST_CANDIDATE}"
    --candidate-build "${OTP_TEST_CANDIDATE_BUILD}"
    --sdk-root "${BEAM_SDK_ROOT}"
    --reference-git "${OTP_TEST_REFERENCE_GIT}"
    --configured-source "${OTP_TEST_CONFIGURED_SOURCE}"
    --work-root "${OTP_TEST_WORK_ROOT}"
    --make "${OTP_TEST_MAKE}" --cc "${CMAKE_C_COMPILER}" --cxx "${CMAKE_CXX_COMPILER}"
    --git "${OTP_TEST_GIT}" --tar "${OTP_TEST_TAR}"
    --javac "${JAVA_HOME}/bin/javac${CMAKE_EXECUTABLE_SUFFIX}" --wx-config "${OTP_WX_CONFIG}"
    --perl "${PERL_EXECUTABLE}" --clang "${OTP_TEST_CLANG}" --bash "${OTP_TEST_BASH}"
    --flavor "${OTP_BEAM_FLAVOR}" --build-type "${BEAM_SDK_BUILD_TYPE}")
if(OTP_TEST_INPUTS)
    list(APPEND _otp_ct_args --inputs "${OTP_TEST_INPUTS}")
endif()

set(_otp_inventory_path "${PROJECT_SOURCE_DIR}/tests/otp/manifest.json")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_otp_inventory_path}")
file(READ "${_otp_inventory_path}" _otp_inventory)
function(_otp_inventory_array output json)
    string(JSON _count ERROR_VARIABLE _error LENGTH "${json}" ${ARGN})
    set(_values)
    if(NOT _error AND _count GREATER 0)
        math(EXPR _last "${_count} - 1")
        foreach(_index RANGE 0 ${_last})
            string(JSON _value GET "${json}" ${ARGN} ${_index})
            list(APPEND _values "${_value}")
        endforeach()
    endif()
    set(${output} "${_values}" PARENT_SCOPE)
endfunction()
_otp_inventory_array(_otp_apps "${_otp_inventory}" applications)
list(LENGTH _otp_apps _otp_app_count)
if(NOT _otp_app_count EQUAL 35)
    message(FATAL_ERROR "The pinned OTP test profile requires 35 application domains")
endif()
set(_otp_erts emulator system epmd yielding-c-fun)
set(_otp_domains ${_otp_apps} ${_otp_erts})
set(_otp_session "${OTP_TEST_WORK_ROOT}/test-session.json")
set(_otp_full_tests)
set(_otp_full_reports)
set(_otp_prepare_commands)
set(_otp_erts_prepare_commands)

foreach(_domain IN LISTS _otp_domains)
    _otp_ct_invocation(_otp_ct_domain_command "${_domain}")
    set(_domain_args --domain "${_domain}" --profile full)
    set(_prepare_command ${_otp_ct_domain_command} prepare ${_otp_ct_args} ${_domain_args}
        --report "${OTP_TEST_WORK_ROOT}/reports/prepare/${_domain}.json")
    add_custom_target("otp-tests-prepare-${_domain}"
        COMMAND ${_prepare_command} USES_TERMINAL VERBATIM)
    list(APPEND _otp_prepare_commands COMMAND ${_prepare_command})
    if(_domain IN_LIST _otp_erts)
        list(APPEND _otp_erts_prepare_commands COMMAND ${_prepare_command})
        set(_enabled FALSE)
        if(OTP_ENABLE_TEST_SUITES OR OTP_ENABLE_ERTS_TESTS)
            set(_enabled TRUE)
        endif()
        set(_name "otp-erts-${_domain}")
        set(_labels "otp;erts;${_domain}")
    else()
        set(_enabled "${OTP_ENABLE_TEST_SUITES}")
        set(_name "otp-app-${_domain}")
        set(_labels "otp;otp-applications;${_domain}")
    endif()
    if(_enabled)
        set(_report "${OTP_TEST_WORK_ROOT}/reports/${_domain}.json")
        set(_session_args)
        if(OTP_ENABLE_TEST_SUITES)
            set(_session_args --session-file "${_otp_session}")
            string(APPEND _labels ";full")
        endif()
        if(_domain STREQUAL "epmd" OR _domain STREQUAL "yielding-c-fun")
            string(APPEND _labels ";supplemental")
        else()
            string(APPEND _labels ";canonical")
        endif()
        add_test(NAME "${_name}" COMMAND ${_otp_ct_domain_command} run ${_otp_ct_args}
            ${_domain_args} ${_session_args} --report "${_report}")
        set(_timeout 172800)
        if(_domain STREQUAL "yielding-c-fun")
            set(_timeout 3600)
        endif()
        set_tests_properties("${_name}" PROPERTIES RUN_SERIAL TRUE TIMEOUT "${_timeout}"
            LABELS "${_labels};${OTP_BEAM_FLAVOR};${CMAKE_BUILD_TYPE}")
        if(OTP_ENABLE_TEST_SUITES)
            set_tests_properties("${_name}" PROPERTIES FIXTURES_REQUIRED otp_test_session)
            list(APPEND _otp_full_tests "${_name}")
            list(APPEND _otp_full_reports --input-report "${_report}")
        endif()
    endif()
endforeach()
add_custom_target(otp-tests-prepare ${_otp_prepare_commands} USES_TERMINAL VERBATIM)
add_custom_target(otp-erts-prepare ${_otp_erts_prepare_commands} USES_TERMINAL VERBATIM)

if(OTP_ENABLE_TEST_SUITES)
    add_test(NAME otp-tests-start COMMAND ${_otp_ct_shared_command} begin
        --session-file "${_otp_session}")
    set_tests_properties(otp-tests-start PROPERTIES RUN_SERIAL TRUE TIMEOUT 60
        FIXTURES_SETUP otp_test_session LABELS "otp;full;session")
    add_test(NAME otp-tests-reconcile COMMAND ${_otp_ct_shared_command} reconcile
        ${_otp_ct_args} ${_otp_full_reports} --session-file "${_otp_session}"
        --report "${OTP_TEST_WORK_ROOT}/reports/matrix.json")
    set_tests_properties(otp-tests-reconcile PROPERTIES RUN_SERIAL TRUE TIMEOUT 60
        DEPENDS "otp-tests-start;${_otp_full_tests}"
        LABELS "otp;full;reconciliation")
endif()

if(OTP_ENABLE_INDIVIDUAL_SUITES)
    # These JSON fields are registration names, not executable CT specifications.
    # The runner validates the actual prepared suite inventory and lifecycle.
    foreach(_domain IN LISTS _otp_apps ITEMS emulator system epmd)
        _otp_ct_invocation(_otp_ct_domain_command "${_domain}")
        if(_domain STREQUAL "epmd")
            set(_section supplemental_batches)
        else()
            set(_section batches)
        endif()
        string(JSON _batch GET "${_otp_inventory}" ${_section} "${_domain}")
        _otp_inventory_array(_suites "${_batch}" suites)
        foreach(_field generated_suites dynspec_targets)
            _otp_inventory_array(_generated "${_batch}" ${_field})
            list(APPEND _suites ${_generated})
        endforeach()
        string(JSON _variants ERROR_VARIABLE _error LENGTH "${_batch}" variants)
        if(NOT _error AND _variants GREATER 0)
            math(EXPR _last "${_variants} - 1")
            foreach(_index RANGE 0 ${_last})
                string(JSON _suite GET "${_batch}" variants ${_index} module)
                list(APPEND _suites "${_suite}")
            endforeach()
        endif()
        list(REMOVE_DUPLICATES _suites)
        foreach(_suite IN LISTS _suites)
            if(NOT _suite MATCHES "^[A-Za-z][A-Za-z0-9_]*_SUITE$")
                continue()
            endif()
            if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND
               ((_domain STREQUAL "emulator" AND _suite STREQUAL "mtx_SUITE") OR
                    (_domain STREQUAL "system" AND
                        (_suite STREQUAL "ethread_SUITE" OR _suite STREQUAL "erl_print_SUITE"))))
                continue()
            endif()
            set(_name "otp-suite-${_domain}-${_suite}")
            add_test(NAME "${_name}" COMMAND ${_otp_ct_domain_command} run ${_otp_ct_args}
                --domain "${_domain}" --profile suite --suite "${_suite}"
                --report "${OTP_TEST_WORK_ROOT}/reports/suite/${_domain}-${_suite}.json")
            set_tests_properties("${_name}" PROPERTIES RUN_SERIAL TRUE TIMEOUT 172800
                LABELS "otp;suite;${_domain};${OTP_BEAM_FLAVOR};${CMAKE_BUILD_TYPE}")
        endforeach()
    endforeach()
endif()

set(_otp_ct_selftest_inputs)
if(OTP_TEST_INPUTS)
    list(APPEND _otp_ct_selftest_inputs --inputs "${OTP_TEST_INPUTS}")
endif()
add_test(NAME otp-test-controller COMMAND ${_otp_ct_shared_command} selftest
    --source-root "${PROJECT_SOURCE_DIR}"
    --work-root "${OTP_TEST_WORK_ROOT}/selftest"
    --report "${OTP_TEST_WORK_ROOT}/reports/selftest.json" ${_otp_ct_selftest_inputs})
set_tests_properties(otp-test-controller PROPERTIES RUN_SERIAL TRUE TIMEOUT 120
    LABELS "harness;test-preparation;erlang-controller")

add_custom_target(otp-tests
    COMMAND "${CMAKE_CTEST_COMMAND}" --test-dir "${PROJECT_BINARY_DIR}"
        --output-on-failure --no-tests=error -L "^full$" USES_TERMINAL VERBATIM)
add_custom_target(otp-erts-check
    COMMAND "${CMAKE_CTEST_COMMAND}" --test-dir "${PROJECT_BINARY_DIR}"
        --output-on-failure --no-tests=error -L "^erts$" USES_TERMINAL VERBATIM)
