# The product consumes only an explicitly selected installed process runtime.

set(BEAM_SDK_ROOT "" CACHE PATH "Installed BEAM SDK prefix")
set(OTP_BEAM_FLAVOR "emu" CACHE STRING "Required emulator flavor: emu or jit")
set_property(CACHE OTP_BEAM_FLAVOR PROPERTY STRINGS emu jit)

if(CMAKE_CONFIGURATION_TYPES)
    message(FATAL_ERROR "The OTP build supports single-config Release or Debug configurations")
endif()
if(NOT DEFINED CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL "")
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Single-config build type" FORCE)
elseif(NOT CMAKE_BUILD_TYPE MATCHES "^(Release|Debug)$")
    message(FATAL_ERROR "CMAKE_BUILD_TYPE must be Release or Debug")
endif()
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Release Debug)

if(NOT IS_ABSOLUTE "${BEAM_SDK_ROOT}" OR NOT IS_DIRECTORY "${BEAM_SDK_ROOT}")
    message(FATAL_ERROR "Set BEAM_SDK_ROOT to an absolute installed BEAM SDK prefix")
endif()

if(NOT OTP_BEAM_FLAVOR MATCHES "^(emu|jit)$")
    message(FATAL_ERROR "Set OTP_BEAM_FLAVOR to emu or jit")
endif()

# The OTP selection is authoritative, including when one SDK contains all four
# configurations. A conflicting explicit selector is an error, not a fallback.
if(DEFINED BEAM_RUNTIME_FLAVOR AND NOT BEAM_RUNTIME_FLAVOR STREQUAL OTP_BEAM_FLAVOR)
    message(FATAL_ERROR "BEAM_RUNTIME_FLAVOR conflicts with OTP_BEAM_FLAVOR")
endif()
set(BEAM_RUNTIME_FLAVOR "${OTP_BEAM_FLAVOR}")

# Discover the package directory through installed metadata, including custom
# relative installation libdirs. Never search a sibling build or default paths.
file(REAL_PATH "${BEAM_SDK_ROOT}" BEAM_SDK_ROOT)
set(_sdk_manifest_path "${BEAM_SDK_ROOT}/manifest.json")
if(NOT EXISTS "${_sdk_manifest_path}")
    message(FATAL_ERROR "Selected SDK lacks installed manifest.json")
endif()
file(REAL_PATH "${_sdk_manifest_path}" _sdk_manifest_path)
cmake_path(IS_PREFIX BEAM_SDK_ROOT "${_sdk_manifest_path}" NORMALIZE _manifest_inside)
if(NOT _manifest_inside)
    message(FATAL_ERROR "Selected SDK manifest escapes its installed prefix")
endif()
file(READ "${_sdk_manifest_path}" _sdk_manifest)
string(JSON _sdk_schema ERROR_VARIABLE _sdk_json_error GET "${_sdk_manifest}" schema)
string(JSON _sdk_schema_type ERROR_VARIABLE _sdk_type_error TYPE "${_sdk_manifest}" schema)
if(_sdk_json_error OR _sdk_type_error OR NOT _sdk_schema_type STREQUAL "NUMBER"
        OR NOT _sdk_schema STREQUAL "1")
    message(FATAL_ERROR "Selected SDK has an invalid or unsupported manifest schema")
endif()
# Reject incomplete identities and ambiguous configuration inventories before
# package selection can silently choose one of several matching records.
foreach(_field IN ITEMS source_id toolchain_id)
    string(JSON _type ERROR_VARIABLE _type_error TYPE "${_sdk_manifest}" "${_field}")
    string(JSON _identity ERROR_VARIABLE _identity_error GET "${_sdk_manifest}" "${_field}")
    string(LENGTH "${_identity}" _identity_length)
    if(_type_error OR _identity_error OR NOT _type STREQUAL "STRING"
            OR NOT _identity_length EQUAL 64 OR NOT _identity MATCHES "^[0-9a-f]+$")
        message(FATAL_ERROR "Selected SDK manifest has an invalid ${_field} identity")
    endif()
endforeach()
string(JSON _type ERROR_VARIABLE _sdk_json_error TYPE "${_sdk_manifest}" variants)
if(_sdk_json_error OR NOT _type STREQUAL "ARRAY")
    message(FATAL_ERROR "Selected SDK manifest has an invalid configuration inventory")
