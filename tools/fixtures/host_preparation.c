/* SPDX-License-Identifier: Apache-2.0 */
#define _GNU_SOURCE
#include "otp_host_inputs.h"
#include "otp_host_assets.h"
#include "otp_host_version.h"
#include <dirent.h>
#include <errno.h>
#include <fenv.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef __APPLE__
#include "host_observe.h"
#include <mach/mach.h>
#include <dlfcn.h>
#endif

#define CHECK(condition) do { if (!(condition)) { \
    fprintf(stderr, "OTP preparation failed at line %d: %s\n", __LINE__, #condition); \
    goto cleanup; \
} } while (0)

static int entries(const char *path)
{
#ifdef __APPLE__
    if (!strcmp(path, "/proc/self/task")) return beam_test_host_threads(getpid());
    int *values = NULL; size_t count = 0;
    if (strcmp(path, "/proc/self/fd") || beam_test_host_fds(getpid(), &values, &count)) return -1;
    free(values); return (int)count;
#else
    DIR *dir = opendir(path);
    struct dirent *entry;
    int count = 0;
    if (!dir) return -1;
    while ((entry = readdir(dir)))
        if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) ++count;
    closedir(dir);
    return count;
#endif
}

static void signal_handler(int signal_number) { (void)signal_number; }

typedef struct host_state {
    struct sigaction action;
    sigset_t signal_mask;
    stack_t stack;
    struct stat descriptors[3];
    int descriptor_flags[3], status_flags[3];
    int fd_count, thread_count;
} host_state;

static int address_space_size(rlim_t *size);
#ifdef __APPLE__
static rlim_t observed_memory_limit;
static void (*allocation_limit)(size_t);
#endif

static int memory_limit_select(const struct rlimit *limit, int failure)
{
#ifdef __APPLE__
    /* Darwin rejects RLIMIT_AS reductions. Inject the same real allocation
     * failure in the unmodified acquisition object, and observe the address
     * space budget directly at every cleanup boundary. */
    if (!allocation_limit) return -1;
    allocation_limit(failure ? 1024 * 1024 : 0);
    observed_memory_limit = limit->rlim_cur;
    return 0;
#else
    (void)failure;
    return setrlimit(RLIMIT_AS, limit);
#endif
}
static int memory_limit_restore(const struct rlimit *limit)
{
#ifdef __APPLE__
    (void)limit;
    if (allocation_limit) allocation_limit(0);
    observed_memory_limit = 0;
    return 0;
#else
    return setrlimit(RLIMIT_AS, limit);
#endif
}

static int host_unchanged(const host_state *before)
{
    struct sigaction action;
    sigset_t signal_mask;
    stack_t stack;
    struct stat descriptor;
    const char *bindir = getenv("BINDIR");
#ifdef __APPLE__
    rlim_t size;
    if (observed_memory_limit && (!address_space_size(&size) || size > observed_memory_limit))
        return 0;
#endif
    if (!bindir || strcmp(bindir, "preparation-host-state") ||
        fegetround() != FE_DOWNWARD ||
        entries("/proc/self/fd") != before->fd_count ||
        entries("/proc/self/task") != before->thread_count ||
        sigaction(SIGUSR1, NULL, &action) != 0 ||
        action.sa_handler != before->action.sa_handler ||
        action.sa_flags != before->action.sa_flags ||
        sigprocmask(SIG_SETMASK, NULL, &signal_mask) != 0 ||
        sigaltstack(NULL, &stack) != 0 ||
        stack.ss_sp != before->stack.ss_sp ||
        stack.ss_size != before->stack.ss_size ||
        stack.ss_flags != before->stack.ss_flags)
        return 0;
    for (int i = 1; i < NSIG; ++i)
        if (sigismember(&action.sa_mask, i) !=
            sigismember(&before->action.sa_mask, i) ||
            sigismember(&signal_mask, i) != sigismember(&before->signal_mask, i))
            return 0;
    for (int i = 0; i < 3; ++i)
        if (fstat(i, &descriptor) != 0 ||
            descriptor.st_dev != before->descriptors[i].st_dev ||
            descriptor.st_ino != before->descriptors[i].st_ino ||
            fcntl(i, F_GETFD) != before->descriptor_flags[i] ||
            fcntl(i, F_GETFL) != before->status_flags[i])
            return 0;
    return 1;
}

static int address_space_size(rlim_t *size)
{
#ifdef __APPLE__
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS ||
        count != MACH_TASK_BASIC_INFO_COUNT || info.virtual_size > RLIM_INFINITY - 64 * 1024 * 1024)
        return 0;
    *size = (rlim_t)info.virtual_size;
    return 1;
