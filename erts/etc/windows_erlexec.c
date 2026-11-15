/* SPDX-License-Identifier: Apache-2.0 */
/* OTP-owned Windows launcher integration. The upstream parser remains intact;
 * only the platform lifecycle calls the installed SDK's public process entry. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "otp_windows_launcher.h"

typedef int (*beam_entry_function)(int, char **);
typedef int (*beam_wait_function)(void);
static beam_wait_function wait_for_key;
extern int keep_window;
int otp_upstream_win_erlexec(int, char **, HANDLE);

void error(char *format, ...)
{
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fputc('\n', stderr);
    exit(1);
}

static wchar_t *wide(const char *value)
{
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value, -1, NULL, 0);
    wchar_t *result = count ? malloc((size_t) count * sizeof(*result)) : NULL;
    if (!result || !MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                      value, -1, result, count))
        error("Cannot encode Windows launcher path (%lu)", GetLastError());
    return result;
}

static char *utf8(const wchar_t *value)
{
    int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1, NULL, 0, NULL, NULL);
    char *result = count ? malloc((size_t) count) : NULL;
    if (!result || !WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                      value, -1, result, count, NULL, NULL))
        error("Cannot encode Windows launcher name (%lu)", GetLastError());
    return result;
}

static int same_path(const char *left, const char *right)
{
    wchar_t *a = wide(left), *b = wide(right), *p;
    int equal;
    for (p = a; *p; ++p) if (*p == L'/') *p = L'\\';
    for (p = b; *p; ++p) if (*p == L'/') *p = L'\\';
    equal = CompareStringOrdinal(a, -1, b, -1, TRUE) == CSTR_EQUAL;
    free(a); free(b);
    return equal;
}

static void keep_console(void)
{
    fputs("\nPress any key to close window.\n", stdout);
    fflush(stdout);
    if (wait_for_key) wait_for_key();
}

/* Microsoft CRT quoting, including empty arguments and trailing backslashes. */
static wchar_t *quoted_arguments(char **argv)
{
    size_t capacity = 1, used = 0, index;
    wchar_t *line;
    for (index = 0; argv[index]; ++index) capacity += strlen(argv[index]) * 4 + 4;
    line = calloc(capacity, sizeof(*line));
    if (!line) error("Cannot allocate Windows command line");
    for (index = 0; argv[index]; ++index) {
        wchar_t *argument = wide(argv[index]), *p;
        size_t slashes = 0;
        if (index) line[used++] = L' ';
        line[used++] = L'"';
        for (p = argument; ; ++p) {
            if (*p == L'\\') { ++slashes; continue; }
            if (*p == L'"' || !*p) {
                size_t count = slashes * 2 + (*p == L'"' ? 1 : 0);
                while (count--) line[used++] = L'\\';
            } else {
                while (slashes) { line[used++] = L'\\'; --slashes; }
            }
            slashes = 0;
            if (!*p) break;
            line[used++] = *p;
        }
        line[used++] = L'"';
        free(argument);
    }
    line[used] = 0;
    return line;
}

int start_emulator(char *emulator, char *start_program, char **argv, int detached)
{
    int argc = 0;
    wchar_t *dll = wide(emulator);
    HMODULE runtime;
    beam_entry_function entry;
    while (argv[argc]) ++argc;
    if (detached) {
        STARTUPINFOW startup;
        PROCESS_INFORMATION child;
        wchar_t *program = wide(start_program), *line;
        SetEnvironmentVariableW(L"ERL_CONSOLE_MODE", L"detached");
        SetEnvironmentVariableW(L"ERL_EMULATOR_DLL", dll);
        argv[0] = start_program;
        line = quoted_arguments(argv);
        memset(&startup, 0, sizeof(startup)); startup.cb = sizeof(startup);
        memset(&child, 0, sizeof(child));
        if (!CreateProcessW(program, line, NULL, NULL, FALSE,
                            DETACHED_PROCESS | CREATE_UNICODE_ENVIRONMENT,
                            NULL, NULL, &startup, &child))
            error("Cannot start detached Erlang (%lu)", GetLastError());
        SetPriorityClass(child.hProcess, GetPriorityClass(GetCurrentProcess()));
        CloseHandle(child.hThread); CloseHandle(child.hProcess);
        free(program); free(line); free(dll);
        return 0;
    }
    runtime = LoadLibraryExW(dll, NULL,
                            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (!runtime) error("Cannot load emulator %s (%lu)", emulator, GetLastError());
    entry = (beam_entry_function) GetProcAddress(runtime, "beam_main");
    if (!entry) error("Selected emulator lacks public beam_main: %s", emulator);
    wait_for_key = (beam_wait_function) GetProcAddress(runtime, "beam_windows_wait_for_console_key");
    free(dll);
    {
        wchar_t title[32768];
        DWORD length = GetEnvironmentVariableW(L"ERL_WINDOW_TITLE", title, 32768);
        if (length && length < 32768) SetConsoleTitleW(title);
    }
    SetEnvironmentVariableW(L"ERL_CONSOLE_MODE", L"windowed");
    if (keep_window) {
        if (!wait_for_key) error("Selected SDK lacks the Windows console wait interface");
        atexit(keep_console);
    }
    return entry(argc, argv);
}

/* Native build/bootstrap hosts inject the same checks as the Unix launcher.
 * Installed commands do not match these absolute producer paths. */
__declspec(dllexport) int win_erlexec(int argc, char **argv, HANDLE module)
{
    wchar_t executable[32768];
    char *name;
    char **augmented;
    int extra = 0, index, used = 0, boot_supplied = 0;
    const char *mode = getenv("ERL_CONSOLE_MODE");
    /* The detached second invocation already contains raw emulator arguments. */
    if (mode && strcmp(mode, "detached") == 0)
        return otp_upstream_win_erlexec(argc, argv, module);
    DWORD count = GetModuleFileNameW(NULL, executable, 32768);
    if (!count || count >= 32768) error("Cannot resolve Erlang executable path");
    name = utf8(executable);
    if (same_path(name, otp_bootstrap_executable)) extra = 8;
    else if (same_path(name, otp_product_executable)) extra = 2;
    free(name);
    if (!extra) return otp_upstream_win_erlexec(argc, argv, module);
    augmented = calloc((size_t) argc + extra + 1, sizeof(*augmented));
    if (!augmented) error("Cannot allocate Erlang launcher arguments");
    augmented[used++] = argv[0];
    if (extra == 8) {
        for (index = 1; index < argc; ++index) {
            if (!strcmp(argv[index], "-extra")) break;
            if (!strcmp(argv[index], "-boot")) boot_supplied = 1;
        }
        if (!boot_supplied) {
            augmented[used++] = "-boot";
            augmented[used++] = (char *) otp_bootstrap_boot;
        }
        augmented[used++] = "+SDcpu"; augmented[used++] = "1";
        augmented[used++] = "+SDio"; augmented[used++] = "1";
        augmented[used++] = "-eval"; augmented[used++] = (char *) otp_guard;
    } else {
        augmented[used++] = "-pz"; augmented[used++] = (char *) otp_inspection;
    }
    for (index = 1; index < argc; ++index) augmented[used++] = argv[index];
    /* The retained parser rewrites +VM options to -VM options in place. */
    for (index = 0; index < used; ++index) {
        augmented[index] = _strdup(augmented[index]);
        if (!augmented[index]) error("Cannot copy Erlang launcher argument");
    }
    return otp_upstream_win_erlexec(used, augmented, module);
}
