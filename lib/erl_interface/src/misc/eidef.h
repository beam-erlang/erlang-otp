/*
 * %CopyrightBegin%
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright Ericsson AB 2002-2026. All Rights Reserved.
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

#ifndef _EIDEF_H
#define _EIDEF_H

/* Common definitions used in ei user interface */

#include "config.h"		/* Central include of config.h */

#include <stddef.h>		/* We want to get definition of NULL */

#include "ei.h"			/* Want the API function declarations */

#define EISMALLBUF 2048

#ifndef HAVE_SOCKLEN_T
typedef int socklen_t;
#endif

#ifdef USE_ISINF_ISNAN		/* simulate finite() */
#  define isfinite(f) (!isinf(f) && !isnan(f))
#  define HAVE_ISFINITE
#elif defined(__GNUC__) && defined(HAVE_FINITE)
/* We use finite in gcc as it emits assembler instead of
   the function call that isfinite emits. The assembler is
   significantly faster. */
#  ifdef isfinite
#     undef isfinite
#  endif
#  define isfinite finite
#  ifndef HAVE_ISFINITE
#    define HAVE_ISFINITE
#  endif
#elif defined(isfinite) && !defined(HAVE_ISFINITE)
#  define HAVE_ISFINITE
#elif !defined(HAVE_ISFINITE) && defined(HAVE_FINITE)
#  define isfinite finite
#  define HAVE_ISFINITE
#endif

/* Taken from https://best.openssf.org/Compiler-Hardening-Guides/Compiler-Options-Hardening-Guide-for-C-and-C++.html#warn-about-implicit-fallthrough-in-switch-statements */
#ifdef __has_attribute
#  if __has_attribute(__fallthrough__)
#    define EI_FALLTHROUGH()                    __attribute__((__fallthrough__))
#  endif
#endif
#ifndef EI_FALLTHROUGH
# define EI_FALLTHROUGH()                    do {} while (0)  /* fallthrough */
#endif

typedef unsigned char  uint8;	/* FIXME use configure */
typedef unsigned short uint16;
typedef unsigned int   uint32;
typedef signed   char  int8;
typedef signed   short int16;
typedef signed   int   int32;

#ifdef DEBUG
#  include <stdlib.h>
#  define ASSERT(Cnd) ((void) ((Cnd) ? 1 : abort()))
#else
#  define ASSERT(Cnd)
#endif

/* EI_UNDEF can be used to silence false warnings about
 * "variable may be used uninitialized" while keeping the variable
 * marked as undefined by valgrind.
 */
#ifdef VALGRIND
#  define EI_UNDEF(V,I) do {} while(0)
#else
#  define EI_UNDEF(V,I) V = I
#endif


/* Installed-SDK codec adapters. These types are intentionally independent of ei.h. */
#include <beam/sdk/etf.h>
#include <string.h>
static inline void ei_etf_pid_to(BeamEtfPid *d, const erlang_pid *s)
{
    memcpy(d->node, s->node, sizeof d->node);
    d->num = s->num;
    d->serial = s->serial;
    d->creation = s->creation;
}
static inline void ei_etf_pid_from(erlang_pid *d, const BeamEtfPid *s)
{
    memcpy(d->node, s->node, sizeof d->node);
    d->num = s->num;
    d->serial = s->serial;
    d->creation = s->creation;
}
static inline void ei_etf_port_to(BeamEtfPort *d, const erlang_port *s)
{
    memcpy(d->node, s->node, sizeof d->node);
    d->id = s->id;
    d->creation = s->creation;
}
static inline void ei_etf_port_from(erlang_port *d, const BeamEtfPort *s)
{
    memcpy(d->node, s->node, sizeof d->node);
    d->id = s->id;
    d->creation = s->creation;
}
static inline void ei_etf_ref_to(BeamEtfRef *d, const erlang_ref *s)
{
    memcpy(d->node, s->node, sizeof d->node);
    d->len = s->len;
    memcpy(d->n, s->n, sizeof d->n);
    d->creation = s->creation;
}
static inline void ei_etf_ref_from(erlang_ref *d, const BeamEtfRef *s)
{
    memcpy(d->node, s->node, sizeof d->node);
    d->len = s->len;
    memcpy(d->n, s->n, sizeof d->n);
    d->creation = s->creation;
}
static inline void ei_etf_fun_to(BeamEtfFun *d, const erlang_fun *s)
{
    d->arity = s->arity;
    memcpy(d->module, s->module, sizeof d->module);
    if (s->type == EI_FUN_CLOSURE) {
        d->type = BEAM_ETF_FUN_CLOSURE;
        memcpy(d->u.closure.md5, s->u.closure.md5, sizeof d->u.closure.md5);
        d->u.closure.index = s->u.closure.index;
        d->u.closure.old_index = s->u.closure.old_index;
        d->u.closure.uniq = s->u.closure.uniq;
        d->u.closure.n_free_vars = s->u.closure.n_free_vars;
        d->u.closure.free_var_len = s->u.closure.free_var_len;
        d->u.closure.free_vars = s->u.closure.free_vars;
        ei_etf_pid_to(&d->u.closure.pid, &s->u.closure.pid);
    } else if (s->type == EI_FUN_EXPORT) {
        d->type = BEAM_ETF_FUN_EXPORT;
        d->u.exprt.func_allocated = s->u.exprt.func_allocated;
        d->u.exprt.func = s->u.exprt.func;
    } else {
        /* Preserve the original encoder behavior for unknown discriminants. */
        d->type = s->type;
    }
}
static inline void ei_etf_fun_from(erlang_fun *d, const BeamEtfFun *s)
{
    d->arity = s->arity;
    memcpy(d->module, s->module, sizeof d->module);
    if (s->type == BEAM_ETF_FUN_CLOSURE) {
        d->type = EI_FUN_CLOSURE;
        memcpy(d->u.closure.md5, s->u.closure.md5, sizeof d->u.closure.md5);
        d->u.closure.index = s->u.closure.index;
        d->u.closure.old_index = s->u.closure.old_index;
        d->u.closure.uniq = s->u.closure.uniq;
        d->u.closure.n_free_vars = s->u.closure.n_free_vars;
        d->u.closure.free_var_len = s->u.closure.free_var_len;
        d->u.closure.free_vars = s->u.closure.free_vars;
        ei_etf_pid_from(&d->u.closure.pid, &s->u.closure.pid);
    } else {
        d->type = EI_FUN_EXPORT;
        d->u.exprt.func_allocated = s->u.exprt.func_allocated;
        d->u.exprt.func = s->u.exprt.func;
        if (!s->u.exprt.func_allocated && s->u.exprt.func)
            d->u.exprt.func = d->module + (s->u.exprt.func - s->module);
    }
}

#endif /* _EIDEF_H */
