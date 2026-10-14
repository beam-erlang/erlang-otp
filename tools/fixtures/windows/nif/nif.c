/* SPDX-License-Identifier: Apache-2.0 */
#include <erl_nif.h>
static ERL_NIF_TERM twice(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int value;
    if (argc != 1 || !enif_get_int(env, argv[0], &value) || value < -1000 || value > 1000)
        return enif_make_badarg(env);
    return enif_make_int(env, value * 2);
}
static ErlNifFunc functions[] = {{"double",1,twice,0}};
ERL_NIF_INIT(otp_windows_nif,functions,NULL,NULL,NULL,NULL)
