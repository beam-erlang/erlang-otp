/* SPDX-License-Identifier: Apache-2.0 */
#ifndef OTP_HOST_INPUTS_H
#define OTP_HOST_INPUTS_H
#include <beam/beam.h>

/* Product-private owned inputs. Acquisition performs no VM operations. */
typedef struct otp_host_inputs {
    beam_composition_options composition;
    beam_entry entry;
    beam_bytes context;
    void *storage;
} otp_host_inputs;

/* Initialize storage to NULL. Failure leaves the complete output unchanged.
 * Root is absolute UTF-8; arguments are literal OTP startup argument bytes. */
beam_status otp_host_acquire(const char *root, size_t argc,
                             const char *const *argv, otp_host_inputs *output,
                             beam_error *error);
/* Safe repeatedly, including after failed acquisition. Clear all output fields. */
void otp_host_release(otp_host_inputs *inputs);
#endif
