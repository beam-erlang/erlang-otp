/* SPDX-License-Identifier: Apache-2.0 */
#define _XOPEN_SOURCE 700
#include <beam/beam.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sdk_selection.h"
#ifdef _WIN32
#include <direct.h>
#define realpath(path, unused) _fullpath(NULL, path, 0)
#endif

static int fail_status(const char *operation, beam_status status,
                       const beam_error *error)
{
    fprintf(stderr, "%s: %s%s%s\n", operation, beam_status_message(status),
            error && error->message[0] ? ": " : "",
            error ? error->message : "");
    return 1;
}

static int atom_equals(beam_buffer bytes, const char *expected)
{
    size_t length, offset;
    if (bytes.size < 3 || bytes.data[0] != 131)
        return 0;
    if (bytes.data[1] == 119 || bytes.data[1] == 115) {
        length = bytes.data[2];
        offset = 3;
    } else if ((bytes.data[1] == 118 || bytes.data[1] == 100) && bytes.size >= 4) {
        length = ((size_t)bytes.data[2] << 8) | bytes.data[3];
        offset = 4;
    } else {
        return 0;
    }
    return bytes.size == offset + length && strlen(expected) == length &&
           memcmp(bytes.data + offset, expected, length) == 0;
}

int main(int argc, char **argv)
{
    static const unsigned char flavor_argument[] = {
        131, 108, 0, 0, 0, 1, 119, 10,
        'e', 'm', 'u', '_', 'f', 'l', 'a', 'v', 'o', 'r', 106
    };
    beam_system *system = NULL;
    beam_vm *vm = NULL;
    beam_vm_options options;
    beam_error error = {0};
    beam_result result = {0};
    beam_status status;
    const char *const *core = NULL;
    size_t core_count = 0, required = 0;
    char *loaded = NULL, *expected = NULL, *actual = NULL;
    int failed = 1, halt_status = 0;

    if (argc != 2) {
        fputs("usage: otp_sdk_probe <selected-executable>\n", stderr);
        return 1;
    }
    if (strncmp(beam_version(), "BEAM/Erlang " OTP_SDK_VERSION " ",
                sizeof("BEAM/Erlang " OTP_SDK_VERSION " ") - 1) != 0) {
        fputs("Loaded runtime version does not match the selected SDK\n", stderr);
        return 1;
    }
    if (strcmp(beam_build_id(), OTP_SDK_BUILD_ID)) {
        fputs("Linked runtime identity does not match the selected SDK\n", stderr);
        return 1;
    }
    status = beam_library_path(NULL, 0, &required, &error);
    if (status != BEAM_OK)
        return fail_status("query runtime path", status, &error);
    loaded = malloc(required);
    if (!loaded)
        return 1;
    status = beam_library_path(loaded, required, &required, &error);
    if (status != BEAM_OK) {
        fail_status("read runtime path", status, &error);
        goto cleanup;
    }
    expected = realpath(argv[1], NULL);
    actual = realpath(loaded, NULL);
    if (!expected || !actual || strcmp(expected, actual) != 0) {
        fprintf(stderr, "Loaded runtime differs from selected SDK: %s\n", loaded);
        goto cleanup;
    }
    status = beam_core_modules(&core, &core_count);
    if (status != BEAM_OK || !core || !core_count) {
        fputs("Public embedded-core inventory is unavailable\n", stderr);
        goto cleanup;
    }
    status = beam_init(&system, &error);
    if (status != BEAM_OK) {
        fail_status("initialize system", status, &error);
        goto cleanup;
    }
    beam_vm_options_init(&options);
    status = beam_vm_init(system, &options, &vm, &error);
    if (status != BEAM_OK) {
        fail_status("initialize bare VM", status, &error);
        goto cleanup;
    }
    status = beam_vm_start(vm, &error);
    if (status != BEAM_OK) {
        fail_status("start bare VM", status, &error);
        goto cleanup;
    }
    status = beam_vm_call(vm, "erlang", "system_info",
                          (beam_bytes){flavor_argument, sizeof flavor_argument},
                          &result);
    if (status != BEAM_OK) {
        fail_status("query runtime flavor", status, NULL);
        goto cleanup;
    }
    if (result.kind != BEAM_RETURN || !atom_equals(result.value, OTP_SDK_FLAVOR)) {
        fputs("Executing runtime flavor does not match the selected SDK\n", stderr);
        goto cleanup;
    }
    printf("SDK %s flavor=%s build-id=%s core-modules=%zu\n",
           OTP_SDK_VERSION, OTP_SDK_FLAVOR, OTP_SDK_BUILD_ID, core_count);
    failed = 0;

cleanup:
    beam_result_release(&result);
    if (vm) {
        status = beam_vm_terminate(&vm, &halt_status);
        if (status != BEAM_OK || halt_status != 0) {
            fail_status("terminate VM", status, NULL);
            failed = 1;
        }
    }
    if (system) {
        status = beam_terminate(&system);
        if (status != BEAM_OK) {
            fail_status("terminate system", status, NULL);
            failed = 1;
        }
    }
    free(expected);
    free(actual);
    free(loaded);
    return failed;
}
