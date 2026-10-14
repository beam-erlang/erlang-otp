/* SPDX-License-Identifier: Apache-2.0 */
/* Test-only Darwin allocation failures; never linked into the OTP product. */
#include <errno.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdlib.h>

static _Atomic size_t failure_threshold;
void otp_test_allocation_limit(size_t threshold)
{ atomic_store_explicit(&failure_threshold, threshold, memory_order_relaxed); }
static int rejected(size_t bytes)
{
    size_t threshold = atomic_load_explicit(&failure_threshold, memory_order_relaxed);
    if (threshold && bytes >= threshold) { errno = ENOMEM; return 1; }
    return 0;
}
static void *failing_malloc(size_t size)
{ return rejected(size) ? NULL : malloc(size); }
static void *failing_calloc(size_t count, size_t size)
{
    if (count && size > SIZE_MAX / count) { errno = ENOMEM; return NULL; }
    return rejected(count * size) ? NULL : calloc(count, size);
}
static void *failing_realloc(void *pointer, size_t size)
{ return rejected(size) ? NULL : realloc(pointer, size); }
#define INTERPOSE(replacement, original) \
    __attribute__((used)) static struct { const void *replace, *replacee; } \
    interpose_##original __attribute__((section("__DATA,__interpose"))) = \
        {(const void *)&replacement, (const void *)&original}
/* Calls from this image retain their original binding, so the forwarding calls
 * above reach libc rather than recursively interposing themselves. */
INTERPOSE(failing_malloc, malloc);
INTERPOSE(failing_calloc, calloc);
INTERPOSE(failing_realloc, realloc);
