# Jinterface is a Java application: its Erlang module list is intentionally empty.

set(JAVA_HOME "$ENV{JAVA_HOME}" CACHE PATH "Explicit installed JDK prefix")
if(NOT IS_ABSOLUTE "${JAVA_HOME}")
    message(FATAL_ERROR "Set JAVA_HOME to an explicit absolute installed JDK prefix")
endif()
foreach(_tool java javac jar)
    if(NOT EXISTS "${JAVA_HOME}/bin/${_tool}${CMAKE_EXECUTABLE_SUFFIX}")
        message(FATAL_ERROR "Selected JDK is missing ${JAVA_HOME}/bin/${_tool}${CMAKE_EXECUTABLE_SUFFIX}")
    endif()
endforeach()
execute_process(COMMAND "${JAVA_HOME}/bin/javac${CMAKE_EXECUTABLE_SUFFIX}" -version
    RESULT_VARIABLE _javac_status OUTPUT_VARIABLE _javac_version ERROR_VARIABLE _javac_error)
if(NOT _javac_status EQUAL 0)
    message(FATAL_ERROR "Selected javac failed: ${_javac_error}")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${JAVA_HOME}/bin/java${CMAKE_EXECUTABLE_SUFFIX}" "${JAVA_HOME}/bin/javac${CMAKE_EXECUTABLE_SUFFIX}" "${JAVA_HOME}/bin/jar${CMAKE_EXECUTABLE_SUFFIX}")

set(_java_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpAuthException.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangDecodeException.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangException.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangExit.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangRangeException.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpException.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangAtom.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangBinary.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangBitstr.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangBoolean.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangByte.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangChar.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangDouble.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangFloat.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangInt.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangList.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangLong.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangObject.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangPid.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangPort.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangRef.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangShort.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangString.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangTuple.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangMap.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangUInt.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangUShort.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/AbstractConnection.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/AbstractNode.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/GenericQueue.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/Link.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/Links.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpConnection.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpCookedConnection.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpEpmd.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangFun.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpErlangExternalFun.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpExternal.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpGenericTransportFactory.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpInputStream.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpLocalNode.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpNodeStatus.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpMD5.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpMbox.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpMsg.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpNode.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpOutputStream.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpPeer.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpSelf.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpServer.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpServerSocketTransport.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpServerTransport.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpSocketTransport.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpSocketTransportFactory.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpTransport.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpTransportFactory.java"
    "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang/OtpSystem.java"
)

otp_application_version(jinterface _version)
set(_classes "${OTP_GENERATED_ROOT}/jinterface/classes")
set(_jar "${PROJECT_BINARY_DIR}/lib/jinterface/priv/OtpErlang.jar")
set(_jar_flags -cf)
if(DEFINED ENV{SOURCE_DATE_EPOCH})
    set(_jar_flags --date=1980-01-01T12:00:00Z -c -f)
endif()
add_custom_command(OUTPUT "${_jar}"
    COMMAND "${CMAKE_COMMAND}" -E rm -rf "${_classes}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_classes}" "${PROJECT_BINARY_DIR}/lib/jinterface/priv"
    COMMAND "${JAVA_HOME}/bin/javac${CMAKE_EXECUTABLE_SUFFIX}" -Xlint -encoding UTF-8 -d "${_classes}" ${_java_sources}
    COMMAND "${JAVA_HOME}/bin/jar${CMAKE_EXECUTABLE_SUFFIX}" ${_jar_flags} "${_jar}" -C "${_classes}" com/ericsson/otp/erlang
    DEPENDS ${_java_sources} "${JAVA_HOME}/bin/javac${CMAKE_EXECUTABLE_SUFFIX}" "${JAVA_HOME}/bin/jar${CMAKE_EXECUTABLE_SUFFIX}"
    VERBATIM
    COMMENT "Compiling Jinterface with the selected JDK")
add_custom_target(otp_jinterface_jar DEPENDS "${_jar}")
otp_add_application(APP jinterface
    RESOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/java_src/com/ericsson/otp/erlang"
    DEPENDS otp_jinterface_jar
    NO_SOURCE_INSTALL
)
install(FILES "${_jar}" DESTINATION "lib/jinterface-${_version}/priv")
install(FILES ${_java_sources} DESTINATION "lib/jinterface-${_version}/java_src/com/ericsson/otp/erlang")
