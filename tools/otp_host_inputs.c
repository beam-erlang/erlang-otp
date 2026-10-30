/* SPDX-License-Identifier: Apache-2.0 */
#include "otp_host_inputs.h"
#include "otp_host_assets.h"
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct acquisition {
    unsigned char *arguments;
    char *helper;
} acquisition;
typedef struct failure { beam_status status; beam_error *error; } failure;
typedef struct buffer {
    unsigned char *data;
    size_t size, capacity;
    failure *failure;
} buffer;

static void report(failure *f, beam_status status, int code, const char *format, ...)
{
    if (f->status != BEAM_OK) return;
    f->status = status;
    if (f->error) {
        va_list args;
        f->error->native_code = code;
        va_start(args, format);
        vsnprintf(f->error->message, sizeof(f->error->message), format, args);
        va_end(args);
    }
}

static void put(buffer *b, const void *data, size_t size)
{
    if (b->failure->status != BEAM_OK || !size) return;
    if (size > SIZE_MAX - b->size) {
        report(b->failure, BEAM_OUT_OF_MEMORY, 0, "startup input is too large");
        return;
    }
    size_t needed = b->size + size;
    if (needed > b->capacity) {
        size_t capacity = b->capacity ? b->capacity : 256;
        while (capacity < needed) {
            if (capacity > SIZE_MAX / 2) { capacity = needed; break; }
            capacity *= 2;
        }
        void *next = realloc(b->data, capacity);
        if (!next) {
            report(b->failure, BEAM_OUT_OF_MEMORY, ENOMEM, "cannot allocate startup input");
            return;
        }
        b->data = next; b->capacity = capacity;
    }
    memcpy(b->data + b->size, data, size);
    b->size = needed;
}
static void byte(buffer *b, unsigned value)
{ unsigned char c = (unsigned char)value; put(b, &c, 1); }
static void number(buffer *b, size_t value)
{
    if (value > UINT32_MAX) {
        report(b->failure, BEAM_INVALID_ARGUMENT, 0, "startup input exceeds ETF limits");
        return;
    }
    unsigned char bytes[] = {value >> 24, value >> 16, value >> 8, value};
    put(b, bytes, sizeof(bytes));
}
static void atom(buffer *b, const char *value)
{
    size_t size = strlen(value);
    if (size > 255) {
        report(b->failure, BEAM_INVALID_ARGUMENT, 0, "invalid startup atom");
        return;
    }
    byte(b, 119); byte(b, size); put(b, value, size);
}
static void list(buffer *b, size_t size) { byte(b, 108); number(b, size); }
static void binary(buffer *b, const char *value)
{ size_t size = strlen(value); byte(b, 109); number(b, size); put(b, value, size); }

