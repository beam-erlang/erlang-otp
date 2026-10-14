/* SPDX-License-Identifier: Apache-2.0 */
#include "host_observe.h"
#include <errno.h>
#include <dlfcn.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>
#ifdef __APPLE__
#include <libproc.h>
#include <sys/proc_info.h>
#include <sys/sysctl.h>
#endif

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t condition = PTHREAD_COND_INITIALIZER;
static int ready, stop;

static void *worker(void *unused)
{
    (void)unused;
    pthread_mutex_lock(&mutex);
    ready = 1;
    pthread_cond_signal(&condition);
    while (!stop) pthread_cond_wait(&condition, &mutex);
    pthread_mutex_unlock(&mutex);
    return NULL;
}

static int same(const int *a, size_t an, const int *b, size_t bn)
{ return an == bn && (!an || !memcmp(a, b, an * sizeof *a)); }

static int self_test(const char *library)
{
    (void)library;
    int result = 1, pipes[2] = {-1, -1}, thread_started = 0;
    int *before = NULL, *during = NULL, *after = NULL;
    size_t bn, dn, an;
    pthread_t thread;
    pid_t child = -1;
    void *mapping = MAP_FAILED;
    size_t page = (size_t)sysconf(_SC_PAGESIZE);
#define CHECK(expression) do { if (!(expression)) { \
    fprintf(stderr, "host-observer:%d: %s (errno=%d)\n", __LINE__, #expression, errno); goto done; \
} } while (0)
    CHECK(page && page <= SIZE_MAX / 3);
    CHECK(!beam_test_host_fds(getpid(), &before, &bn));
    CHECK(!pipe(pipes));
    CHECK(!beam_test_host_fds(getpid(), &during, &dn));
    CHECK(dn == bn + 2);
    close(pipes[0]); close(pipes[1]); pipes[0] = pipes[1] = -1;
    CHECK(!beam_test_host_fds(getpid(), &after, &an));
    CHECK(same(before, bn, after, an));
    free(before); free(during); free(after); before = during = after = NULL;

    int threads = beam_test_host_threads(getpid());
    CHECK(threads > 0);
    CHECK(!pthread_create(&thread, NULL, worker, NULL));
    thread_started = 1;
    pthread_mutex_lock(&mutex);
    while (!ready) pthread_cond_wait(&condition, &mutex);
    pthread_mutex_unlock(&mutex);
    CHECK(beam_test_host_threads(getpid()) == threads + 1);
    pthread_mutex_lock(&mutex); stop = 1; pthread_cond_signal(&condition); pthread_mutex_unlock(&mutex);
    CHECK(!pthread_join(thread, NULL)); thread_started = 0;
    /* Kernel thread release may follow the pthread join acknowledgement. */
    int current = -1;
    for (int i = 0; i < 1000; ++i) {
        current = beam_test_host_threads(getpid());
        if (current == threads || current < 0) break;
        usleep(1000);
    }
    CHECK(current == threads);

    CHECK(!beam_test_host_children(getpid(), &before, &bn));
    CHECK(!pipe(pipes));
    child = fork(); CHECK(child >= 0);
    if (!child) {
        char byte;
        close(pipes[1]);
        _exit(read(pipes[0], &byte, 1) < 0 ? 1 : 0);
    }
    close(pipes[0]); pipes[0] = -1;
    CHECK(!beam_test_host_children(getpid(), &during, &dn));
    CHECK(dn == bn + 1);
    int found = 0;
    for (size_t i = 0; i < dn; ++i) if (during[i] == child) found = 1;
    CHECK(found);
    int alive, zombie;
    CHECK(!beam_test_host_state(child, &alive, &zombie) && alive && !zombie);
#ifdef __APPLE__
    char **child_files; size_t child_file_count;
    CHECK(!beam_test_host_mapped_files(child,&child_files,&child_file_count) && child_file_count);
    beam_test_host_free_paths(child_files,child_file_count);
