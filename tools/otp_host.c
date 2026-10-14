/* SPDX-License-Identifier: Apache-2.0 */
#define _GNU_SOURCE
#include <beam/beam.h>
#include "otp_host_inputs.h"
#include "otp_host_version.h"
#include <errno.h>
#ifndef _WIN32
#include <langinfo.h>
#include <unistd.h>
#else
#include "otp_windows.h"
#define strdup _strdup
#define main otp_utf8_main
#endif
#include <limits.h>
#include <locale.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#ifdef __APPLE__
#include <mach-o/dyld.h>
#include <xlocale.h>
#endif

/* Distribution policy lives here. All VM work uses the installed public SDK. */
static void fail(const char *message)
{
    fprintf(stderr, "erl: %s\n", message);
    exit(1);
}
static char *directory(const char *file)
{
    char *copy = strdup(file);
    if (!copy) fail("out of memory");
    char *slash = strrchr(copy, '/');
    if (!slash) fail("invalid installed path");
    *slash = 0; return copy;
}
static void configure(beam_vm_options *options, beam_error *error)
{
    beam_host_info info = {.struct_size = sizeof(info)};
    if (beam_query_host(&info, error) != BEAM_OK) fail(error->message);
    beam_vm_options_init(options);
    options->schedulers = info.configured_cpus ? info.configured_cpus : 1;
    options->schedulers_online = info.available_cpus ? info.available_cpus :
        (info.online_cpus ? info.online_cpus : options->schedulers);
    if (info.available_cpus && info.quota_cpus && info.quota_cpus < options->schedulers_online)
        options->schedulers_online = info.quota_cpus;
    options->dirty_cpu_schedulers = options->schedulers;
    options->dirty_cpu_schedulers_online = options->schedulers_online;
    options->dirty_io_schedulers = 10;
    const char *value = getenv("ERL_THREAD_POOL_SIZE");
    if (value && strlen(value) < 21) {
        int n = atoi(value); options->async_threads = n > 1024 ? 1024 : (n < 0 ? 0 : (unsigned)n);
    }
    value = getenv("ERL_MAX_ETS_TABLES");
    if (value && strlen(value) < 21) options->ets_limit = atoi(value);
    value = getenv("ERL_FULLSWEEP_AFTER");
    if (value && strlen(value) < 21) options->fullsweep_after = (uint16_t)atoi(value);
    value = getenv("ERL_MAX_PORTS");
    if (value && strlen(value) < 21) {
        int n = atoi(value); options->port_limit = n < 0 ? 0 : (unsigned)n;
        options->port_limit_ignore_files = 1;
    }
#if defined(__APPLE__) || defined(_WIN32)
    /* Pinned OTP defaults to Unicode filenames on Darwin independently of
     * LC_CTYPE (erts/emulator/sys/common/erl_sys_common_misc.c). */
    options->filename_encoding = BEAM_FILENAME_UTF8;
#else
    locale_t locale = newlocale(LC_CTYPE_MASK, "", (locale_t)0);
    options->filename_encoding = locale && !strcmp(nl_langinfo_l(CODESET, locale), "UTF-8") ?
        BEAM_FILENAME_UTF8 : BEAM_FILENAME_LATIN1;
    if (locale) freelocale(locale);
#endif
    options->execution = BEAM_PROCESS_OWNED;
    options->process_policy = BEAM_PROCESS_SIGNALS | BEAM_PROCESS_STDIO | BEAM_PROCESS_DIAGNOSTICS;
    const char *program = getenv("PROGNAME");
    options->program_name = program ? program : "erl";
}

