find_package(Python3 3.9 REQUIRED COMPONENTS Interpreter)

if(WIN32)
  add_test(NAME install.windows-publication
    COMMAND "${Python3_EXECUTABLE}" -B "${CMAKE_CURRENT_SOURCE_DIR}/test_windows_publish.py"
      --guard "$<TARGET_FILE:otp_install_guard>" --cmake "${CMAKE_COMMAND}")
  set_tests_properties(install.windows-publication
    PROPERTIES TIMEOUT 60 LABELS "windows;harness;installed")
endif()

add_test(NAME otp-build-tree
  COMMAND "${Python3_EXECUTABLE}" -B "${CMAKE_CURRENT_SOURCE_DIR}/otp/build_tree.py"
    --source "${PROJECT_SOURCE_DIR}" --build "${PROJECT_BINARY_DIR}"
    --erts-version "${OTP_ERTS_VERSION}" --flavor "${OTP_BEAM_FLAVOR}"
    --build-type "${CMAKE_BUILD_TYPE}"
    --target "${OTP_TARGET}" --apps ${OTP_APPLICATIONS})
set_tests_properties(otp-build-tree PROPERTIES TIMEOUT 240 RUN_SERIAL TRUE LABELS "build-tree;compiler")

# These checks consume a private installation, never the VM source/build tree.
set(_otp_runner "${CMAKE_CURRENT_SOURCE_DIR}/installed.py")
foreach(_mode IN ITEMS installed destdir relocated isolated original-cases)
  add_test(NAME "otp-${_mode}"
    COMMAND "${Python3_EXECUTABLE}" "${_otp_runner}"
      --mode "${_mode}"
      --source "${PROJECT_SOURCE_DIR}"
      --build "${PROJECT_BINARY_DIR}"
      --cmake "${CMAKE_COMMAND}"
      --cc "${CMAKE_C_COMPILER}"
      --erts-version "${OTP_ERTS_VERSION}"
      --flavor "${OTP_BEAM_FLAVOR}"
      --build-type "${CMAKE_BUILD_TYPE}"
      --sdk "${BEAM_SDK_ROOT}"
      --java "${JAVA_HOME}/bin/java"
      --javac "${JAVA_HOME}/bin/javac"
      --apps ${OTP_APPLICATIONS})
  set_tests_properties("otp-${_mode}" PROPERTIES
    TIMEOUT 480 RUN_SERIAL TRUE LABELS "installed;${_mode}")
endforeach()
if(WIN32)
  set_tests_properties(otp-isolated PROPERTIES TIMEOUT 1800)
endif()

add_test(NAME otp-sdk-selection
  COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/sdk_selection.py"
    --source "${PROJECT_SOURCE_DIR}" --cmake "${CMAKE_COMMAND}"
    --sdk "${BEAM_SDK_ROOT}" --flavor "${OTP_BEAM_FLAVOR}"
    --build-type "${CMAKE_BUILD_TYPE}")
set_tests_properties(otp-sdk-selection PROPERTIES TIMEOUT 90 RUN_SERIAL TRUE
  LABELS "sdk;configuration")
add_test(NAME otp-native-architecture
  COMMAND "${Python3_EXECUTABLE}" -B "${CMAKE_CURRENT_SOURCE_DIR}/native_architecture.py"
    --source "${PROJECT_SOURCE_DIR}" --cmake "${CMAKE_COMMAND}"
    --sdk "${BEAM_SDK_ROOT}" --flavor "${OTP_BEAM_FLAVOR}"
    --build-type "${CMAKE_BUILD_TYPE}"
    --cc "${CMAKE_C_COMPILER}" --cxx "${CMAKE_CXX_COMPILER}")
set_tests_properties(otp-native-architecture PROPERTIES TIMEOUT 120 RUN_SERIAL TRUE
  LABELS "sdk;configuration")
add_test(NAME otp-atomic-install
  COMMAND "${Python3_EXECUTABLE}" -B "${CMAKE_CURRENT_SOURCE_DIR}/test_install_tree.py"
    --cmake "${CMAKE_COMMAND}")
set_tests_properties(otp-atomic-install PROPERTIES TIMEOUT 30 LABELS "installed;configuration")

include("${PROJECT_SOURCE_DIR}/cmake/OTPTests.cmake")

# Python's default user temp directory can be outside the task sandbox. Keep
# every validation payload under the shared workspace's disposable root.
file(MAKE_DIRECTORY "${PROJECT_SOURCE_DIR}/../tmp")
get_property(_otp_registered_tests DIRECTORY PROPERTY TESTS)
set_property(TEST ${_otp_registered_tests} APPEND PROPERTY ENVIRONMENT
  "TMPDIR=${PROJECT_SOURCE_DIR}/../tmp" "TMP=${PROJECT_SOURCE_DIR}/../tmp" "TEMP=${PROJECT_SOURCE_DIR}/../tmp")