#else
    unsigned long long pages;
    long page_size = sysconf(_SC_PAGESIZE);
    FILE *statm = fopen("/proc/self/statm", "r");
    int ok;
    if (!statm || page_size <= 0) {
        if (statm) fclose(statm);
        return 0;
    }
    ok = fscanf(statm, "%llu", &pages) == 1 &&
         pages <= (RLIM_INFINITY - 64 * 1024 * 1024) / (rlim_t)page_size;
    fclose(statm);
    if (ok) *size = (rlim_t)pages * (rlim_t)page_size;
    return ok;
#endif
}

int main(int argc, char **argv)
{
    if (argc != 3) return 2;
    char asset[PATH_MAX], held[PATH_MAX + 6], bindir[PATH_MAX];
    struct sigaction action = {0};
    host_state host;
    struct rlimit limit, restricted, memory_limit, memory_restricted;
    rlim_t memory_size;
    int opened[128], opened_count = 0, moved = 0, limited = 0;
    int memory_limited = 0;
    beam_module_spec copied[OTP_PRELOAD_COUNT] = {0};
    char *large_argument = NULL;
    size_t prepared_count = 0;
    otp_host_inputs inputs = {0}, unchanged = {0};
    beam_composition *composition = NULL;
    beam_system *system = NULL;
    beam_vm *vm = NULL;
    beam_vm_options options;
    beam_error error = {0};
    char *owned_root = NULL;
    const char *arguments[] = {
        "-root", argv[1], "-bindir", bindir, "-boot", argv[2], "-noshell", "-noinput", "-eval",
        "22=length(erlang:pre_loaded()),"
        "preloaded=code:which(erl_tracer),true=code:is_sticky(erl_tracer),"
        "Modules=[erl_init,init,prim_buffer,prim_eval,prim_inet,prim_file,zlib,"
        "socket_registry,prim_socket,prim_net,prim_zip,erl_prim_loader,erl_tracer],"
        "lists:foreach(fun(M)->preloaded=code:which(M),true=code:is_sticky(M),"
        "{error,enoent}=file:read_file(filename:join(code:lib_dir(erts,ebin),"
        "atom_to_list(M)++\".beam\")) end,Modules),"
        "[\"--runtime=otp\",\"two words\",[16#65e5,16#672c],\"\",\"--\"]=init:get_plain_arguments(),"
        "io:put_chars(\"OTP_PREPARATION_OK\\n\"),halt().",
        "-extra", "--runtime=otp", "two words", "日本", "", "--"
    };
    const size_t argument_count = sizeof(arguments) / sizeof(arguments[0]);
    CHECK(snprintf(bindir, sizeof(bindir), "%s/erts-%s/bin", argv[1], OTP_ERTS_VERSION) < (int)sizeof(bindir));
    CHECK(OTP_PRELOAD_COUNT == 13 && !strcmp(otp_preloads[12].name, "erl_tracer"));
    CHECK(snprintf(asset, sizeof(asset), "%s/%s", argv[1], OTP_CHILD_HELPER) < (int)sizeof(asset));
    CHECK(snprintf(held, sizeof(held), "%s.held", asset) < (int)sizeof(held));
    CHECK(access(held, F_OK) < 0 && errno == ENOENT);
#ifdef __APPLE__
    allocation_limit = (void (*)(size_t))dlsym(RTLD_DEFAULT, "otp_test_allocation_limit");
    CHECK(allocation_limit);
#endif
    CHECK(setenv("BINDIR", "preparation-host-state", 1) == 0);
    action.sa_handler = signal_handler;
    sigemptyset(&action.sa_mask);
    CHECK(sigaction(SIGUSR1, &action, NULL) == 0);
    CHECK(sigaction(SIGUSR1, NULL, &host.action) == 0);
    CHECK(sigprocmask(SIG_SETMASK, NULL, &host.signal_mask) == 0);
    CHECK(sigaltstack(NULL, &host.stack) == 0);
    CHECK(fesetround(FE_DOWNWARD) == 0);
    for (int i = 0; i < 3; ++i) {
        CHECK(fstat(i, &host.descriptors[i]) == 0);
        host.descriptor_flags[i] = fcntl(i, F_GETFD);
        host.status_flags[i] = fcntl(i, F_GETFL);
        CHECK(host.descriptor_flags[i] >= 0 && host.status_flags[i] >= 0);
    }
    host.fd_count = entries("/proc/self/fd");
    host.thread_count = entries("/proc/self/task");
    CHECK(host.fd_count > 0 && host.thread_count == 1);
    inputs.entry.arguments.size = 17; /* Preserve the entire sentinel on failure. */
    unchanged = inputs;
    CHECK(otp_host_acquire("relative", argument_count, arguments, &inputs, &error) == BEAM_INVALID_ARGUMENT);
    CHECK(!memcmp(&inputs, &unchanged, sizeof(inputs)));
    CHECK(otp_host_acquire("/invalid\xff", argument_count, arguments, &inputs, &error) == BEAM_INVALID_ARGUMENT);
    CHECK(!memcmp(&inputs, &unchanged, sizeof(inputs)));
    CHECK(otp_host_acquire(argv[1], 1, NULL, &inputs, &error) == BEAM_INVALID_ARGUMENT);
    CHECK(!memcmp(&inputs, &unchanged, sizeof(inputs)) && host_unchanged(&host));

    /* The genuine external helper remains an acquisition requirement. */
    CHECK(otp_host_acquire(argv[1], argument_count, arguments, &inputs, &error) == BEAM_OK);
    CHECK(rename(asset, held) == 0); moved = 1;
    for (int i = 0; i < 128; ++i) {
        CHECK(beam_composition_prepare(&inputs.composition, &composition, &error) == BEAM_RUNTIME_NOT_FOUND);
        CHECK(!composition && host_unchanged(&host));
    }
    CHECK(rename(held, asset) == 0); moved = 0;
    CHECK(beam_composition_prepare(&inputs.composition, &composition, &error) == BEAM_OK);
    beam_composition_release(&composition);
    otp_host_release(&inputs);

    CHECK(getrlimit(RLIMIT_NOFILE, &limit) == 0);
    restricted = limit;
    if (restricted.rlim_cur > 64) restricted.rlim_cur = 64;
    CHECK(setrlimit(RLIMIT_NOFILE, &restricted) == 0); limited = 1;
    while (opened_count < 128) {
        int fd = open("/dev/null", O_RDONLY);
        if (fd < 0) break;
        opened[opened_count++] = fd;
    }
    CHECK(errno == EMFILE);
    CHECK(otp_host_acquire(argv[1], argument_count, arguments, &inputs, &error) == BEAM_OK);
    otp_host_release(&inputs);
    while (opened_count) close(opened[--opened_count]);
    CHECK(setrlimit(RLIMIT_NOFILE, &limit) == 0); limited = 0;
    CHECK(host_unchanged(&host));

    /* ETF argument allocation still fails atomically under memory pressure. */
    large_argument = malloc(32 * 1024 * 1024); CHECK(large_argument);
    memset(large_argument, 'x', 32 * 1024 * 1024 - 1);
    large_argument[32 * 1024 * 1024 - 1] = 0;
    CHECK(getrlimit(RLIMIT_AS, &memory_limit) == 0);
    CHECK(address_space_size(&memory_size));
    memory_restricted = memory_limit;
    memory_restricted.rlim_cur = memory_size + 1024 * 1024;
    CHECK(memory_limit_select(&memory_restricted, 1) == 0); memory_limited = 1;
    unchanged = inputs;
    for (int i = 0; i < 16; ++i) {
        const char *large_arguments[] = {large_argument};
        CHECK(otp_host_acquire(argv[1], 1, large_arguments, &inputs, &error) == BEAM_OUT_OF_MEMORY);
        CHECK(!memcmp(&inputs, &unchanged, sizeof(inputs)) && host_unchanged(&host));
    }
    CHECK(memory_limit_restore(&memory_limit) == 0); memory_limited = 0;
    free(large_argument); large_argument = NULL;

    CHECK(address_space_size(&memory_size));
    memory_restricted = memory_limit;
    memory_restricted.rlim_cur = memory_size + 8 * 1024 * 1024;
    CHECK(memory_restricted.rlim_cur <= memory_limit.rlim_cur);
    CHECK(memory_limit_select(&memory_restricted, 0) == 0); memory_limited = 1;
    for (int i = 0; i < 64; ++i) {
        CHECK(otp_host_acquire(argv[1], argument_count, arguments, &inputs, &error) == BEAM_OK);
        unchanged = inputs;
        CHECK(otp_host_acquire(NULL, 0, NULL, &inputs, &error) == BEAM_INVALID_ARGUMENT);
        CHECK(!memcmp(&inputs, &unchanged, sizeof(inputs)));
        beam_module_spec duplicates[] = {inputs.composition.preloads[0], inputs.composition.preloads[0]};
        beam_composition_options invalid = inputs.composition;
        invalid.preload_count = 2;
        invalid.preloads = duplicates;
        CHECK(beam_composition_prepare(&invalid, &composition, &error) == BEAM_INVALID_ARGUMENT);
        CHECK(!composition && host_unchanged(&host));
        duplicates[0].bytes.size = 1;
        invalid.preload_count = 1;
        CHECK(beam_composition_prepare(&invalid, &composition, &error) == BEAM_INVALID_BEAM);
        CHECK(!composition && host_unchanged(&host));
        /* Cancel generic composition before any system/VM initialization. */
        CHECK(beam_composition_prepare(&inputs.composition, &composition, &error) == BEAM_OK);
        beam_composition *kept = composition;
        CHECK(beam_composition_prepare(&inputs.composition, &composition, &error) == BEAM_INVALID_ARGUMENT);
        CHECK(composition == kept);
        beam_composition_release(&composition);
        beam_composition_release(&composition);
        otp_host_release(&inputs); otp_host_release(&inputs);
        CHECK(!inputs.storage && !inputs.composition.preloads && host_unchanged(&host));
    }
    CHECK(memory_limit_restore(&memory_limit) == 0); memory_limited = 0;
    CHECK(!beam_system_is_initialized());

    owned_root = strdup(argv[1]); CHECK(owned_root);
    CHECK(otp_host_acquire(owned_root, argument_count, arguments, &inputs, &error) == BEAM_OK);
    memset(owned_root, 'x', strlen(owned_root)); free(owned_root); owned_root = NULL;
    for (size_t i = 0; i < OTP_PRELOAD_COUNT; ++i) {
        copied[i] = otp_preloads[i];
        copied[i].bytes.data = malloc(copied[i].bytes.size);
        copied[i].origin = strdup("copied OTP preload");
        CHECK(copied[i].bytes.data && copied[i].origin);
        memcpy((void *)copied[i].bytes.data, otp_preloads[i].bytes.data, copied[i].bytes.size);
    }
    inputs.composition.preloads = copied;
    CHECK(beam_composition_prepare(&inputs.composition, &composition, &error) == BEAM_OK);
    for (size_t i = 0; i < OTP_PRELOAD_COUNT; ++i) {
        memset((void *)copied[i].bytes.data, 0, copied[i].bytes.size);
        memset((void *)copied[i].origin, 'x', strlen(copied[i].origin));
        free((void *)copied[i].bytes.data); free((void *)copied[i].origin);
        copied[i] = (beam_module_spec){0};
    }
    CHECK(fesetround(FE_TONEAREST) == 0);
    CHECK(beam_init(&system, &error) == BEAM_OK);
    beam_vm_options_init(&options);
    options.execution = BEAM_PROCESS_OWNED;
    options.filename_encoding = BEAM_FILENAME_UTF8;
    options.composition = composition;
    options.initial_root = &inputs.entry;
    options.startup_context = inputs.context;
    CHECK(beam_vm_init(system, &options, &vm, &error) == BEAM_OK);
    memset((void *)inputs.entry.arguments.data, 0, inputs.entry.arguments.size);
    otp_host_release(&inputs); otp_host_release(&inputs);
    beam_composition_release(&composition);
    for (size_t i = 0; i < OTP_PRELOAD_COUNT; ++i) {
        CHECK(snprintf(asset, sizeof(asset), "%s/lib/erts-%s/ebin/%s.beam", argv[1], OTP_ERTS_VERSION, otp_preloads[i].name) < (int)sizeof(asset));
        CHECK(snprintf(held, sizeof(held), "%s.held", asset) < (int)sizeof(held));
        CHECK(rename(asset, held) == 0);
        ++prepared_count;
    }
    /* The runner restores this disposable installation after process exit. */
    (void)beam_vm_enter(vm, &error);
    CHECK(0);
cleanup:
    otp_host_release(&inputs);
    beam_composition_release(&composition);
    if (vm) beam_vm_terminate(&vm, NULL);
    if (system) beam_terminate(&system);
    free(owned_root);
    if (memory_limited) memory_limit_restore(&memory_limit);
    free(large_argument);
    for (size_t i = 0; i < OTP_PRELOAD_COUNT; ++i) {
        free((void *)copied[i].bytes.data); free((void *)copied[i].origin);
    }
    while (opened_count) close(opened[--opened_count]);
    if (limited) setrlimit(RLIMIT_NOFILE, &limit);
    if (moved) rename(held, asset);
    while (prepared_count) {
        --prepared_count;
        snprintf(asset, sizeof(asset), "%s/lib/erts-%s/ebin/%s.beam", argv[1], OTP_ERTS_VERSION, otp_preloads[prepared_count].name);
        snprintf(held, sizeof(held), "%s.held", asset);
        rename(held, asset);
    }
    return 1;
}
