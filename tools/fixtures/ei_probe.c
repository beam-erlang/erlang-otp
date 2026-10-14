/* SPDX-License-Identifier: Apache-2.0 */
#include <ei.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static int connection_error(void)
{
    ei_cnode node;
    struct sockaddr_in address = {0};
    socklen_t length = sizeof(address);
    /* Reserve a loopback port without listening: connection refusal is
     * deterministic and cannot race another server claiming the port. */
    int reserved = socket(AF_INET, SOCK_STREAM, 0);
    if (reserved < 0) return 1;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(reserved, (struct sockaddr *)&address, sizeof(address)) ||
        getsockname(reserved, (struct sockaddr *)&address, &length) ||
        ei_connect_init(&node, "otp_ei_probe", "otp_ei_cookie", 0)) {
        close(reserved);
        return 1;
    }
    int connection = ei_connect_host_port_tmo(
        &node, "127.0.0.1", ntohs(address.sin_port), 1000);
    int saved = erl_errno;
    if (connection >= 0) ei_close_connection(connection);
    close(reserved);
#ifdef __APPLE__
    /* Darwin drops SYNs for a bound, non-listening socket. The pinned original
     * EI returns ERL_CONNECT_FAIL/ETIMEDOUT for this reserved-port control. */
    return connection != ERL_CONNECT_FAIL || saved != ETIMEDOUT;
#else
    return connection >= 0 || saved != EIO;
#endif
}

int main(void)
{
    ei_x_buff encoded;
    int index = 0, version, arity;
    long integer;
    double floating;
    char atom[32];
    if (ei_init() || ei_x_new_with_version(&encoded)) return 1;
    if (ei_x_encode_tuple_header(&encoded, 3) || ei_x_encode_atom(&encoded, "otp_ei") ||
        ei_x_encode_long(&encoded, 42) || ei_x_encode_double(&encoded, 3.5)) return 2;
    if (ei_decode_version(encoded.buff, &index, &version) ||
        ei_decode_tuple_header(encoded.buff, &index, &arity) || arity != 3 ||
        ei_decode_atom(encoded.buff, &index, atom) || strcmp(atom, "otp_ei") ||
        ei_decode_long(encoded.buff, &index, &integer) || integer != 42 ||
        ei_decode_double(encoded.buff, &index, &floating) || floating != 3.5 ||
        index != encoded.index) return 3;
    ei_x_free(&encoded);
    if (connection_error()) return 4;
    puts("ei_passed");
    return 0;
}