#endif
    close(pipes[1]); pipes[1] = -1;
    int status;
    CHECK(waitpid(child, &status, 0) == child && WIFEXITED(status) && !WEXITSTATUS(status));
    CHECK(!beam_test_host_state(child, &alive, &zombie) && !alive);
    child = -1;
    CHECK(!beam_test_host_children(getpid(), &after, &an));
    CHECK(same(before, bn, after, an));

    int regions = beam_test_host_executable_regions();
    CHECK(regions > 0);
    mapping = mmap(NULL, 3 * page, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
    CHECK(mapping != MAP_FAILED);
    CHECK(!mprotect((char *)mapping + page, page, PROT_READ | PROT_EXEC));
    CHECK(beam_test_host_executable_regions() == regions + 1);
    CHECK(!munmap(mapping, 3 * page)); mapping = MAP_FAILED;
    CHECK(beam_test_host_executable_regions() == regions);

    char executable[PATH_MAX], image[PATH_MAX];
    CHECK(!beam_test_host_executable(getpid(), executable, sizeof executable));
    CHECK(!beam_test_host_image((const void *)self_test, image, sizeof image));
    CHECK(!strcmp(executable, image));
#ifdef __APPLE__
    char **files=NULL; size_t file_count=0;
    CHECK(!beam_test_host_mapped_files(getpid(),&files,&file_count) && file_count);
    beam_test_host_free_paths(files,file_count);
    if (library) {
        char canonical[PATH_MAX]; CHECK(realpath(library,canonical));
        void *loaded=dlopen(canonical,RTLD_NOW|RTLD_LOCAL); CHECK(loaded);
        void *symbol=dlsym(loaded,"beam_isolation_value");
        int observed=symbol && !beam_test_host_image(symbol,image,sizeof image) && !strcmp(image,canonical);
        if (!beam_test_host_mapped_files(getpid(),&files,&file_count)) {
            int present=0;
            for (size_t i=0;i<file_count;++i) if (!strcmp(files[i],canonical)) present=1;
            observed=observed && present;
            beam_test_host_free_paths(files,file_count);
        } else observed=0;
        int closed=dlclose(loaded); CHECK(observed && !closed);
        CHECK(!beam_test_host_mapped_files(getpid(),&files,&file_count));
        int absent=1;
        for (size_t i=0;i<file_count;++i) if (!strcmp(files[i],canonical)) absent=0;
        beam_test_host_free_paths(files,file_count);
        CHECK(absent);
    }
#endif
    puts("HOST_OBSERVATIONS_RESTORED"); result = 0;
done:
    if (thread_started) {
        pthread_mutex_lock(&mutex); stop = 1; pthread_cond_signal(&condition); pthread_mutex_unlock(&mutex);
        pthread_join(thread, NULL);
    }
    for (int i = 0; i < 2; ++i) if (pipes[i] >= 0) close(pipes[i]);
    if (child > 0) { kill(child, SIGKILL); waitpid(child, NULL, 0); }
    if (mapping != MAP_FAILED) munmap(mapping, 3 * page);
    free(before); free(during); free(after);
    return result;
#undef CHECK
}

#ifdef __APPLE__
/* proc_pidpath cannot resolve an unlinked executable vnode. The kernel's
 * KERN_PROCARGS2 record still contains its exec path before the argv strings. */
static int process_path(pid_t pid, char *path, size_t capacity)
{
    if (proc_pidpath(pid, path, (uint32_t)capacity) > 0) return 0;
    int mib[] = {CTL_KERN, KERN_PROCARGS2, pid};
    size_t size = 0;
    if (sysctl(mib, 3, NULL, &size, NULL, 0) || size <= sizeof(int) || size > 16*1024*1024) return -1;
    char *record = malloc(size);
    if (!record) return -1;
    if (sysctl(mib, 3, record, &size, NULL, 0)) { free(record); return -1; }
    char *image = record + sizeof(int);
    size_t available = size - sizeof(int);
    size_t length = strnlen(image, available);
    if (length == available || length >= capacity || image[0] != '/') {
        free(record); errno = EIO; return -1;
    }
    memcpy(path, image, length + 1);
    free(record);
    return 0;
}

static void json_string(const char *text)
{
    putchar('"');
    for (const unsigned char *p=(const unsigned char *)text;*p;++p) {
        if (*p=='"' || *p=='\\') { putchar('\\'); putchar(*p); }
        else if (*p<32) printf("\\u%04x",*p);
        else putchar(*p);
    }
    putchar('"');
}
#endif

