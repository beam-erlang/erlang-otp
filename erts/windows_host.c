/* SPDX-License-Identifier: Apache-2.0 */
/* Keep the installed SDK's process-owning entry in OTP's distribution DLL.
 * BEAM::Runtime supplies the implementation and canonical preload resources. */
#include <beam/beam.h>

int (*const otp_runtime_entry)(int, char **) = beam_main;
int (*const otp_console_wait_entry)(void) = beam_windows_wait_for_console_key;
