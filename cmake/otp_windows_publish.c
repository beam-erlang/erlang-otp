/* SPDX-License-Identifier: Apache-2.0 */
/* Project-owned installation guard. No VM or installed product dependency. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <process.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

static HANDLE *held;
static size_t held_count, held_capacity;

/* _spawnv concatenates its argument strings into a Windows command line.
 * Quote each one using the CRT's backslash-before-quote rules. */
static wchar_t *quoted(const wchar_t *argument)
{
    size_t length = wcslen(argument), read = 0, written = 0;
    wchar_t *result = malloc((length * 2 + 3) * sizeof(*result));
    if (!result) return NULL;
    result[written++] = L'"';
    while (read < length) {
        size_t slashes = 0;
        while (read < length && argument[read] == L'\\') { ++slashes; ++read; }
        if (read == length || argument[read] == L'"') {
            size_t count = slashes * 2 + (read < length ? 1 : 0);
            while (count--) result[written++] = L'\\';
        } else {
            while (slashes--) result[written++] = L'\\';
        }
        if (read < length) result[written++] = argument[read++];
    }
    result[written++] = L'"';
    result[written] = L'\0';
    return result;
}

static wchar_t *joined(const wchar_t *root, const wchar_t *name)
{
    size_t length = wcslen(root) + wcslen(name) + 2;
    wchar_t *path = malloc(length * sizeof(*path));
    if (!path) return NULL;
    _snwprintf_s(path, length, _TRUNCATE, L"%s\\%s", root, name);
    return path;
}

static int remember(HANDLE handle)
{
    if (held_count == held_capacity) {
        size_t capacity = held_capacity ? held_capacity * 2 : 128;
        HANDLE *replacement = realloc(held, capacity * sizeof(*held));
        if (!replacement) { CloseHandle(handle); return 0; }
        held = replacement;
        held_capacity = capacity;
    }
    held[held_count++] = handle;
    return 1;
}

static int check_directory(const wchar_t *path)
{
    DWORD attributes = GetFileAttributesW(path);
    if (attributes == INVALID_FILE_ATTRIBUTES) {
        DWORD error = GetLastError();
        return error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND;
    }
    if ((attributes & FILE_ATTRIBUTE_REPARSE_POINT) || !(attributes & FILE_ATTRIBUTE_DIRECTORY)) {
        fwprintf(stderr, L"Installation destination directory is a reparse point or non-directory: %s\n", path);
        return 0;
    }
    return 1;
}

static int preflight(const wchar_t *stage, const wchar_t *prefix)
{
    WIN32_FIND_DATAW entry;
    wchar_t *pattern;
    HANDLE search;
    int ok = 1;
    if (!check_directory(prefix)) return 0;
    pattern = joined(stage, L"*");
    if (!pattern) return 0;
    search = FindFirstFileW(pattern, &entry);
    free(pattern);
    if (search == INVALID_HANDLE_VALUE) return GetLastError() == ERROR_FILE_NOT_FOUND;
    do {
        wchar_t *source, *destination;
        DWORD attributes;
        if (!wcscmp(entry.cFileName, L".") || !wcscmp(entry.cFileName, L"..")) continue;
        source = joined(stage, entry.cFileName);
        destination = joined(prefix, entry.cFileName);
        if (!source || !destination) { free(source); free(destination); ok = 0; break; }
        if ((entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) &&
                !(entry.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
            ok = preflight(source, destination);
        } else {
            attributes = GetFileAttributesW(destination);
            if (attributes != INVALID_FILE_ATTRIBUTES) {
                HANDLE file;
                if ((attributes & FILE_ATTRIBUTE_DIRECTORY) &&
                        !(attributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
                    fwprintf(stderr, L"Installation destination leaf is a directory: %s\n", destination);
                    ok = 0;
                } else {
                    /* Deny new readers/writers while CMake publishes. DELETE
                     * sharing permits its rename without rewriting mapped files.
                     * A running executable or incompatible open handle rejects
                     * the entire preflight before any destination is replaced. */
                    file = CreateFileW(destination, GENERIC_READ | GENERIC_WRITE | DELETE,
                        FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
                        FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, NULL);
                    if (file == INVALID_HANDLE_VALUE) {
                        fwprintf(stderr, L"Installation file is in use or cannot be replaced (Windows error %lu): %s\n",
                            GetLastError(), destination);
                        ok = 0;
                    } else {
                        ok = remember(file);
                    }
                }
            } else {
                DWORD error = GetLastError();
                ok = error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND;
            }
        }
        free(source);
        free(destination);
        if (!ok) break;
    } while (FindNextFileW(search, &entry));
    if (ok && GetLastError() != ERROR_NO_MORE_FILES) ok = 0;
    FindClose(search);
    return ok;
}

/* Delete-pending old leaves disappear when the held handles close. Only empty
 * private-stage directories may remain; never remove a remaining file here. */
static int prune_empty_stage(const wchar_t *stage)
{
    WIN32_FIND_DATAW entry;
    wchar_t *pattern = joined(stage, L"*");
    HANDLE search;
    int ok = 1;
    if (!pattern) return 0;
    search = FindFirstFileW(pattern, &entry);
    free(pattern);
    if (search == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        if (error == ERROR_PATH_NOT_FOUND) return 1;
        if (error != ERROR_FILE_NOT_FOUND) return 0;
    } else {
        do {
            wchar_t *child;
            if (!wcscmp(entry.cFileName, L".") || !wcscmp(entry.cFileName, L"..")) continue;
            if (!(entry.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ||
                    (entry.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) { ok = 0; break; }
            child = joined(stage, entry.cFileName);
            if (!child) { ok = 0; break; }
            ok = prune_empty_stage(child);
            free(child);
            if (!ok) break;
        } while (FindNextFileW(search, &entry));
        FindClose(search);
    }
    if (ok && !RemoveDirectoryW(stage)) {
        DWORD error = GetLastError();
        ok = error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND;
    }
    return ok;
}

int wmain(int argc, wchar_t **argv)
{
    intptr_t result = 1;
    size_t index;
    wchar_t **arguments;
    if (argc < 5) {
        fputs("Usage: otp_windows_publish STAGE PREFIX CMAKE ARG...\n", stderr);
        return 2;
    }
    arguments = calloc((size_t) argc - 2, sizeof(*arguments));
    if (!arguments) return 1;
    for (index = 3; index < (size_t) argc; ++index) {
        arguments[index - 3] = quoted(argv[index]);
        if (!arguments[index - 3]) break;
    }
    if (index != (size_t) argc) goto done;
    if (preflight(argv[1], argv[2])) {
        result = _wspawnv(_P_WAIT, argv[3], (const wchar_t *const *) arguments);
        if (result == -1) { perror("Cannot start installation publisher"); result = 1; }
    }
done:
    for (index = 0; index < held_count; ++index) CloseHandle(held[index]);
    if (result == 0 && !prune_empty_stage(argv[1])) {
        fwprintf(stderr, L"Published files but could not retire the empty private stage: %s\n", argv[1]);
        result = 1;
    }
    for (index = 0; arguments[index]; ++index) free(arguments[index]);
    free(arguments);
    free(held);
    return (int) result;
}