endif()
string(JSON _variant_count LENGTH "${_sdk_manifest}" variants)
if(_variant_count EQUAL 0)
    message(FATAL_ERROR "Selected SDK manifest has an empty configuration inventory")
endif()
math(EXPR _last_variant "${_variant_count} - 1")
set(_sdk_configurations "")
foreach(_index RANGE 0 ${_last_variant})
    string(JSON _flavor ERROR_VARIABLE _flavor_error GET "${_sdk_manifest}" variants ${_index} flavor)
    string(JSON _build_type ERROR_VARIABLE _build_type_error GET "${_sdk_manifest}" variants ${_index} build_type)
    if(_flavor_error OR _build_type_error OR NOT _flavor MATCHES "^(emu|jit)$"
            OR NOT _build_type MATCHES "^(Release|Debug)$")
        message(FATAL_ERROR "Selected SDK manifest has an invalid runtime configuration")
    endif()
    set(_configuration "${_flavor}/${_build_type}")
    if(_configuration IN_LIST _sdk_configurations)
        message(FATAL_ERROR "Selected SDK manifest has a duplicate runtime configuration: ${_configuration}")
    endif()
    list(APPEND _sdk_configurations "${_configuration}")
    string(JSON _type ERROR_VARIABLE _type_error TYPE "${_sdk_manifest}" variants ${_index} build_id)
    string(JSON _identity ERROR_VARIABLE _identity_error GET "${_sdk_manifest}" variants ${_index} build_id)
    string(LENGTH "${_identity}" _identity_length)
    if(_type_error OR _identity_error OR NOT _type STREQUAL "STRING"
            OR NOT _identity_length EQUAL 64 OR NOT _identity MATCHES "^[0-9a-f]+$")
        message(FATAL_ERROR "Selected SDK manifest has an invalid build_id identity")
    endif()
endforeach()
string(JSON _sdk_package_dir ERROR_VARIABLE _sdk_json_error GET "${_sdk_manifest}" package_dir)
string(JSON _type ERROR_VARIABLE _type_error TYPE "${_sdk_manifest}" package_dir)
if(_sdk_json_error OR _type_error OR NOT _type STREQUAL "STRING"
        OR _sdk_package_dir STREQUAL "" OR IS_ABSOLUTE "${_sdk_package_dir}"
        OR _sdk_package_dir MATCHES "(^|/)\\.\\.(/|$)" OR _sdk_package_dir MATCHES "\\\\")
    message(FATAL_ERROR "Selected SDK has an invalid relative package directory")
endif()
set(_sdk_package_dir "${BEAM_SDK_ROOT}/${_sdk_package_dir}")
file(REAL_PATH "${_sdk_package_dir}" _sdk_package_dir)
cmake_path(IS_PREFIX BEAM_SDK_ROOT "${_sdk_package_dir}" NORMALIZE _package_inside)
if(NOT _package_inside OR NOT IS_DIRECTORY "${_sdk_package_dir}")
    message(FATAL_ERROR "Selected SDK package directory is missing or escapes its prefix")
endif()
set(_sdk_config "${_sdk_package_dir}/BEAMConfig.cmake")
file(REAL_PATH "${_sdk_config}" _sdk_config)
cmake_path(IS_PREFIX BEAM_SDK_ROOT "${_sdk_config}" NORMALIZE _config_inside)
if(NOT _config_inside OR NOT EXISTS "${_sdk_config}")
    message(FATAL_ERROR "Selected SDK package is missing or escapes its prefix")
endif()
# Give a stable diagnostic for a required public field before package JSON
# extraction could report only a low-level parser error.
string(JSON _sdk_host_triple ERROR_VARIABLE _sdk_json_error GET "${_sdk_manifest}" host_triple)
if(_sdk_json_error OR _sdk_host_triple STREQUAL "")
    message(FATAL_ERROR "Selected SDK lacks BEAM_SDK_HOST_TRIPLE; rebuild and reinstall the SDK, then reconfigure OTP")
endif()
string(JSON _type ERROR_VARIABLE _type_error TYPE "${_sdk_manifest}" host_triple)
if(_type_error OR NOT _type STREQUAL "STRING"
        OR NOT _sdk_host_triple MATCHES "^[A-Za-z0-9][A-Za-z0-9_.+-]*$")
    message(FATAL_ERROR "Selected SDK BEAM_SDK_HOST_TRIPLE must be a safe single directory component")
