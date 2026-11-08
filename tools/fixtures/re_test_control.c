/* SPDX-License-Identifier: Apache-2.0 */
#include <erl_nif.h>
#include <stdint.h>
#include <time.h>
#ifndef OTP_RE_CLOCK_ONLY
extern size_t otp_re_test_allocations(void), otp_re_test_resources(void);
extern size_t otp_re_test_bytes(void), otp_re_test_peak_bytes(void);
extern size_t otp_re_test_total_allocations(void), otp_re_test_total_allocated_bytes(void);
extern size_t otp_re_test_compile_entered(void), otp_re_test_compile_active(void);
extern size_t otp_re_test_module_owners(void);
extern unsigned otp_re_test_compile_hold(unsigned), otp_re_test_fail_upgrade(unsigned);
extern int otp_re_test_set_limit(int);
extern size_t otp_re_test_yield_coverage(const int **,const uint64_t **,const uint64_t **);
static ERL_NIF_TERM stats(ErlNifEnv *env,int argc,const ERL_NIF_TERM argv[])
{
    (void)argc;(void)argv;
    const char *keys[]={"allocations","resources","bytes","peak_bytes","total_allocations","total_bytes","compile_entered","compile_active","owners"};
    size_t values[]={otp_re_test_allocations(),otp_re_test_resources(),otp_re_test_bytes(),otp_re_test_peak_bytes(),otp_re_test_total_allocations(),otp_re_test_total_allocated_bytes(),otp_re_test_compile_entered(),otp_re_test_compile_active(),otp_re_test_module_owners()};
    ERL_NIF_TERM result=enif_make_new_map(env);
    for(size_t i=0;i<sizeof(values)/sizeof(values[0]);++i)
        if(!enif_make_map_put(env,result,enif_make_atom(env,keys[i]),enif_make_uint64(env,values[i]),&result)) return enif_make_badarg(env);
    return result;
}
static ERL_NIF_TERM limit(ErlNifEnv *env,int argc,const ERL_NIF_TERM argv[])
{
    int value;(void)argc;
    if(enif_is_identical(argv[0],enif_make_atom(env,"default"))) value=-1;
    else if(!enif_get_int(env,argv[0],&value)||value<=0) return enif_make_badarg(env);
    return enif_make_int(env,otp_re_test_set_limit(value));
}
static ERL_NIF_TERM coverage(ErlNifEnv *env,int argc,const ERL_NIF_TERM argv[])
{
    const int *lines;const uint64_t *visits,*yields;(void)argc;(void)argv;
    size_t count=otp_re_test_yield_coverage(&lines,&visits,&yields);
    ERL_NIF_TERM result=enif_make_list(env,0);
    while(count){--count;result=enif_make_list_cell(env,enif_make_tuple3(env,enif_make_int(env,lines[count]),enif_make_uint64(env,visits[count]),enif_make_uint64(env,yields[count])),result);}
    return result;
}
static ERL_NIF_TERM hold(ErlNifEnv *env,int argc,const ERL_NIF_TERM argv[])
{
    unsigned ms;(void)argc;
    if(!enif_get_uint(env,argv[0],&ms)||ms>1000) return enif_make_badarg(env);
    return enif_make_uint(env,otp_re_test_compile_hold(ms));
}
static ERL_NIF_TERM fail_upgrade(ErlNifEnv *env,int argc,const ERL_NIF_TERM argv[])
{
    unsigned stage;(void)argc;
    if(!enif_get_uint(env,argv[0],&stage)||stage>3) return enif_make_badarg(env);
    return enif_make_uint(env,otp_re_test_fail_upgrade(stage));
}
#endif
static ERL_NIF_TERM clocks(ErlNifEnv *env,int argc,const ERL_NIF_TERM argv[])
{
    struct timespec cpu,wall;(void)argc;(void)argv;
    if(clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&cpu)||clock_gettime(CLOCK_MONOTONIC,&wall)) return enif_make_badarg(env);
    return enif_make_tuple2(env,enif_make_uint64(env,(uint64_t)cpu.tv_sec*1000000000+cpu.tv_nsec),enif_make_uint64(env,(uint64_t)wall.tv_sec*1000000000+wall.tv_nsec));
}
static ErlNifFunc functions[]={
    {"clocks",0,clocks,0},
#ifndef OTP_RE_CLOCK_ONLY
    {"stats",0,stats,0},{"limit",1,limit,0},{"coverage",0,coverage,0},
    {"compile_hold",1,hold,0},{"fail_upgrade",1,fail_upgrade,0},
#endif
};
ERL_NIF_INIT(otp_re_test,functions,NULL,NULL,NULL,NULL)
