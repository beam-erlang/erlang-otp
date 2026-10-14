/* SPDX-License-Identifier: Apache-2.0 */
#include <ethread.h>
#include <erl_printf.h>
#include <string.h>

static void *worker(void *argument) { return argument; }
int main(void)
{
    ethr_tid thread;
    void *result = NULL;
    char text[32];
    if (ethr_init(NULL) || ethr_late_init(NULL)) return 1;
    if (ethr_thr_create(&thread, worker, text, NULL) || ethr_thr_join(thread, &result)) return 2;
    if (result != text || erts_snprintf(text, sizeof(text), "answer=%d", 42) != 9) return 3;
    return strcmp(text, "answer=42") != 0;
}
