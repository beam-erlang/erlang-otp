# JInterface is OTP-owned Java code; the selected JDK supplies its toolchain.
find_package(Java REQUIRED COMPONENTS Development Runtime)
set(_resources "${PROJECT_SOURCE_DIR}/lib/jinterface/java_src/com/ericsson/otp/erlang")
set(_java_inventory "${_resources}/java_files")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_java_inventory}")
file(READ "${_java_inventory}" _java_text)
string(REGEX MATCHALL "[\n][ \t]+[A-Za-z][A-Za-z0-9_]*" _java_entries "${_java_text}")
set(_java_sources)
foreach(_entry IN LISTS _java_entries)
    string(REGEX MATCH "[A-Za-z][A-Za-z0-9_]*" _class "${_entry}")
    if(NOT EXISTS "${_resources}/${_class}.java")
        message(FATAL_ERROR "Missing JInterface source ${_class}.java")
    endif()
    list(APPEND _java_sources "${_resources}/${_class}.java")
endforeach()
if(NOT _java_sources)
    message(FATAL_ERROR "Empty JInterface source inventory")
endif()
set(_java_classes "${PROJECT_BINARY_DIR}/generated/jinterface/classes")
set(_java_jar "${PROJECT_BINARY_DIR}/otp/lib/jinterface-${_version}/priv/OtpErlang.jar")
set(_jar_date)
if(NOT "$ENV{SOURCE_DATE_EPOCH}" STREQUAL "")
    set(_jar_date --date=1980-01-01T12:00:00Z)
endif()
add_custom_command(OUTPUT "${_java_jar}"
    COMMAND "${CMAKE_COMMAND}" -E rm -rf "${_java_classes}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_java_classes}"
        "${PROJECT_BINARY_DIR}/otp/lib/jinterface-${_version}/priv"
    COMMAND "${Java_JAVAC_EXECUTABLE}" -Xlint -encoding UTF-8
        -d "${_java_classes}" ${_java_sources}
    COMMAND "${Java_JAR_EXECUTABLE}" ${_jar_date} -c -f "${_java_jar}"
        -C "${_java_classes}" com/ericsson/otp/erlang/
    DEPENDS ${_java_sources} "${_java_inventory}"
    COMMENT "Building the OTP JInterface Java library" VERBATIM)
list(APPEND _extra_dependencies "${_java_jar}")
install(FILES "${_java_jar}" DESTINATION "lib/jinterface-${_version}/priv")
install(FILES ${_java_sources}
    DESTINATION "lib/jinterface-${_version}/java_src/com/ericsson/otp/erlang")