endif()
set(BEAM_DIR "${_sdk_package_dir}"
    CACHE PATH "Selected installed SDK package" FORCE
)

# OTP's release table pins the required BEAM/ERTS release exactly.
# Require the selected package to supply its runtime triple, even if a caller
# previously defined a variable or cache entry with the same name.
set(BEAM_SDK_HOST_TRIPLE "")
find_package(BEAM ${OTP_ERTS_VERSION} EXACT CONFIG REQUIRED
    PATHS "${BEAM_DIR}"
    NO_DEFAULT_PATH
)

if(NOT BEAM_SDK_VERSION STREQUAL OTP_ERTS_VERSION)
    message(FATAL_ERROR
        "Selected SDK version '${BEAM_SDK_VERSION}' does not match "
        "required BEAM version '${OTP_ERTS_VERSION}'"
    )
endif()

set(_sdk_required_targets Runtime NIF Driver)
if(NOT WIN32)
    list(APPEND _sdk_required_targets ChildSetup)
endif()
foreach(_target IN LISTS _sdk_required_targets)
    if(NOT TARGET BEAM::${_target})
        message(FATAL_ERROR "Selected SDK lacks BEAM::${_target}")
    endif()
endforeach()
if(TARGET BEAM::RuntimeStatic)
    message(FATAL_ERROR "Selected SDK exposes the removed BEAM::RuntimeStatic interface")
endif()

# Native application loaders use the selected VM's exact runtime architecture
# string. Keep one output target name rather than guessing it from this host.
if(NOT DEFINED BEAM_SDK_HOST_TRIPLE OR BEAM_SDK_HOST_TRIPLE STREQUAL "")
    message(FATAL_ERROR
        "Selected SDK lacks BEAM_SDK_HOST_TRIPLE; rebuild and reinstall the SDK, then reconfigure OTP")
endif()
if(NOT BEAM_SDK_HOST_TRIPLE MATCHES "^[A-Za-z0-9][A-Za-z0-9_.+-]*$")
    message(FATAL_ERROR "Selected SDK BEAM_SDK_HOST_TRIPLE must be a safe single directory component")
endif()
set(OTP_TARGET "${BEAM_SDK_HOST_TRIPLE}")

# Check the SDK's exported identity against the OTP sources and build settings.
if(NOT BEAM_SDK_ERTS_VERSION STREQUAL OTP_ERTS_VERSION)
    message(FATAL_ERROR
        "Selected SDK ERTS version does not match OTP sources; "
        "select the matching BEAM SDK"
    )
endif()

if(NOT BEAM_SDK_FLAVOR STREQUAL OTP_BEAM_FLAVOR
    OR NOT BEAM_SDK_SYSTEM_NAME STREQUAL CMAKE_SYSTEM_NAME
)
    message(FATAL_ERROR "Selected SDK flavor/platform does not match this OTP configuration")
endif()
if(NOT BEAM_SDK_BUILD_TYPE STREQUAL CMAKE_BUILD_TYPE)
    message(FATAL_ERROR "Selected SDK build type does not match this OTP configuration")
endif()
set(CMAKE_TRY_COMPILE_CONFIGURATION "${CMAKE_BUILD_TYPE}")

# Validate the selected SDK, native host and actual compiler targets without
# retargeting compilers or requiring a separate architecture setting.

