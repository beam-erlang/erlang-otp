/* SPDX-License-Identifier: Apache-2.0 */
#include <erl_nif.h>
#include <erl_internal_test.h>

/* Retained native test ABI declared by alloc_SUITE_data/allocator_test.h.
 * Operation 0xf05 queries availability without changing allocator state. */
extern unsigned long erts_alc_test(unsigned long, unsigned long,
                                   unsigned long, unsigned long);

static void *worker(void *argument) { return argument; }
static ERL_NIF_TERM check(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    ethr_rwmutex mutex;
    ethr_rwmutex_opt options = ETHR_RWMUTEX_OPT_DEFAULT_INITER;
    ethr_atomic_t counter;
    ethr_tid thread;
    void *result = NULL;
    (void)argc; (void)argv;
    if (erts_internal_test.ethr_rwmutex_init_opt(&mutex, &options)) return enif_make_badarg(env);
    erts_internal_test.ethr_rwmutex_rwlock(&mutex);
    erts_internal_test.ethr_atomic_init(&counter, 41);
    erts_internal_test.ethr_atomic_inc(&counter);
    int passed = erts_internal_test.ethr_atomic_read(&counter) == 42
        && erts_alc_test(0xf05, 0, 0, 0) == 1;
    erts_internal_test.ethr_rwmutex_rwunlock(&mutex);
    passed &= erts_internal_test.ethr_rwmutex_destroy(&mutex) == 0;
    if (erts_internal_test.ethr_thr_create(&thread, worker, &counter, NULL)) return enif_make_badarg(env);
    passed &= erts_internal_test.ethr_thr_join(thread, &result) == 0 && result == &counter;
    return enif_make_atom(env, passed ? "ok" : "failed");
}
static ErlNifFunc functions[] = {{"check", 0, check, 0}};
ERL_NIF_INIT(development_probe, functions, NULL, NULL, NULL, NULL)
