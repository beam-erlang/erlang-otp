/* SPDX-License-Identifier: Apache-2.0 */
#include <ei.h>
#include <stdlib.h>
#include <stdio.h>
static int fail_growth;
void *__real_realloc(void *, size_t);
void *__wrap_realloc(void *pointer, size_t size)
{
    if (fail_growth) return NULL;
    return __real_realloc(pointer,size);
}
extern int ei_x_extra;
int main(void)
{
    ei_x_buff buffer;
    char bytes[256] = {0};
    if (ei_x_new(&buffer)) return 1;
    char *allocation = buffer.buff;
    int old_index = buffer.index;
    ei_x_extra = 17;
    fail_growth = 1;
    int status = ei_x_append_buf(&buffer,bytes,sizeof bytes);
    fail_growth = 0;
    /* Preserve the original library's failed realloc assignment behavior. */
    int failed = status != -1 || buffer.buff != NULL ||
        buffer.buffsz != sizeof bytes+34 || buffer.index != old_index;
    free(allocation);
    if (failed) return 2;
    puts("ei_growth_failure_passed");
    return 0;
}
