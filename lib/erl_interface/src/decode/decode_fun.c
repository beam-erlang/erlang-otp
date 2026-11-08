/*
 * %CopyrightBegin%
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright Ericsson AB 2001-2025. All Rights Reserved.
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
#include <string.h>
#include <stdlib.h>

#include "eidef.h"
#include "eiext.h"
#include "ei_malloc.h"
#include "decode_skip.h"
#include "putget.h"

int ei_decode_fun(const char *buf, int *index, erlang_fun *p)
{
    BeamEtfFun value = {0};
    int status = beam_etf_embed_decode_fun(buf, index, p ? &value : NULL);
    if (p) {
        if (status == 0) ei_etf_fun_from(p, &value);
        else beam_etf_embed_free_fun(&value);
    }
    return status;
}

void free_fun(erlang_fun* f)
{
    BeamEtfFun value = {0};
    ei_etf_fun_to(&value, f);
    beam_etf_embed_free_fun(&value);
}