/* Return one scalar, zero at the terminator, or -1 for invalid UTF-8. */
static int scalar(const unsigned char **cursor, unsigned *value)
{
    const unsigned char *p = *cursor;
    if (!*p) return 0;
    unsigned c = *p++, rest = 0, minimum = 0;
    if (c >= 0xc2 && c <= 0xdf) { c &= 31; rest = 1; minimum = 128; }
    else if (c >= 0xe0 && c <= 0xef) { c &= 15; rest = 2; minimum = 2048; }
    else if (c >= 0xf0 && c <= 0xf4) { c &= 7; rest = 3; minimum = 65536; }
    else if (c >= 128) return -1;
    while (rest--) {
        if ((*p & 0xc0) != 0x80) return -1;
        c = (c << 6) | (*p++ & 63);
    }
    if (c < minimum || c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff)) return -1;
    *cursor = p; *value = c; return 1;
}
static int utf8_length(const char *value, size_t *count)
{
    const unsigned char *p = (const unsigned char *)value;
    unsigned c; int result;
    *count = 0;
    while ((result = scalar(&p, &c)) > 0) ++*count;
    return result == 0;
}
#ifndef _WIN32
static char *path(failure *f, const char *root, const char *relative)
{
    if (f->status != BEAM_OK) return NULL;
    size_t n = strlen(root), m = strlen(relative);
    if (n > SIZE_MAX - 2 || m > SIZE_MAX - n - 2) {
        report(f, BEAM_OUT_OF_MEMORY, 0, "installation path is too long");
        return NULL;
    }
    char *result = malloc(n + m + 2);
    if (!result) report(f, BEAM_OUT_OF_MEMORY, ENOMEM, "cannot allocate installation path");
    else snprintf(result, n + m + 2, "%s/%s", root, relative);
    return result;
}
#endif
static void release(acquisition *data)
{
    if (!data) return;
    free(data->arguments); free(data->helper); free(data);
}
static int absolute_root(const char *root)
{
    if (!root) return 0;
#ifdef _WIN32
    return (((root[0] >= 'A' && root[0] <= 'Z') || (root[0] >= 'a' && root[0] <= 'z')) &&
            root[1] == ':' && (root[2] == '/' || root[2] == '\\')) ||
           (root[0] == '\\' && root[1] == '\\');
#else
    return root[0] == '/';
#endif
}
void otp_host_release(otp_host_inputs *inputs)
{
    if (!inputs) return;
    release(inputs->storage);
    *inputs = (otp_host_inputs){0};
}
beam_status otp_host_acquire(const char *root, size_t argc,
                             const char *const *argv, otp_host_inputs *output,
                             beam_error *error)
{
    failure state = {BEAM_OK, error};
    size_t root_length;
    if (error) *error = (beam_error){0};
    if (!output || output->storage || !absolute_root(root) || argc > UINT32_MAX ||
        (argc && !argv) || !utf8_length(root, &root_length)) {
        report(&state, BEAM_INVALID_ARGUMENT, 0, "invalid OTP startup acquisition arguments");
        return state.status;
    }
    for (size_t i = 0; i < argc; ++i) {
        if (!argv[i]) {
            report(&state, BEAM_INVALID_ARGUMENT, 0, "null OTP startup argument");
            return state.status;
        }
    }
    if (strcmp(beam_build_id(), OTP_SDK_BUILD_ID)) {
        report(&state, BEAM_INVALID_ARGUMENT, 0, "linked runtime differs from selected SDK identity");
        return state.status;
    }
    acquisition *data = calloc(1, sizeof(*data));
    if (!data) {
        report(&state, BEAM_OUT_OF_MEMORY, ENOMEM, "cannot allocate OTP startup acquisition");
        return state.status;
    }
    buffer arguments = {.failure = &state};
#ifndef _WIN32
    data->helper = path(&state, root, OTP_CHILD_HELPER);
#endif
    byte(&arguments, 131); list(&arguments, 2); atom(&arguments, "init");
    list(&arguments, argc);
    for (size_t i = 0; i < argc && state.status == BEAM_OK; ++i) binary(&arguments, argv[i]);
    byte(&arguments, 106); byte(&arguments, 106);
    data->arguments = arguments.data;
    if (state.status != BEAM_OK) { release(data); return state.status; }
    *output = (otp_host_inputs){
        .composition = {.struct_size = sizeof(beam_composition_options),
            .preload_count = OTP_PRELOAD_COUNT, .preloads = otp_preloads,
            .builtin_nif_count = OTP_NIF_COUNT, .builtin_nifs = otp_nifs,
            .embedded_dependency_count = sizeof(otp_embedded_dependencies) / sizeof(*otp_embedded_dependencies),
            .embedded_dependencies = otp_embedded_dependencies,
            .builtin_driver_count = OTP_DRIVER_COUNT, .builtin_drivers = otp_drivers,
            .program_helper = data->helper,
            .native_admission = BEAM_NATIVE_NIFS | BEAM_NATIVE_DRIVERS | BEAM_NATIVE_PORTS | BEAM_NATIVE_DISTRIBUTION},
        .entry = {"erl_init", "start", {data->arguments, arguments.size}},
        .storage = data};
    return BEAM_OK;
}
