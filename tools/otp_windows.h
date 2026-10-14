/* SPDX-License-Identifier: Apache-2.0 */
#ifndef OTP_WINDOWS_H
#define OTP_WINDOWS_H
#include <winsock2.h>
#include <windows.h>
#include <stdlib.h>
#include <wchar.h>
#ifndef PATH_MAX
#define PATH_MAX 131072
#endif
static char *otp_windows_utf8(const wchar_t *wide)
{
    int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, NULL, 0, NULL, NULL);
    char *text = size ? malloc((size_t)size) : NULL;
    if (text && !WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, text, size, NULL, NULL)) {
        free(text); return NULL;
    }
    return text;
}
#endif