static const char *option_value(int *index, int argc, char **argv, size_t prefix)
{
    const char *value = argv[*index] + prefix;
    if (!*value) {
        if (++*index >= argc) fail("missing emulator option value");
        value = argv[*index];
    }
    return value;
}
static size_t positive_number(const char *value, int zero_allowed)
{
    char *end; unsigned long long n;
    if (!isdigit((unsigned char)*value)) fail("invalid numeric emulator option");
    errno = 0; n = strtoull(value, &end, 10);
    if (errno || *end || n > SIZE_MAX || (!n && !zero_allowed)) fail("invalid numeric emulator option");
    return (size_t)n;
}
static unsigned thread_count(const char *value, int zero_allowed)
{
    size_t n = positive_number(value, zero_allowed);
    if (n > UINT_MAX) fail("thread count is too large");
    return (unsigned)n;
}
static void scheduler_pair(const char *value, unsigned *total, unsigned *online)
{
    char *end; long first, second;
    errno = 0; first = strtol(value, &end, 10);
    if (errno || end == value || (*end && *end != ':')) fail("invalid scheduler count");
    second = first;
    if (*end == ':') {
        const char *next = end + 1;
        errno = 0; second = strtol(next, &end, 10);
        if (errno || end == next || *end) fail("invalid scheduler online count");
    }
    if (first <= 0) first += *total;
    if (second <= 0) second += *online;
    if (first < 1 || (unsigned long long)first > UINT_MAX || second < 1 || second > first)
        fail("scheduler counts are outside the supported range");
    *total = (unsigned)first; *online = (unsigned)second;
}
static int runtime_arguments(beam_vm_options *options, int argc, char **argv)
{
    int output = 1, separated = 0;
    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--")) {
            separated = 1;
            for (++i; i < argc; ++i) argv[output++] = argv[i];
            break;
        }
        /* erlexec has already separated VM options from literal init inputs. */
        if (argv[i][0] != '-') fail("invalid emulator argument from launcher");
        if (!strcmp(argv[i], "-V")) {
            fprintf(stderr, "Erlang (SMP,ASYNC_THREADS) (BEAM) emulator version %s\n", OTP_ERTS_VERSION);
            exit(0);
        }
        argv[i][0] = '+';
        const char *arg = argv[i], *value;
        if (!strncmp(arg, "+SDcpu", 6)) {
            value = option_value(&i, argc, argv, 6);
            scheduler_pair(value, &options->dirty_cpu_schedulers, &options->dirty_cpu_schedulers_online);
        } else if (!strncmp(arg, "+SDio", 5)) {
            options->dirty_io_schedulers = thread_count(option_value(&i, argc, argv, 5), 0);
        } else if (!strncmp(arg, "+S", 2)) {
            scheduler_pair(option_value(&i, argc, argv, 2), &options->schedulers, &options->schedulers_online);
        } else if (!strncmp(arg, "+Muatags", 8)) {
            value = option_value(&i, argc, argv, 8);
            if (!strcmp(value, "true"))
                options->allocator_tagging = BEAM_ALLOCATOR_TAGGING_ENABLED;
            else if (!strcmp(value, "false"))
                options->allocator_tagging = BEAM_ALLOCATOR_TAGGING_DISABLED;
            else
                fail("invalid allocator tagging value (expected true or false)");
        } else if (!strncmp(arg, "+A", 2)) {
            options->async_threads = thread_count(option_value(&i, argc, argv, 2), 1);
        } else if (!strncmp(arg, "+IOt", 4)) {
            options->poll_threads = thread_count(option_value(&i, argc, argv, 4), 0);
        } else if (!strncmp(arg, "+K", 2)) {
            /* Pinned OTP 29 consumes obsolete +K without changing polling. */
            (void)option_value(&i, argc, argv, 2);
        } else if (!strncmp(arg, "+P", 2)) {
            options->process_limit = positive_number(option_value(&i, argc, argv, 2), 0);
        } else if (!strncmp(arg, "+Q", 2)) {
            options->port_limit = positive_number(option_value(&i, argc, argv, 2), 0);
            options->port_limit_ignore_files = 1;
        } else if (!strncmp(arg, "+t", 2)) {
            options->atom_limit = positive_number(option_value(&i, argc, argv, 2), 0);
        } else if (!strncmp(arg, "+hms", 4)) {
            options->min_heap_size = positive_number(option_value(&i, argc, argv, 4), 0);
        } else if (!strncmp(arg, "+hmbs", 5)) {
            options->min_bin_vheap_size = positive_number(option_value(&i, argc, argv, 5), 0);
        } else if (!strncmp(arg, "+hmax", 5)) {
            options->max_heap_size = positive_number(option_value(&i, argc, argv, 5), 1);
        } else if (!strncmp(arg, "+sbt", 4)) {
            value = option_value(&i, argc, argv, 4);
            /* The public lifecycle guarantees unbound schedulers. Do not
             * pretend to select any binding mode absent from that contract. */
            if (strcmp(value, "u")) fail("scheduler binding requires additional public SDK support");
        } else if (!strncmp(arg, "+B", 2)) {
            value = arg + 2;
            if (!*value && i + 1 < argc && strlen(argv[i + 1]) == 1 && strchr("dic", argv[i + 1][0]))
                value = argv[++i];
            if (!*value || !strcmp(value, "d")) options->break_policy = BEAM_BREAK_DISABLED;
            else if (!strcmp(value, "i")) options->break_policy = BEAM_BREAK_IGNORE;
            else if (!strcmp(value, "c")) options->break_policy = BEAM_BREAK_INPUT;
            else fail("invalid break-handler option");
        } else {
            fprintf(stderr, "erl: emulator option is not implemented: %s\n", arg); exit(1);
        }
    }
    if (options->dirty_cpu_schedulers > options->schedulers)
        options->dirty_cpu_schedulers = options->schedulers;
    if (options->dirty_cpu_schedulers_online > options->schedulers_online)
        options->dirty_cpu_schedulers_online = options->schedulers_online;
    if (options->dirty_cpu_schedulers_online > options->dirty_cpu_schedulers)
        options->dirty_cpu_schedulers_online = options->dirty_cpu_schedulers;
    if (!separated) fail("use the installed erl launcher");
    argv[output] = NULL;
    return output;
}

