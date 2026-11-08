/* SPDX-License-Identifier: Apache-2.0 */
#define USE_EI_UNDOCUMENTED
#include <ei.h>
#include <errno.h>
#include <limits.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define VERIFY(expr) do { if (!(expr)) { fprintf(stderr,"ei compatibility line %d: %s\n",__LINE__,#expr); return 1; } } while (0)
extern int ei_x_extra;

static int codec_compatibility(void)
{
    char wire[4096], output[2048], long_atom[1021];
    int i = 0, n, type, size;
    ei_x_buff x;
    erlang_char_encoding was = ERLANG_ASCII, result = ERLANG_ASCII;
    long signed_value;
    unsigned long unsigned_value;
    VERIFY(ei_encode_long(wire,&i,LONG_MIN) == 0);
    n = 0; VERIFY(ei_decode_long(wire,&n,&signed_value) == 0 && signed_value == LONG_MIN && n == i);
    i = 0; VERIFY(ei_encode_ulong(wire,&i,ULONG_MAX) == 0);
    n = 0; VERIFY(ei_decode_ulong(wire,&n,&unsigned_value) == 0 && unsigned_value == ULONG_MAX && n == i);
    i = 0;
    VERIFY(ei_encode_atom(wire,&i,"\xe9") == 0);
    n = 0; VERIFY(ei_decode_atom(wire,&n,output) == 0 && !strcmp(output,"\xe9"));
    n = 0; VERIFY(ei_decode_atom_as(wire,&n,output,sizeof output,ERLANG_UTF8,&was,&result) == 0);
    VERIFY(!strcmp(output,"\xc3\xa9") && was == ERLANG_UTF8 && result == ERLANG_UTF8);
    memset(long_atom,'a',256); long_atom[256] = 0;
    i = 0; VERIFY(ei_encode_atom(wire,&i,long_atom) == 0);
    n = 0; VERIFY(ei_get_type(wire,&n,&type,&size) == 0 && size == 255);
    VERIFY(ei_x_new(&x) == 0);
    char *before = x.buff; int capacity = x.buffsz, cursor = x.index;
    VERIFY(ei_x_encode_atom(&x,long_atom) == -1 && x.buff == before && x.buffsz == capacity && x.index == cursor);
    i = 0; VERIFY(ei_encode_atom_as(wire,&i,"\xf0\x9f\x90\xa7",ERLANG_UTF8,ERLANG_LATIN1) == 0);
    n = 0; VERIFY(ei_decode_atom(wire,&n,output) == -1 && n == 0);
    VERIFY(ei_decode_atom_as(wire,&n,output,sizeof output,ERLANG_UTF8,NULL,NULL) == 0 && !strcmp(output,"\xf0\x9f\x90\xa7"));
    ei_x_extra = 17;
    memset(wire,23,sizeof wire);
    VERIFY(ei_x_append_buf(&x,wire,sizeof wire) == 0 && x.index == sizeof wire && x.buffsz == sizeof wire+34);
    ei_x_extra = 100;
    VERIFY(ei_x_free(&x) == 0);
    erlang_big *big = ei_alloc_big(5), *decoded = ei_alloc_big(5);
    VERIFY(big && decoded);
    unsigned short *digits = (unsigned short *)big->digits;
    digits[0] = 0x1234; digits[1] = 0x5678; digits[2] = 0x9a; big->is_neg = 1;
    i = 0; VERIFY(ei_encode_big(wire,&i,big) == 0);
    const unsigned char expected[] = {'n',5,1,0x34,0x12,0x78,0x56,0x9a};
    VERIFY(i == sizeof expected && !memcmp(wire,expected,sizeof expected));
    n = 0; VERIFY(ei_decode_big(wire,&n,decoded) == 0 && decoded->is_neg == 1 && n == i && !memcmp(decoded->digits,big->digits,6));
    ei_free_big(big); ei_free_big(decoded);
    erlang_fun fun = {0}, decoded_fun = {0};
    fun.type = EI_FUN_EXPORT; fun.arity = 1; strcpy(fun.module,"erlang"); fun.u.exprt.func = "length";
    i = 0; VERIFY(ei_encode_fun(wire,&i,&fun) == 0);
    n = 0; VERIFY(ei_decode_fun(wire,&n,&decoded_fun) == 0 && n == i);
    VERIFY(decoded_fun.u.exprt.func == decoded_fun.module+7 && !strcmp(decoded_fun.u.exprt.func,"length"));
    i = 0; VERIFY(ei_encode_fun(wire,&i,&decoded_fun) == 0); free_fun(&decoded_fun);
    for (i=0; i<255; ++i) memcpy(long_atom+4*i,"\xf0\x9f\x90\xa7",4);
    long_atom[1020] = 0; memcpy(fun.module,long_atom,1021); fun.u.exprt.func = long_atom;
    i = 0; VERIFY(ei_encode_fun(wire,&i,&fun) == 0);
    n = 0; VERIFY(ei_decode_fun(wire,&n,&decoded_fun) == 0 && n == i && decoded_fun.u.exprt.func_allocated && !strcmp(decoded_fun.u.exprt.func,long_atom));
    free_fun(&decoded_fun);
    return 0;
}

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