function(otp_check_native_architecture)
    # The supported SDKs name architecture families; OTP requires their 64-bit ABI.
    if(BEAM_SDK_ARCHITECTURE STREQUAL "x86")
        set(_sdk_arch x86_64)
        set(_compiler_arch "defined(__x86_64__) || defined(_M_X64)")
    elseif(BEAM_SDK_ARCHITECTURE STREQUAL "arm")
        set(_sdk_arch arm64)
        set(_compiler_arch "defined(__aarch64__) || defined(_M_ARM64)")
    else()
        message(FATAL_ERROR "Unsupported BEAM SDK architecture '${BEAM_SDK_ARCHITECTURE}'")
    endif()

    if(CMAKE_CROSSCOMPILING OR NOT CMAKE_HOST_SYSTEM_NAME STREQUAL CMAKE_SYSTEM_NAME)
        message(FATAL_ERROR "The core OTP build requires a native host and target")
    endif()

    foreach(_processor IN ITEMS CMAKE_HOST_SYSTEM_PROCESSOR CMAKE_SYSTEM_PROCESSOR)
        string(TOLOWER "${${_processor}}" _actual_arch)

        if(_actual_arch MATCHES "^(x86_64|amd64)$")
            set(_actual_arch x86_64)
        elseif(_actual_arch MATCHES "^(aarch64|arm64)$")
            set(_actual_arch arm64)
        endif()

        if(NOT _actual_arch STREQUAL _sdk_arch)
            message(FATAL_ERROR
                "Selected SDK requires native ${_sdk_arch}, "
                "but ${_processor} is '${${_processor}}'; select a matching SDK and native toolchain"
            )
        endif()
    endforeach()

    # Probe both languages on every configure, including configuration-specific
    # flags, so neither cached platform metadata nor a previous probe can hide a
    # changed compiler target. No executable is linked or run.
    string(CONCAT _probe
        "#if !(${_compiler_arch})\n"
        "#error Incorrect native compiler target\n"
        "#endif\n"
        "typedef char native_pointer_width[(sizeof(void *) == 8) ? 1 : -1];\n"
        "int native_architecture_probe(void) { return 0; }\n"
    )
    set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

    if(CMAKE_CONFIGURATION_TYPES)
        set(_configurations "${CMAKE_CONFIGURATION_TYPES}")
        list(POP_FRONT _configurations _first_configuration)
    else()
        set(_first_configuration "${CMAKE_BUILD_TYPE}")
        set(_configurations "")
    endif()

    # IN ITEMS preserves an empty build type for a single-configuration generator.
    foreach(_configuration IN ITEMS "${_first_configuration}" ${_configurations})
        set(CMAKE_TRY_COMPILE_CONFIGURATION "${_configuration}")
        try_compile(_compiler_arch_matches
            SOURCE_FROM_CONTENT native_architecture.c "${_probe}"
            SOURCE_FROM_CONTENT native_architecture.cpp "${_probe}"
            # Make custom configurations available to the nested build as well.
            CMAKE_FLAGS "-DCMAKE_CONFIGURATION_TYPES:STRING=${_configuration}"
            NO_CACHE
            OUTPUT_VARIABLE _probe_output
        )

        if(NOT _compiler_arch_matches)
            message(FATAL_ERROR
                "Selected SDK requires native 64-bit ${_sdk_arch} C and C++ compiler targets; "
                "check the selected compilers and flags.\n${_probe_output}"
            )
        endif()
    endforeach()
endfunction()

otp_check_native_architecture()

if(APPLE AND CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS BEAM_SDK_DEPLOYMENT_TARGET)
    message(FATAL_ERROR "OTP deployment target is older than the SDK deployment floor")
endif()

# Preload implementations, execution seeds and inspection sources are SDK-owned.
# OTP stages and installs the public SDK assets without a local source copy.

# Record SDK metadata and artifact hashes for diagnostics and qualification.
set(_sdk_artifacts BEAM_SDK_ARCHIVE)
set(_child_setup "")
set(_child_hash "")
if(NOT WIN32)
    get_target_property(_child_setup BEAM::ChildSetup IMPORTED_LOCATION)
    list(APPEND _sdk_artifacts _child_setup)
endif()
foreach(_artifact IN LISTS _sdk_artifacts)
    if(NOT IS_ABSOLUTE "${${_artifact}}" OR NOT EXISTS "${${_artifact}}"
            OR IS_DIRECTORY "${${_artifact}}")
        message(FATAL_ERROR "Selected SDK lacks its public ${_artifact} artifact")
    endif()
    file(REAL_PATH "${${_artifact}}" _artifact_path)
    cmake_path(IS_PREFIX BEAM_SDK_ROOT "${_artifact_path}" NORMALIZE _artifact_inside)
    if(NOT _artifact_inside)
        message(FATAL_ERROR "Selected SDK ${_artifact} artifact escapes its prefix")
    endif()
    set(${_artifact} "${_artifact_path}")
endforeach()
if(NOT WIN32)
    file(SHA256 "${_child_setup}" _child_hash)
endif()
file(SHA256 "${BEAM_SDK_ARCHIVE}" _runtime_hash)
file(SHA256 "${_sdk_manifest_path}" _sdk_manifest_hash)
file(SHA256 "${_sdk_config}" _sdk_config_hash)
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/templates/sdk_selection.txt.in"
    "${PROJECT_BINARY_DIR}/sdk-selection.txt"
    @ONLY
)
