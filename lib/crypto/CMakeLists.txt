# crypto application sources, generation and release rules.
otp_application_version(crypto _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/crypto.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/crypto_ec_curves.erl"
)


file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP crypto
    SOURCES ${_sources}
    OPTIONS
        "{d,'CRYPTO_VSN',\"${_version}\"}"
    INPUTS ${_headers}
)


# Ordinary upstream Crypto NIFs over the public SDK and a selected OpenSSL.


if(NOT IS_ABSOLUTE "${OPENSSL_ROOT_DIR}" OR NOT IS_DIRECTORY "${OPENSSL_ROOT_DIR}")
    message(FATAL_ERROR "Set OPENSSL_ROOT_DIR to an explicit installed OpenSSL prefix")
endif()

find_package(OpenSSL REQUIRED COMPONENTS Crypto)
file(REAL_PATH "${OPENSSL_ROOT_DIR}" _openssl_root)

foreach(_input IN ITEMS "${OPENSSL_INCLUDE_DIR}" "${OPENSSL_CRYPTO_LIBRARY}")
    file(REAL_PATH "${_input}" _actual)
    cmake_path(IS_PREFIX _openssl_root "${_actual}" NORMALIZE _selected)

    if(NOT _selected)
        message(FATAL_ERROR
            "OpenSSL input ${_input} is outside OPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR}"
        )
    endif()
endforeach()

include(CheckCSourceCompiles)
include(CMakePushCheckState)
cmake_push_check_state(RESET)
set(CMAKE_REQUIRED_LIBRARIES OpenSSL::Crypto)
unset(OTP_CRYPTO_HAS_ENGINE CACHE)
foreach(_probe IN ITEMS OTP_CRYPTO_HAS_MEMCMP OTP_CRYPTO_DISABLE_TEST_ENGINE OTP_CRYPTO_OPENSSL_3)
    unset(${_probe} CACHE)
endforeach()
check_c_source_compiles(
    "#include <openssl/crypto.h>\nint main(void) { int (*compare)(const void *, const void *, size_t) = CRYPTO_memcmp; return compare(\"a\", \"b\", 1); }"
    OTP_CRYPTO_HAS_MEMCMP
)
# Upstream defaults to building the test engine except with LibreSSL >= 3.5.0.
# The unchanged source handles disabled OpenSSL algorithms itself.
check_c_source_compiles(
    "#include <openssl/opensslv.h>\n#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x3050000fL\n#error test engine is enabled by default\n#endif\nint main(void) { return 0; }"
    OTP_CRYPTO_DISABLE_TEST_ENGINE
)
check_c_source_compiles(
    "#include <openssl/opensslv.h>\n#if !defined(OPENSSL_VERSION_MAJOR) || OPENSSL_VERSION_MAJOR != 3\n#error not OpenSSL 3\n#endif\nint main(void) { return 0; }"
    OTP_CRYPTO_OPENSSL_3
)
cmake_pop_check_state()
otp_application_version(crypto OTP_CRYPTO_VERSION)
set(_crypto_dir "${PROJECT_SOURCE_DIR}/lib/crypto/c_src")
set(_crypto_sources)

foreach(_name IN ITEMS
    crypto
    aead
    aes
    algorithms
    api_ng
    atoms
    bn
    cipher
    cmac
    common
    dh
    digest
    dss
    ec
    ecdh
    eddsa
    engine
    evp
    fips
    hash
    hmac
    info
    mac
    math
    pkey
    rand
    rsa
    srp
    hash_equals
    pbkdf2_hmac
)
    list(APPEND _crypto_sources "${_crypto_dir}/${_name}.c")
endforeach()

add_library(otp_crypto_nif MODULE ${_crypto_sources})
target_link_libraries(otp_crypto_nif PRIVATE BEAM::NIF otp_native_config OpenSSL::Crypto)
target_compile_definitions(otp_crypto_nif PRIVATE DISABLE_EVP_DH=0 DISABLE_EVP_HMAC=0)

if(OTP_CRYPTO_HAS_MEMCMP)
    target_compile_definitions(otp_crypto_nif PRIVATE HAVE_OPENSSL_CRYPTO_MEMCMP)
endif()

