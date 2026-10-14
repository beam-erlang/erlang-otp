# SPDX-License-Identifier: Apache-2.0
# Product and private build-host versions share the retained release table.
file(STRINGS "${PROJECT_SOURCE_DIR}/otp_versions.table" _version_row
    REGEX "^OTP-${PROJECT_VERSION} :" LIMIT_COUNT 1)
function(otp_application_version application output)
    if(NOT _version_row MATCHES "[ :]${application}-([^ ]+)")
        message(FATAL_ERROR "No ${application} version in OTP-${PROJECT_VERSION} table")
    endif()
    set(${output} "${CMAKE_MATCH_1}" PARENT_SCOPE)
endfunction()