static int reference_roundtrip(const char *port)
{
    ei_cnode node;
    ei_x_buff args, reply;
    erlang_fun fun = {0}, result_fun = {0};
    EI_LONGLONG value;
    char atom[32], bytes[3];
    long length;
    int i = 0, arity;
    VERIFY(ei_connect_init(&node,"codec_client","etf_interop_cookie",0) == 0);
    int fd = ei_connect_host_port_tmo(&node,"127.0.0.1",atoi(port),5000);
    VERIFY(fd >= 0);
    VERIFY(ei_x_new(&args) == 0 && ei_x_new(&reply) == 0);
    /* hd/1 receives one argument, a list containing the tuple to echo. */
    VERIFY(ei_x_encode_list_header(&args,1) == 0 && ei_x_encode_list_header(&args,1) == 0);
    VERIFY(ei_x_encode_tuple_header(&args,4) == 0);
    VERIFY(ei_x_encode_atom_as(&args,"\xc3\xa9",ERLANG_UTF8,ERLANG_UTF8) == 0);
    VERIFY(ei_x_encode_longlong(&args,9223372036854775807LL) == 0);
    VERIFY(ei_x_encode_binary(&args,"\0\1\xff",3) == 0);
    fun.type = EI_FUN_EXPORT; fun.arity = 1; strcpy(fun.module,"erlang"); fun.u.exprt.func = "length";
    VERIFY(ei_x_encode_fun(&args,&fun) == 0 && ei_x_encode_empty_list(&args) == 0 && ei_x_encode_empty_list(&args) == 0);
    VERIFY(ei_rpc(&node,fd,"erlang","hd",args.buff,args.index,&reply) == 0);
    VERIFY(ei_decode_tuple_header(reply.buff,&i,&arity) == 0 && arity == 4);
    VERIFY(ei_decode_atom_as(reply.buff,&i,atom,sizeof atom,ERLANG_UTF8,NULL,NULL) == 0 && !strcmp(atom,"\xc3\xa9"));
    VERIFY(ei_decode_longlong(reply.buff,&i,&value) == 0 && value == 9223372036854775807LL);
    VERIFY(ei_decode_binary(reply.buff,&i,bytes,&length) == 0 && length == 3 && !memcmp(bytes,"\0\1\xff",3));
    VERIFY(ei_decode_fun(reply.buff,&i,&result_fun) == 0 && i == reply.index && result_fun.arity == 1 && !strcmp(result_fun.module,"erlang") && !strcmp(result_fun.u.exprt.func,"length"));
    free_fun(&result_fun); ei_x_free(&args); ei_x_free(&reply);
    VERIFY(ei_close_connection(fd) == 0);
    return 0;
}

int main(int argc, char **argv)
{
    ei_x_buff encoded;
    int index = 0, version, arity;
    long integer;
    double floating;
    char atom[32];
    if (codec_compatibility()) return 5;
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
    if (argc == 2 && reference_roundtrip(argv[1])) return 6;
    if (argc > 2) return 7;
    puts("ei_passed");
    return 0;
}
