# SPDX-License-Identifier: Apache-2.0
# Apply supported upstream hardening options to the libraries whose exported
# development metadata advertises them, as well as the product executables.
if(MSVC)
    # MSVC's default stack protection and PE linker protections apply. Its
    # linker warns and ignores unknown GNU options rather than rejecting them.
    set(OTP_NATIVE_LDFLAGS)
    return()
endif()
include(CheckLinkerFlag)
include(CheckCCompilerFlag)
set(OTP_NATIVE_LDFLAGS)
foreach(_flag IN ITEMS -Wl,--no-copy-dt-needed-entries -Wl,--as-needed
        -Wl,-z,now -Wl,-z,relro -Wl,-z,noexecstack)
    string(MAKE_C_IDENTIFIER "OTP_LINK_${_flag}" _probe)
    check_linker_flag(C "${_flag}" "${_probe}")
    if(${_probe})
        add_link_options("${_flag}")
        list(APPEND OTP_NATIVE_LDFLAGS "${_flag}")
    endif()
endforeach()
check_c_compiler_flag(-fstack-protector-strong OTP_STACK_PROTECTOR_STRONG)
if(OTP_STACK_PROTECTOR_STRONG)
    add_compile_options(-fstack-protector-strong)
    add_link_options(-fstack-protector-strong)
    list(APPEND OTP_NATIVE_LDFLAGS -fstack-protector-strong)
endif()
