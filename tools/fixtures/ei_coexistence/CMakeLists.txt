cmake_minimum_required(VERSION 3.25)
project(ei_runtime_coexistence LANGUAGES C CXX)
find_package(BEAM CONFIG REQUIRED COMPONENTS Runtime RuntimeStatic)
find_package(Threads REQUIRED)
foreach(archive ei ei_st)
    add_library(${archive} STATIC IMPORTED)
    set_target_properties(${archive} PROPERTIES
        IMPORTED_LOCATION "${OTP_PREFIX}/usr/lib/lib${archive}.a"
        INTERFACE_INCLUDE_DIRECTORIES "${OTP_PREFIX}/usr/include"
        INTERFACE_LINK_LIBRARIES "Threads::Threads;m")
    # Both archives must be transitive dependencies for their relative order
    # to follow these interfaces. A direct libei precedes RuntimeStatic's archive.
    add_library(${archive}_link INTERFACE)
    target_link_libraries(${archive}_link INTERFACE ${archive})
    foreach(form shared static_first static_last)
        set(_target "${archive}_${form}")
        add_executable(${_target} main.c)
        if(form STREQUAL shared)
            target_link_libraries(${_target} PRIVATE BEAM::Runtime ${archive})
        elseif(form STREQUAL static_first)
            target_link_libraries(${_target} PRIVATE BEAM::RuntimeStatic ${archive}_link)
        else()
            target_link_libraries(${_target} PRIVATE ${archive}_link BEAM::RuntimeStatic)
        endif()
    endforeach()
endforeach()
