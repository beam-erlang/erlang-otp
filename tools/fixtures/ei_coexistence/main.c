/* SPDX-License-Identifier: Apache-2.0 */
#include <beam/beam.h>
#include <beam/beam_etf.h>
#include <ei.h>
#include <stdio.h>
int main(void)
{
    BeamEtfBuffer modern;
    ei_x_buff compatibility;
    beam_host_info info = {0};
    info.struct_size = sizeof info;
    long value;
    int index = 0;
    if (beam_etf_x_new(&modern) || ei_x_new(&compatibility) ||
        beam_etf_x_encode_long(&modern,42) ||
        ei_decode_long(modern.buff,&index,&value) || value != 42 || index != modern.index)
        return 1;
    index = 0;
    if (ei_x_encode_long(&compatibility,43) ||
        beam_etf_decode_long(compatibility.buff,&index,&value) || value != 43 || index != compatibility.index ||
        beam_query_host(&info,NULL) != BEAM_OK)
        return 2;
    if (beam_etf_x_free(&modern) || ei_x_free(&compatibility)) return 3;
    puts("ei_runtime_coexistence_passed");
    return 0;
}
