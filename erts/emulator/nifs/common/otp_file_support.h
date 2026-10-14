/* SPDX-License-Identifier: Apache-2.0 */
#ifndef OTP_FILE_SUPPORT_H
#define OTP_FILE_SUPPORT_H

/* Product-local file platform requirements; no VM-private configuration. */
#include "otp_file_config.h"
#include "otp_nif_support.h"
#include <beam/native.h>
#include <stdatomic.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#ifndef _WIN32
#include <unistd.h>
#include <dirent.h>
#include <sys/uio.h>

_Static_assert(sizeof(off_t) == 8, "OTP files require 64-bit offsets");
#endif

static inline uint32_t otp_file_read_u32_be(const unsigned char *bytes)
{
    return ((uint32_t) bytes[0] << 24) | ((uint32_t) bytes[1] << 16) |
           ((uint32_t) bytes[2] << 8) | (uint32_t) bytes[3];
}

/* Preserve the previous-value result on success and failure. Sequential
 * consistency covers the original acquire/release/relaxed transitions. */
static inline int32_t otp_file_state_compare(_Atomic int32_t *state,
                                             int32_t desired, int32_t expected)
{
    atomic_compare_exchange_strong_explicit(state, &expected, desired,
                                            memory_order_seq_cst,
                                            memory_order_seq_cst);
    return expected;
}

#define OTP_FILE_INTERNAL_ERROR(message) \
    beam_native_fail(BEAM_NATIVE_FAILURE_ABORT, \
                     "%s:%d:%s(): Internal error: %s\n", \
                     __FILE__, __LINE__, __func__, (message))

#endif