# Preserve the upstream default: FIPS support is disabled.
set(OTP_CRYPTO_TARGETS otp_crypto_nif)

if(OPENSSL_USE_STATIC_LIBS OR OPENSSL_CRYPTO_LIBRARY MATCHES "[.]a$")
    target_sources(otp_crypto_nif PRIVATE "${_crypto_dir}/crypto_callback.c")
else()
    target_compile_definitions(otp_crypto_nif PRIVATE HAVE_DYNAMIC_CRYPTO_LIB)
    add_library(otp_crypto_callback MODULE "${_crypto_dir}/crypto_callback.c")
    target_compile_definitions(otp_crypto_callback PRIVATE HAVE_DYNAMIC_CRYPTO_LIB)
    target_include_directories(otp_crypto_callback PRIVATE "${OPENSSL_INCLUDE_DIR}")
    target_link_libraries(otp_crypto_callback PRIVATE BEAM::NIF otp_native_config)
    list(APPEND OTP_CRYPTO_TARGETS otp_crypto_callback)
endif()

if(NOT OTP_CRYPTO_DISABLE_TEST_ENGINE)
    add_library(otp_crypto_test_engine MODULE "${_crypto_dir}/otp_test_engine.c")
    target_link_libraries(otp_crypto_test_engine PRIVATE BEAM::NIF otp_native_config OpenSSL::Crypto)
    list(APPEND OTP_CRYPTO_TARGETS otp_crypto_test_engine)
endif()

if(DEFINED OTP_LINUX_NATIVE_CFLAGS AND OTP_CRYPTO_OPENSSL_3)
    set_property(SOURCE "${_crypto_dir}/engine.c" "${_crypto_dir}/pkey.c"
        "${_crypto_dir}/otp_test_engine.c" APPEND PROPERTY COMPILE_OPTIONS -Wno-deprecated-declarations)
endif()

foreach(_target IN LISTS OTP_CRYPTO_TARGETS)
    otp_linux_native_flags(${_target} DED)
    target_compile_definitions(${_target} PRIVATE "$<$<CONFIG:Debug>:DEBUG>")
    if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
        target_compile_options(${_target} PRIVATE -g "$<IF:$<CONFIG:Debug>,-O0,-O2>"
            -Werror=undef -Werror=implicit -Werror=return-type
            -Wdeclaration-after-statement -Wall -Wstrict-prototypes)
        if(NOT _target STREQUAL otp_crypto_test_engine)
            target_compile_options(${_target} PRIVATE -Wmissing-prototypes)
        endif()
        target_compile_definitions(${_target} PRIVATE
            _THREAD_SAFE _REENTRANT POSIX_THREADS _POSIX_THREAD_SAFE_FUNCTIONS)
    endif()

    # Upstream compiles from c_src: its public NIF error tuples contain the
    # source basename. Preserve that __FILE__ convention with absolute inputs.
    if(MSVC)
        # cl preserves the basename when invoked with relative source inputs.
        # /pathmap applies the same mapping to __FILE__ and diagnostic paths.
        target_compile_options(${_target} PRIVATE "/pathmap:${_crypto_dir}=.")
    else()
        target_compile_options(${_target} PRIVATE "-fmacro-prefix-map=${_crypto_dir}/=")
    endif()

    if(_target STREQUAL otp_crypto_nif)
        set(_name crypto)
    elseif(_target STREQUAL otp_crypto_callback)
        set(_name crypto_callback)
    else()
        set(_name otp_test_engine)
    endif()

    set_target_properties(${_target} PROPERTIES
        PREFIX ""
        OUTPUT_NAME "${_name}"
        DEBUG_POSTFIX ".debug"
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/crypto/priv/lib/${OTP_TARGET}"
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/crypto/priv/lib/${OTP_TARGET}"
        INSTALL_RPATH_USE_LINK_PATH TRUE
    )
endforeach()

install(TARGETS ${OTP_CRYPTO_TARGETS}
    LIBRARY DESTINATION "lib/crypto-${OTP_CRYPTO_VERSION}/priv/lib"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    RUNTIME DESTINATION "lib/crypto-${OTP_CRYPTO_VERSION}/priv/lib"
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)
message(STATUS "OTP Crypto: OpenSSL ${OPENSSL_VERSION} from ${_openssl_root}")
