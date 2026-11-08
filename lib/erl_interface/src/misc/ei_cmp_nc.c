/*
 * %CopyrightBegin%
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright Ericsson AB 2020-2025. All Rights Reserved.
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
 *
 */

#include <string.h>
#include "eidef.h"

/*
 * Comparison of node container types (pid, port, ref). Comparison
 * done the same way as ERTS compare them. In ref and port case,
 * node info is compared before other data, and in pid case node
 * info is compared after other data.
 */


int
ei_cmp_refs(erlang_ref *a, erlang_ref *b)
{
    BeamEtfRef left, right;
    ei_etf_ref_to(&left, a); ei_etf_ref_to(&right, b);
    return beam_etf_embed_cmp_refs(&left, &right);
}

int
ei_cmp_pids(erlang_pid *a, erlang_pid *b)
{
    BeamEtfPid left, right;
    ei_etf_pid_to(&left, a); ei_etf_pid_to(&right, b);
    return beam_etf_embed_cmp_pids(&left, &right);
}

int
ei_cmp_ports(erlang_port *a, erlang_port *b)
{
    BeamEtfPort left, right;
    ei_etf_port_to(&left, a); ei_etf_port_to(&right, b);
    return beam_etf_embed_cmp_ports(&left, &right);
}
