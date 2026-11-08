/*
 * %CopyrightBegin%
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright Ericsson AB 1998-2025. All Rights Reserved.
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
#include "eidef.h"
#include "eiext.h"
#include "putget.h"


int ei_decode_atom(const char *buf, int *index, char *p)
{
    return ei_decode_atom_as(buf, index, p, MAXATOMLEN, ERLANG_LATIN1, NULL, NULL);
}

int ei_decode_atom_as(const char *buf, int *index, char* p, int destlen,
		      erlang_char_encoding want_enc,
		      erlang_char_encoding* was_encp,
		      erlang_char_encoding* res_encp)
{
    BeamEtfCompatCharEncoding was = 0, result = 0;
    int status = beam_etf_compat_decode_atom_as(buf, index, p, destlen,
        (BeamEtfCompatCharEncoding)want_enc, was_encp ? &was : NULL, res_encp ? &result : NULL);
    if (was_encp && was) *was_encp = (erlang_char_encoding)was;
    if (res_encp && result) *res_encp = (erlang_char_encoding)result;
    return status;
}	



int ei_internal_get_atom(const char** bufp, char* p,
			 erlang_char_encoding* was_encp)
{
    int ix = 0;
    if (ei_decode_atom_as(*bufp, &ix, p, MAXATOMLEN_UTF8, ERLANG_UTF8, was_encp, NULL) < 0)
	return -1;
    *bufp += ix;
    return 0;
}