int main(int argc, char **argv)
{
#ifdef __APPLE__
    if (argc == 3 && !strcmp(argv[1], "--owned-prefix")) {
        char prefix[PATH_MAX];
        if (!realpath(argv[2], prefix)) { perror("owned prefix"); return 1; }
        size_t length = strlen(prefix);
        errno = 0;
        int needed = proc_listpids(PROC_UID_ONLY, (uint32_t)getuid(), NULL, 0);
        if (needed <= 0 || needed > INT_MAX - 4096) return 1;
        int capacity = needed + 4096;
        pid_t *pids = malloc((size_t)capacity);
        if (!pids) return 1;
        int bytes = proc_listpids(PROC_UID_ONLY, (uint32_t)getuid(), pids, capacity);
        if (bytes <= 0 || bytes >= capacity || bytes % sizeof(pid_t)) { free(pids); return 1; }
        int first = 1, self_seen = 0;
        fputs("{\"processes\":[", stdout);
        for (size_t i = 0; i < (size_t)bytes / sizeof(pid_t); ++i) {
            pid_t pid = pids[i];
            if (pid <= 0) continue;
            if (pid == getpid()) { self_seen = 1; continue; }
            char path[PROC_PIDPATHINFO_MAXSIZE];
            errno = 0;
            if (process_path(pid, path, sizeof path)) {
                int alive = -1, zombie = -1;
                if (!beam_test_host_state(pid, &alive, &zombie) && (!alive || zombie)) continue;
                fprintf(stderr, "owned process path pid=%d error=%d alive=%d zombie=%d\n", pid, errno, alive, zombie); free(pids); return 1;
            }
            if (strncmp(path, prefix, length) || path[length] != '/') continue;
            if (!first) putchar(',');
            printf("{\"pid\":%d,\"executable\":", pid); json_string(path); putchar('}'); first = 0;
        }
        free(pids); puts("]}");
        return !self_seen || ferror(stdout) ? 1 : 0;
    }
    if (argc == 4 && !strcmp(argv[1], "--verify-static")) {
        char *end, actual[PATH_MAX], expected[PATH_MAX];
        errno = 0;
        long selected = strtol(argv[2], &end, 10);
        if (errno || *end || selected <= 0 || selected > INT_MAX ||
            !realpath(argv[3], expected) ||
            beam_test_host_executable((pid_t)selected, actual, sizeof actual) ||
            strcmp(actual, expected)) return 1;
        char **files = NULL; size_t count = 0;
        if (beam_test_host_mapped_files((pid_t)selected, &files, &count)) return 1;
        int invalid = !count;
        for (size_t i = 0; i < count; ++i) {
            const char *name = strrchr(files[i], '/');
            name = name ? name + 1 : files[i];
            if (!strcmp(name, "libbeam.dylib") || !strcmp(name, "libbeam.so")) invalid = 1;
        }
        beam_test_host_free_paths(files, count);
        if (invalid) return 1;
        puts("STATIC_HOST_OK");
        return ferror(stdout) ? 1 : 0;
    }
#endif
    if ((argc == 2 || argc == 3) && !strcmp(argv[1], "--self-test")) return self_test(argc==3 ? argv[2] : NULL);
    if (argc != 3 || (strcmp(argv[1], "--state") && strcmp(argv[1],"--images") && strcmp(argv[1],"--snapshot"))) return 64;
    char *end;
    errno = 0;
    long number = strtol(argv[2], &end, 10);
    if (errno || !*argv[2] || *end || number <= 0 || number > INT_MAX) return 64;
#ifdef __APPLE__
    if (!strcmp(argv[1],"--images") || !strcmp(argv[1],"--snapshot")) {
        char executable[PATH_MAX],**paths; size_t count;
        if (beam_test_host_executable((pid_t)number,executable,sizeof executable) ||
            beam_test_host_mapped_files((pid_t)number,&paths,&count)) { perror("host-observer"); return 1; }
        fputs("{\"executable\":",stdout); json_string(executable); fputs(",\"files\":[",stdout);
        for (size_t i=0;i<count;++i) { if (i) putchar(','); json_string(paths[i]); }
        putchar(']'); beam_test_host_free_paths(paths,count);
        if (!strcmp(argv[1], "--snapshot")) {
            int *fds = NULL, *children = NULL;
            size_t nfds = 0, nchildren = 0;
            int threads = beam_test_host_threads((pid_t)number);
            if (threads <= 0 || beam_test_host_fds((pid_t)number, &fds, &nfds) ||
                beam_test_host_children((pid_t)number, &children, &nchildren)) {
                free(fds); free(children); perror("host snapshot"); return 1;
            }
            printf(",\"threads\":%d,\"descriptors\":[", threads);
            for (size_t i = 0; i < nfds; ++i) printf("%s%d", i ? "," : "", fds[i]);
            fputs("],\"children\":[", stdout);
            for (size_t i = 0; i < nchildren; ++i) printf("%s%d", i ? "," : "", children[i]);
            putchar(']'); free(fds); free(children);
        }
        puts("}"); return ferror(stdout) ? 1 : 0;
    }
#else
    if (!strcmp(argv[1],"--images")) return 64;
#endif
    int alive, zombie;
    if (beam_test_host_state((pid_t)number, &alive, &zombie)) { perror("host-observer"); return 1; }
    printf("{\"alive\":%s,\"zombie\":%s}\n", alive ? "true" : "false", zombie ? "true" : "false");
    return 0;
}
