# erl_interface application sources, generation and release rules.
otp_application_version(erl_interface _version)

set(_sources
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP erl_interface
    SOURCES ${_sources}
    INPUTS ${_headers}
    NO_INCLUDE_INSTALL
)


# The independent upstream EI codec and C-node libraries belong to OTP.


set(_otp_ei "${PROJECT_SOURCE_DIR}/lib/erl_interface")
set(_otp_ei_sources)

foreach(_part IN ITEMS connect decode encode epmd global misc)
    file(GLOB _part_sources CONFIGURE_DEPENDS "${_otp_ei}/src/${_part}/*.c")
    list(APPEND _otp_ei_sources ${_part_sources})
endforeach()

# This file has an upstream ERL_INTERFACE mode with no VM implementation input.
list(APPEND _otp_ei_sources "${PROJECT_SOURCE_DIR}/erts/emulator/beam/erl_md5.c")
otp_application_version(erl_interface OTP_EI_VERSION)

if(WIN32)
    set(_ei_variants ei_mt ei_md ei_mdd)
else()
    set(_ei_variants ei ei_st)
endif()
foreach(_variant IN LISTS _ei_variants)
    add_library(otp_${_variant} STATIC ${_otp_ei_sources})
    set_target_properties(otp_${_variant} PROPERTIES
        OUTPUT_NAME "${_variant}"
        POSITION_INDEPENDENT_CODE ON
        ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/erl_interface/lib/${OTP_TARGET}"
    )
    target_compile_definitions(otp_${_variant} PRIVATE ERL_INTERFACE EI_NO_DEPR_WARN)
    otp_linux_native_flags(otp_${_variant} NO_LINK_HARDENING)
    if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
        target_compile_options(otp_${_variant} PRIVATE -O2 -g
            -Werror=undef -Werror=implicit -Werror=return-type
            -Wdeclaration-after-statement -Wall -Wstrict-prototypes
            -Wmissing-prototypes -Wmissing-declarations -Wnested-externs -Winline)
        target_compile_definitions(otp_${_variant} PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
    endif()

    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        target_compile_definitions(otp_${_variant} PRIVATE EI_64BIT)
    endif()

    target_link_libraries(otp_${_variant} PRIVATE otp_native_config)
    if(WIN32)
        target_compile_definitions(otp_${_variant} PRIVATE __WIN32__ USE_THREADS WIN32_THREADS)
        target_link_libraries(otp_${_variant} PUBLIC ws2_32)
        if(_variant STREQUAL ei_mt)
            set_target_properties(otp_${_variant} PROPERTIES OUTPUT_NAME ei MSVC_RUNTIME_LIBRARY MultiThreaded)
        elseif(_variant STREQUAL ei_mdd)
            set_target_properties(otp_${_variant} PROPERTIES MSVC_RUNTIME_LIBRARY MultiThreadedDebugDLL)
        else()
            set_target_properties(otp_${_variant} PROPERTIES MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
        endif()
    else()
        target_link_libraries(otp_${_variant} PUBLIC m)
    endif()
    target_include_directories(otp_${_variant}
        PUBLIC
            "${_otp_ei}/include"
        PRIVATE
            "${PROJECT_SOURCE_DIR}/erts/emulator/beam"
    )

    foreach(_part IN ITEMS connect decode encode epmd global misc)
        target_include_directories(otp_${_variant} PRIVATE "${_otp_ei}/src/${_part}")
    endforeach()
endforeach()

if(WIN32)
    if(CMAKE_BUILD_TYPE STREQUAL Debug)
        add_library(otp_ei ALIAS otp_ei_mdd)
    else()
        add_library(otp_ei ALIAS otp_ei_md)
    endif()
else()
    target_compile_definitions(otp_ei PUBLIC _REENTRANT)
    target_link_libraries(otp_ei PUBLIC Threads::Threads)
endif()

foreach(_variant IN LISTS _ei_variants)
    install(TARGETS otp_${_variant} ARCHIVE DESTINATION "lib/erl_interface-${OTP_EI_VERSION}/lib")
    install(TARGETS otp_${_variant} ARCHIVE DESTINATION usr/lib)
endforeach()

foreach(_destination IN ITEMS "lib/erl_interface-${OTP_EI_VERSION}/include" usr/include)
    install(FILES
        "${_otp_ei}/include/ei.h"
        "${_otp_ei}/include/ei_connect.h"
        "${_otp_ei}/include/eicode.h"
        DESTINATION "${_destination}"
    )
endforeach()

# Erl_Interface owns its command; the ERTS installer also publishes it in bin/.
add_executable(otp_erl_call src/prog/erl_call.c)
target_link_libraries(otp_erl_call PRIVATE otp_command_format otp_ei)
otp_linux_native_flags(otp_erl_call)
if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
    target_compile_options(otp_erl_call PRIVATE -O2 -g
        -Werror=undef -Werror=implicit -Werror=return-type
        -Wdeclaration-after-statement -Wall -Wstrict-prototypes
        -Wmissing-prototypes -Wmissing-declarations -Wnested-externs -Winline)
    target_compile_definitions(otp_erl_call PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
endif()
target_include_directories(otp_erl_call PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src/connect"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/misc"
)
set_target_properties(otp_erl_call PROPERTIES
    OUTPUT_NAME erl_call
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/erl_interface/bin/${OTP_TARGET}"
)
install(TARGETS otp_erl_call RUNTIME DESTINATION "erts-${OTP_ERTS_VERSION}/bin")
install(TARGETS otp_erl_call RUNTIME DESTINATION "lib/erl_interface-${_version}/bin")

# Publish the source release and the selected EI consumer link settings.
set(EI_THREADS true)
if(WIN32)
    set(_ei_thread_definitions __WIN32__ USE_THREADS WIN32_THREADS)
else()
    set(_ei_thread_definitions _REENTRANT)
endif()
get_target_property(_ei_thread_interface_definitions Threads::Threads INTERFACE_COMPILE_DEFINITIONS)
get_target_property(_ei_thread_compile_flags Threads::Threads INTERFACE_COMPILE_OPTIONS)
get_target_property(_ei_thread_link_flags Threads::Threads INTERFACE_LINK_LIBRARIES)
get_target_property(_ei_thread_link_options Threads::Threads INTERFACE_LINK_OPTIONS)
if(_ei_thread_interface_definitions)
    list(APPEND _ei_thread_definitions ${_ei_thread_interface_definitions})
endif()
if(THREADS_HAVE_PTHREAD_ARG)
    # FindThreads expresses the C/CUDA forms conditionally; EI is compiled as C.
    set(_ei_thread_compile_flags -pthread)
endif()
set(_ei_thread_flags)
foreach(_definition IN LISTS _ei_thread_definitions)
    list(APPEND _ei_thread_flags "-D${_definition}")
endforeach()
if(_ei_thread_compile_flags)
    list(APPEND _ei_thread_flags ${_ei_thread_compile_flags})
endif()
set(_ei_thread_libraries "${CMAKE_THREAD_LIBS_INIT}")
if(_ei_thread_link_flags)
    list(APPEND _ei_thread_libraries ${_ei_thread_link_flags})
endif()
if(_ei_thread_link_options)
    list(APPEND _ei_thread_libraries ${_ei_thread_link_options})
endif()
list(REMOVE_DUPLICATES _ei_thread_flags)
list(REMOVE_DUPLICATES _ei_thread_libraries)
string(JOIN " " THR_DEFS ${_ei_thread_flags})
string(JOIN " " THR_LIBS ${_ei_thread_libraries})
if(THR_DEFS MATCHES "\\$<" OR THR_LIBS MATCHES "\\$<")
    message(FATAL_ERROR "EI source-release metadata requires literal selected C thread flags")
endif()
string(TOUPPER "${CMAKE_BUILD_TYPE}" _ei_configuration)
set(LDFLAGS "${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_EXE_LINKER_FLAGS_${_ei_configuration}}")
string(JOIN " " _ei_native_link_flags ${OTP_LINUX_NATIVE_LDFLAGS})
string(APPEND LDFLAGS " ${_ei_native_link_flags}")
string(STRIP "${LDFLAGS}" LDFLAGS)
configure_file("${_otp_ei}/src/eidefs.mk.in"
    "${OTP_GENERATED_ROOT}/erl_interface/src/eidefs.mk" @ONLY)
install(FILES "${_otp_ei}/src/Makefile" "${_otp_ei}/src/Makefile.in"
    "${_otp_ei}/src/README.internal" "${OTP_GENERATED_ROOT}/erl_interface/src/eidefs.mk"
    DESTINATION "lib/erl_interface-${_version}/src")
install(DIRECTORY DESTINATION "lib/erl_interface-${_version}/src/auxdir")
foreach(_part IN ITEMS connect decode encode epmd misc global prog)
    file(GLOB _release_sources CONFIGURE_DEPENDS "${_otp_ei}/src/${_part}/*.c" "${_otp_ei}/src/${_part}/*.h")
    install(FILES ${_release_sources} DESTINATION "lib/erl_interface-${_version}/src/${_part}")
endforeach()
