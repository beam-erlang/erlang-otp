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
#include <limits.h>
#include "eidef.h"
#include "eiext.h"
#include "putget.h"



int ei_encode_atom(char *buf, int *index, const char *p)
{
    size_t len = strlen(p);

    if (len >= MAXATOMLEN)
	len = MAXATOMLEN - 1;
    return ei_encode_atom_len_as(buf, index, p, len, ERLANG_LATIN1, 0);
}

int ei_encode_atom_len(char *buf, int *index, const char *p, int len)
{
    /* This function is documented to truncate at MAXATOMLEN (256) */ 
    if (len >= MAXATOMLEN)
	len = MAXATOMLEN - 1;
    return ei_encode_atom_len_as(buf, index, p, len, ERLANG_LATIN1, 0);
}

int ei_encode_atom_as(char *buf, int *index, const char *p,
		      erlang_char_encoding from_enc,
		      erlang_char_encoding to_enc)
{	
    return ei_encode_atom_len_as(buf, index, p, strlen(p), from_enc, to_enc);
}

int ei_encode_atom_len_as(char *buf, int *index, const char *p, int len,
			  erlang_char_encoding from_enc,
			  erlang_char_encoding to_enc)
{
    return beam_etf_compat_encode_atom_len_as(buf, index, p, len,
        (BeamEtfCompatCharEncoding)from_enc, (BeamEtfCompatCharEncoding)to_enc);
}

int
ei_internal_put_atom(char** bufp, const char* p, int slen,
		     erlang_char_encoding to_enc)
{
    int ix = 0;
    if (ei_encode_atom_len_as(*bufp, &ix, p, slen, ERLANG_UTF8, to_enc) < 0)
	return -1;
    *bufp += ix;
    return 0;
}
