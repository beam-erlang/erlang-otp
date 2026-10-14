/* SPDX-License-Identifier: Apache-2.0 */
#ifndef OTP_SOCKET_SUPPORT_H
#define OTP_SOCKET_SUPPORT_H
#include "otp_socket_config.h"
#include "otp_nif_support.h"
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#ifndef _WIN32
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/uio.h>
#include <net/if.h>
#endif
#ifdef HAVE_SCHED_H
#include <sched.h>
#endif
#include <erl_nif.h>
#include <erl_driver.h>
#include <beam/native.h>

static inline void otp_socket_zero(void *bytes, size_t length)
{
    memset(bytes, 0, length);
}

#ifndef _WIN32
static inline int otp_socket_nonblocking(int descriptor)
{
#ifdef _WIN32
    u_long mode = 1;
    return ioctlsocket((SOCKET)descriptor, FIONBIO, &mode);
#else
    int flags = fcntl(descriptor, F_GETFL, 0);
    return flags < 0 ? -1 : fcntl(descriptor, F_SETFL, flags | O_NONBLOCK);
#endif
}
#define SET_NONBLOCKING(descriptor) otp_socket_nonblocking(descriptor)
static inline int otp_socket_blocking(int descriptor)
{
#ifdef _WIN32
    u_long mode = 0;
    return ioctlsocket((SOCKET)descriptor, FIONBIO, &mode);
#else
    int flags = fcntl(descriptor, F_GETFL, 0);
    return flags < 0 ? -1 : fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK);
#endif
}
#define SET_BLOCKING(descriptor) otp_socket_blocking(descriptor)
#endif

static inline void otp_socket_put_u16(uint16_t value, unsigned char *bytes)
{
    bytes[0] = (unsigned char) (value >> 8);
    bytes[1] = (unsigned char) value;
}

static inline uint16_t otp_socket_get_u16(const unsigned char *bytes)
{
    return ((uint16_t) bytes[0] << 8) | bytes[1];
}
#ifndef _WIN32
#define ERRNO_BLOCK EAGAIN
#endif
#endif
