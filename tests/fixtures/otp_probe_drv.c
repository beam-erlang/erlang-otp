/* SPDX-License-Identifier: Apache-2.0 */
#include <erl_driver.h>

static ErlDrvData start(ErlDrvPort port, char *command)
{
    (void)command;
    return (ErlDrvData)port;
}

static void output(ErlDrvData data, char *bytes, ErlDrvSizeT size)
{
    driver_output((ErlDrvPort)data, bytes, size);
}

static ErlDrvEntry entry = {
    .start = start,
    .output = output,
    .driver_name = "otp_probe_drv",
    .extended_marker = ERL_DRV_EXTENDED_MARKER,
    .major_version = ERL_DRV_EXTENDED_MAJOR_VERSION,
    .minor_version = ERL_DRV_EXTENDED_MINOR_VERSION,
    .driver_flags = ERL_DRV_FLAG_USE_PORT_LOCKING
};

DRIVER_INIT(otp_probe_drv)
{
    return &entry;
}
