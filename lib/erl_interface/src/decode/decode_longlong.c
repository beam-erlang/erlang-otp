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

#ifdef EI_64BIT
int ei_decode_long(const char *buf, int *index, long *p)
{
    return beam_etf_embed_decode_long(buf, index, p);
}
#endif

#ifdef _MSC_VER
#define MAX_TO_NEGATE 0x8000000000000000Ui64
#define MAX_TO_NOT_NEGATE 0x7FFFFFFFFFFFFFFFUi64
#else 
#define MAX_TO_NEGATE 0x8000000000000000ULL
#define MAX_TO_NOT_NEGATE 0x7FFFFFFFFFFFFFFFULL
#endif

int ei_decode_longlong(const char *buf, int *index, EI_LONGLONG *p)
{
    return beam_etf_embed_decode_longlong(buf, index, p);
}
