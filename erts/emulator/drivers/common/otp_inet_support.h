/* SPDX-License-Identifier: Apache-2.0 */
#ifndef OTP_INET_SUPPORT_H
#define OTP_INET_SUPPORT_H
#include "otp_inet_config.h"
#if defined(INET_DRV_DEBUG) && !defined(DEBUG)
#define DEBUG 1
#endif
#include "otp_nif_support.h"
#include <erl_driver.h>
#include <erl_nif.h>
#include <beam/native.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <limits.h>
#include <math.h>
#include <errno.h>
#include <fcntl.h>
#ifndef _WIN32
#include <strings.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/uio.h>
#endif

#if UINTPTR_MAX == UINT64_MAX
#define ARCH_64 1
#endif
/* Shared with the OTP-owned prim_inet command protocol. */
#define OTP_INET_CONTROL_MAGIC 0x03f1a300U
static inline int otp_inet_local_pid(ErlDrvTermData caller)
{
    ErlNifPid pid;
    return enif_get_local_pid(NULL, (ERL_NIF_TERM)caller, &pid);
}
#define OTP_INET_STATIC_ASSERT(condition) _Static_assert(condition, #condition)
#ifdef _MSC_VER
#define OTP_INET_FALLTHROUGH() ((void)0)
#else
#define OTP_INET_FALLTHROUGH() __attribute__((fallthrough))
#endif
#define OTP_INET_INTERNAL_ERROR(message) \
    beam_native_fail(BEAM_NATIVE_FAILURE_ABORT, \
        "%s:%d:%s(): Internal error: %s\n", __FILE__, __LINE__, __func__, (message))

static inline int otp_inet_printf(const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = enif_vfprintf(stdout, format, arguments);
    va_end(arguments);
    return result;
}
#ifdef DEBUG
#define DEBUGF(arguments) otp_inet_printf arguments
#else
#define DEBUGF(arguments) ((void)0)
#endif

#ifndef _WIN32
static inline int otp_inet_nonblocking(int descriptor)
{
    int flags = fcntl(descriptor, F_GETFL, 0);
    return flags < 0 ? -1 : fcntl(descriptor, F_SETFL, flags | O_NONBLOCK);
}
#define SET_NONBLOCKING(descriptor) otp_inet_nonblocking(descriptor)
#define ERRNO_BLOCK EAGAIN
#endif
static inline void otp_inet_zero(void *bytes, size_t length) { memset(bytes, 0, length); }

static inline uint64_t otp_inet_read_be(const void *buffer, unsigned length)
{
    const unsigned char *bytes = buffer;
    uint64_t value = 0;
    for (unsigned i = 0; i < length; ++i) value = (value << 8) | bytes[i];
    return value;
}
static inline void otp_inet_write_be(uint64_t value, void *buffer, unsigned length)
{
    unsigned char *bytes = buffer;
    while (length) { bytes[--length] = (unsigned char)value; value >>= 8; }
}
#define get_int8(buffer) ((unsigned char)otp_inet_read_be((buffer),1))
#define get_int16(buffer) ((uint16_t)otp_inet_read_be((buffer),2))
#define get_int32(buffer) ((int32_t)otp_inet_read_be((buffer),4))
#define get_int64(buffer) (otp_inet_read_be((buffer),8))
#define put_int8(value, buffer) otp_inet_write_be((value),(buffer),1)
#define put_int16(value, buffer) otp_inet_write_be((value),(buffer),2)
#define put_int32(value, buffer) otp_inet_write_be((value),(buffer),4)
#define put_int64(value, buffer) otp_inet_write_be((value),(buffer),8)
#endif
