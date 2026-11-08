/* SPDX-License-Identifier: Apache-2.0 */
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>
#include <erl_nif.h>

static ERL_NIF_TERM stock(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int error, count = -1;
    PCRE2_SIZE offset;
    pcre2_code *code;
    pcre2_match_data *data;
    (void)argc; (void)argv;
    code = pcre2_compile((PCRE2_SPTR)"^(host)([0-9]+)$", PCRE2_ZERO_TERMINATED,
                         0, &error, &offset, NULL);
    if (!code) return enif_make_badarg(env);
    data = pcre2_match_data_create_from_pattern(code, NULL);
    if (data) {
        count = pcre2_match(code, (PCRE2_SPTR)"host123", 7, 0, 0, data, NULL);
        if (count == 3) {
            PCRE2_SIZE *captures = pcre2_get_ovector_pointer(data);
            if (captures[2] != 0 || captures[3] != 4 || captures[4] != 4 || captures[5] != 7)
                count = -1;
        }
        pcre2_match_data_free(data);
    }
    pcre2_code_free(code);
    return count == 3 ? enif_make_atom(env, "stock_ok") : enif_make_badarg(env);
}
static ErlNifFunc functions[] = {{"stock", 0, stock, 0}};
ERL_NIF_INIT(otp_re_coexist, functions, NULL, NULL, NULL, NULL)
