/* SPDX-License-Identifier: Apache-2.0 */
/* Upstream erlexec owns argument policy; the selected public-SDK host owns VM entry. */
#include "otp_windows.h"
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

void error(char *format, ...)
{
    va_list arguments;
    fputs("erl: ", stderr);
    va_start(arguments, format);
    vfprintf(stderr, format, arguments);
    va_end(arguments);
    fputc('\n', stderr);
    exit(1);
}

static wchar_t *wide(const char *text)
{
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, -1, NULL, 0);
    wchar_t *value = count ? malloc((size_t)count * sizeof(*value)) : NULL;
    if (value && !MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, -1, value, count)) {
        free(value); return NULL;
    }
    return value;
}

/* The runtime receives console events directly and owns its break menu.
 * Keep this waiting launcher alive until the runtime reports its exit status.
 * Registered handlers, unlike the ignore-Ctrl+C flag, are not inherited.
 */
static BOOL WINAPI waiting_console_event(DWORD event)
{
    return event == CTRL_C_EVENT || event == CTRL_BREAK_EVENT;
}

int start_emulator(char *emulator, char *start_program, char **argv, int detached)
{
    wchar_t command[32768] = {0};
    size_t used = 0;
    wchar_t *program = wide(emulator);
    (void)start_program;
    if (!program) return 1;
    for (size_t i = 0; argv[i]; ++i) {
        wchar_t *argument = wide(argv[i]);
        if (!argument || used + 2*wcslen(argument) + 4 >= 32768) {
            free(argument); free(program); return 1;
        }
        if (i) command[used++] = L' ';
        command[used++] = L'"';
        size_t slashes = 0;
        for (const wchar_t *p = argument;; ++p) {
            if (*p == L'\\') { ++slashes; continue; }
            size_t copies = (*p == L'"' || !*p) ? slashes*2 : slashes;
            while (copies--) command[used++] = L'\\';
            slashes = 0;
            if (!*p) break;
            if (*p == L'"') command[used++] = L'\\';
            command[used++] = *p;
        }
        command[used++] = L'"'; free(argument);
    }
    STARTUPINFOW startup = {.cb = sizeof(startup)};
    PROCESS_INFORMATION process = {0};
    DWORD flags = detached ? DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP : 0;
    if (!detached) {
        startup.dwFlags = STARTF_USESTDHANDLES;
        startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
        startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
        startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
        if (!GetConsoleWindow()) flags |= DETACHED_PROCESS;
    }
    BOOL console_handler = !detached && GetConsoleWindow();
    if (console_handler && !SetConsoleCtrlHandler(waiting_console_event, TRUE)) {
        fprintf(stderr, "erl: cannot observe console events (Windows error %lu)\n", GetLastError());
        free(program); return 1;
    }
    if (!CreateProcessW(program, command, NULL, NULL, !detached, flags, NULL, NULL, &startup, &process)) {
        fprintf(stderr, "erl: cannot start selected runtime (Windows error %lu)\n", GetLastError());
        if (console_handler) SetConsoleCtrlHandler(waiting_console_event, FALSE);
        free(program); return 1;
    }
    free(program); CloseHandle(process.hThread);
    DWORD status = 0;
    if (!detached) {
        if (WaitForSingleObject(process.hProcess, INFINITE) != WAIT_OBJECT_0 ||
            !GetExitCodeProcess(process.hProcess, &status)) status = 1;
    }
    if (console_handler) SetConsoleCtrlHandler(waiting_console_event, FALSE);
    CloseHandle(process.hProcess);
    return (int)status;
}