int main(int argc, char **argv)
{
    char executable[PATH_MAX];
#ifdef _WIN32
    wchar_t wide[32768];
    DWORD count = GetModuleFileNameW(NULL, wide, 32768);
    char *utf8 = count && count < 32768 ? otp_windows_utf8(wide) : NULL;
    if (!utf8 || strlen(utf8) >= sizeof(executable)) fail("cannot locate installed executable");
    strcpy(executable, utf8); free(utf8);
    for (char *p = executable; *p; ++p) if (*p == '\\') *p = '/';
#elif defined(__APPLE__)
    char raw[PATH_MAX];
    uint32_t capacity = sizeof raw;
    if (_NSGetExecutablePath(raw, &capacity) || !realpath(raw, executable))
        fail("cannot locate installed executable");
#else
    ssize_t n = readlink("/proc/self/exe", executable, sizeof(executable) - 1);
    if (n <= 0 || n == sizeof(executable) - 1) fail("cannot locate installed executable");
    executable[n] = 0;
#endif
    char *bin = directory(executable), *erts = directory(bin), *root = directory(erts);
    free(erts);
    beam_error error = {0}; beam_vm_options options;
    configure(&options, &error);
    argc = runtime_arguments(&options, argc, argv);
    otp_host_inputs inputs = {0};
    beam_composition *composition = NULL; beam_system *system = NULL; beam_vm *vm = NULL;
    beam_status status = otp_host_acquire(root, (size_t)(argc - 1),
        (const char *const *)(argv + 1), &inputs, &error);
    if (status == BEAM_OK)
        status = beam_composition_prepare(&inputs.composition, &composition, &error);
    options.composition = composition; options.initial_root = &inputs.entry;
    options.startup_context = inputs.context;
    if (status == BEAM_OK) status = beam_init(&system, &error);
    if (status == BEAM_OK) status = beam_vm_init(system, &options, &vm, &error);
    otp_host_release(&inputs);
    free(bin); free(root);
    beam_composition_release(&composition);
    if (status == BEAM_OK) status = beam_vm_enter(vm, &error);
    if (vm) beam_vm_terminate(&vm, NULL);
    if (system) beam_terminate(&system);
    fprintf(stderr, "erl: runtime startup returned %d: %s\n", status, error.message);
    return 1;
}

#ifdef _WIN32
int wmain(int argc, wchar_t **wide)
{
    char **owned = calloc((size_t)argc + 1, sizeof(*owned));
    char **args = calloc((size_t)argc + 1, sizeof(*args));
    if (!owned || !args) fail("out of memory");
    for (int i = 0; i < argc; ++i) {
        owned[i] = args[i] = otp_windows_utf8(wide[i]);
        if (!owned[i]) fail("invalid command argument");
    }
    int status = main(argc, args);
    for (int i = 0; i < argc; ++i) free(owned[i]);
    free(owned); free(args);
    return status;
}
#endif
