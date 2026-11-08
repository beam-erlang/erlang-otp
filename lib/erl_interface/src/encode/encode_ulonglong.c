/*
 * %CopyrightBegin%
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright Ericsson AB 2002-2025. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * %CopyrightEnd%
 */
#include "eidef.h"
#include "eiext.h"
#include "putget.h"
#include "ei_x_encode.h"

/*
 * For some 64 bit operations on some operating systems code
 * compiled with GNU cc depends on "libgcc" for some 64 bit
 * operations missing in hardware (or because of gcc bugs).
 * If user code was linked together with the ei lib
 * using other linkers than GNU ld this may cause problems.
 * We moved ei_x_encode_ulonglong() here from "ei_x_encode.c" 
 * to limit this problem to users that actually use the ei 
 * longlong operations, not all ei_x users.
 */
int ei_x_encode_ulonglong(ei_x_buff* x, EI_ULONGLONG n)
{
    int i = x->index;
    ei_encode_ulonglong(NULL, &i, n);
    if (!x_fix_buff(x, i))
	return -1;
    return ei_encode_ulonglong(x->buff, &x->index, n);
}

#ifdef EI_64BIT
int ei_encode_ulong(char *buf, int *index, unsigned long p)
{
    return beam_etf_embed_encode_ulong(buf, index, p);
}
#endif

int ei_encode_ulonglong(char *buf, int *index, EI_ULONGLONG p)
{
    return beam_etf_embed_encode_ulonglong(buf, index, p);
}

