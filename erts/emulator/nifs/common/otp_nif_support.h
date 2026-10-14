/* SPDX-License-Identifier: Apache-2.0 */
#ifndef OTP_NIF_SUPPORT_H
#define OTP_NIF_SUPPORT_H

/* Product-local C helpers. Native modules include only the public NIF SDK. */
#include <stdint.h>
#include <string.h>
#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#include <io.h>
#include <sys/types.h>
#include <erl_driver.h>
/* Match the retained Windows native I/O interfaces (DWORD-sized transfers). */
#if defined(_MSC_VER)
typedef long ssize_t;
#endif
#endif

#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif

/* DEBUG controls the upstream native invariants, independently of NDEBUG. */
#ifdef DEBUG
#include <stdio.h>
#include <stdlib.h>
static inline void otp_nif_assert_fail(const char *expression,
                                      const char *file, int line)
{
    fprintf(stderr, "%s:%d: assertion failed: %s\n", file, line, expression);
    abort();
}
#define ASSERT(expression) ((expression) ? (void) 0 : \
    otp_nif_assert_fail(#expression, __FILE__, __LINE__))
#else
#define ASSERT(expression) ((void) 0)
#endif

#endif
