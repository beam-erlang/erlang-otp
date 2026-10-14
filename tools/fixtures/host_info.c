/* SPDX-License-Identifier: Apache-2.0 */
#include <beam/beam.h>
#include <stdio.h>
#include <string.h>
#include "sdk_selection.h"

int main(void)
{
    beam_host_info info = { .struct_size = sizeof(info) };
    beam_error error = {0};
    if (strcmp(beam_build_id(), OTP_SDK_BUILD_ID) ||
        beam_query_host(&info, &error) != BEAM_OK) {
        fprintf(stderr, "Selected static SDK host query failed: %s\n", error.message);
        return 1;
    }
    printf("{\"configured\":%u,\"online\":%u,\"available\":%u,\"quota\":%u}\n",
           info.configured_cpus, info.online_cpus,
           info.available_cpus, info.quota_cpus);
    return 0;
}
