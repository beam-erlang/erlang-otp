# OTP's ordinary crypto NIF uses only public extension headers and OpenSSL.
find_package(OpenSSL REQUIRED COMPONENTS Crypto)
include(CheckCSourceCompiles)
include(CMakePushCheckState)
cmake_push_check_state(RESET)
unset(OTP_CRYPTO_HAS_MEMCMP CACHE)
unset(OTP_CRYPTO_HAS_ENGINE CACHE)
set(CMAKE_REQUIRED_LIBRARIES OpenSSL::Crypto)
check_c_source_compiles("#include <openssl/crypto.h>
int main(void) { return CRYPTO_memcmp(\"a\", \"b\", 1); }" OTP_CRYPTO_HAS_MEMCMP)
check_c_source_compiles("#include <openssl/opensslv.h>
#if defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER >= 0x3050000fL
#error No upstream test engine for this LibreSSL version
#endif
#include <openssl/engine.h>
int main(void) { ENGINE *e = ENGINE_new(); ENGINE_free(e); return 0; }" OTP_CRYPTO_HAS_ENGINE)
cmake_pop_check_state()

otp_application_version(crypto _crypto_version)
set(_crypto_dir "${PROJECT_SOURCE_DIR}/lib/crypto/c_src")
set(_crypto_output "${PROJECT_BINARY_DIR}/otp/lib/crypto-${_crypto_version}/priv/lib")
set(_crypto_sources)
foreach(_name crypto aead aes algorithms api_ng atoms bn cipher cmac common dh digest
        dss ec ecdh eddsa engine evp fips hash hmac info mac math pkey rand rsa srp
        hash_equals pbkdf2_hmac)
    list(APPEND _crypto_sources "${_crypto_dir}/${_name}.c")
endforeach()
add_library(otp_crypto_nif MODULE ${_crypto_sources})
set_target_properties(otp_crypto_nif PROPERTIES PREFIX "" OUTPUT_NAME crypto
    LIBRARY_OUTPUT_DIRECTORY "${_crypto_output}" INSTALL_RPATH_USE_LINK_PATH TRUE)
target_link_libraries(otp_crypto_nif PRIVATE BEAM::NIF OpenSSL::Crypto)
target_compile_definitions(otp_crypto_nif PRIVATE DISABLE_EVP_DH=0 DISABLE_EVP_HMAC=0)
if(WIN32)
    file(GLOB _openssl_provider_modules "${OPENSSL_ROOT_DIR}/lib/ossl-modules/*.dll")
    if(_openssl_provider_modules)
        target_compile_definitions(otp_crypto_nif PRIVATE OTP_BUNDLED_OPENSSL_MODULES)
        install(FILES ${_openssl_provider_modules}
            DESTINATION "lib/crypto-${_crypto_version}/priv/lib/ossl-modules")
    endif()
endif()
if(OTP_CRYPTO_HAS_MEMCMP)
    target_compile_definitions(otp_crypto_nif PRIVATE HAVE_OPENSSL_CRYPTO_MEMCMP)
endif()
# Upstream defaults to FIPS support disabled. Provider/FIPS certification is
# separate from building the normal Crypto application.
get_target_property(_openssl_library OpenSSL::Crypto IMPORTED_LOCATION)
set(_crypto_targets otp_crypto_nif)
if(_openssl_library MATCHES "\\.a$" AND NOT _openssl_library MATCHES "\\.dll\\.a$")
    target_sources(otp_crypto_nif PRIVATE "${_crypto_dir}/crypto_callback.c")
else()
    target_compile_definitions(otp_crypto_nif PRIVATE HAVE_DYNAMIC_CRYPTO_LIB)
    add_library(otp_crypto_callback MODULE "${_crypto_dir}/crypto_callback.c")
    target_compile_definitions(otp_crypto_callback PRIVATE HAVE_DYNAMIC_CRYPTO_LIB)
    target_link_libraries(otp_crypto_callback PRIVATE BEAM::NIF OpenSSL::Crypto)
    set_target_properties(otp_crypto_callback PROPERTIES PREFIX "" OUTPUT_NAME crypto_callback
        LIBRARY_OUTPUT_DIRECTORY "${_crypto_output}" INSTALL_RPATH_USE_LINK_PATH TRUE)
    list(APPEND _crypto_targets otp_crypto_callback)
endif()
if(OTP_CRYPTO_HAS_ENGINE)
    add_library(otp_crypto_test_engine MODULE "${_crypto_dir}/otp_test_engine.c")
    target_link_libraries(otp_crypto_test_engine PRIVATE BEAM::NIF OpenSSL::Crypto)
    set_target_properties(otp_crypto_test_engine PROPERTIES PREFIX "" OUTPUT_NAME otp_test_engine
        LIBRARY_OUTPUT_DIRECTORY "${_crypto_output}" INSTALL_RPATH_USE_LINK_PATH TRUE)
    list(APPEND _crypto_targets otp_crypto_test_engine)
endif()
install(TARGETS ${_crypto_targets}
    LIBRARY DESTINATION "lib/crypto-${_crypto_version}/priv/lib"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    RUNTIME DESTINATION "lib/crypto-${_crypto_version}/priv/lib"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
file(GENERATE OUTPUT "${PROJECT_BINARY_DIR}/crypto-dependency.txt" CONTENT
    "OpenSSL version: ${OPENSSL_VERSION}\nOpenSSL library: ${_openssl_library}\nCRYPTO_memcmp: ${OTP_CRYPTO_HAS_MEMCMP}\nTest engine: ${OTP_CRYPTO_HAS_ENGINE}\nFIPS support: disabled (upstream default)\n")
