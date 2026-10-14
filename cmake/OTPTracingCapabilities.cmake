# SPDX-License-Identifier: Apache-2.0
# Read a compiled VM capability through the selected public SDK. No VM startup,
# Erlang command, source header or private configuration is involved.
unset(OTP_TRACE_QUERY_COMPILED CACHE)
unset(OTP_TRACE_QUERY_RESULT CACHE)
try_run(OTP_TRACE_QUERY_RESULT OTP_TRACE_QUERY_COMPILED
    SOURCE_FROM_CONTENT otp_trace_backend.c
    "#include <beam/native.h>
#include <stdio.h>
int main(void) {
    switch (beam_native_trace_backend_get()) {
    case BEAM_NATIVE_TRACE_NONE: puts(\"none\"); break;
    case BEAM_NATIVE_TRACE_DTRACE: puts(\"dtrace\"); break;
    case BEAM_NATIVE_TRACE_SYSTEMTAP: puts(\"systemtap\"); break;
    case BEAM_NATIVE_TRACE_LTTNG: puts(\"lttng\"); break;
    default: return 2;
    }
    return 0;
}"
    LINK_LIBRARIES BEAM::RuntimeStatic BEAM::NIF
    COMPILE_OUTPUT_VARIABLE _trace_compile_output
    RUN_OUTPUT_VARIABLE OTP_NATIVE_TRACE_BACKEND)
if(NOT OTP_TRACE_QUERY_COMPILED OR NOT OTP_TRACE_QUERY_RESULT STREQUAL "0")
    message(FATAL_ERROR "Selected SDK lacks a usable public native tracing capability query: ${_trace_compile_output}")
endif()
string(STRIP "${OTP_NATIVE_TRACE_BACKEND}" OTP_NATIVE_TRACE_BACKEND)
if(NOT OTP_NATIVE_TRACE_BACKEND MATCHES "^(none|dtrace|systemtap|lttng)$")
    message(FATAL_ERROR "Unknown SDK tracing backend: ${OTP_NATIVE_TRACE_BACKEND}")
endif()
message(STATUS "Selected SDK native tracing backend: ${OTP_NATIVE_TRACE_BACKEND}")
