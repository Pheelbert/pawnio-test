//  portio.p — legacy x86 port I/O.  *** ADVANCED / handle with care ***
//
//  What you learn here:
//    * io_out_byte(port, value) and io_in_byte(port)
//    * the classic CMOS/RTC access pattern: write a register index to port
//      0x70, then read/write its value at port 0x71
//
//  Why this is the "danger" example:
//    Port I/O talks straight to hardware with no abstraction. READING CMOS (as
//    we do here) is safe and is a great way to see port I/O work. WRITING to
//    arbitrary ports can hang, reset, or corrupt a machine — never poke ports
//    you don't understand. This module only issues reads from the RTC.
//
//  SPDX-License-Identifier: 0BSD

#include <pawnio.inc>

#define CMOS_INDEX_PORT (0x70)   // write the register number here
#define CMOS_DATA_PORT  (0x71)   // then read/write the register value here

NTSTATUS:main() {
    new CPUArch:arch = get_arch();
    if (arch != ARCH_X64) {
        debug_print(''[portio] not x86-64 (arch=%d), refusing load'', _:arch);
        return STATUS_NOT_SUPPORTED;
    }
    debug_print(''[portio] loaded'');
    return STATUS_SUCCESS;
}

// Read a single CMOS register.
//   in[0]  = register index (0x00 .. 0x7F; we mask to 7 bits)
//   out[0] = the byte read (0..255)
DEFINE_IOCTL_SIZED(ioctl_cmos_read, 1, 1) {
    new reg = in[0] & 0x7F;
    io_out_byte(CMOS_INDEX_PORT, reg);
    out[0] = io_in_byte(CMOS_DATA_PORT) & 0xFF;
    return STATUS_SUCCESS;
}

// Read the RTC wall-clock straight from CMOS. Most firmware stores these as BCD
// (e.g. 0x59 means 59), so the host decodes them.
//   out[0] = seconds (reg 0x00)
//   out[1] = minutes (reg 0x02)
//   out[2] = hours   (reg 0x04)
DEFINE_IOCTL_SIZED(ioctl_rtc_time, 0, 3) {
    io_out_byte(CMOS_INDEX_PORT, 0x00);
    out[0] = io_in_byte(CMOS_DATA_PORT) & 0xFF;

    io_out_byte(CMOS_INDEX_PORT, 0x02);
    out[1] = io_in_byte(CMOS_DATA_PORT) & 0xFF;

    io_out_byte(CMOS_INDEX_PORT, 0x04);
    out[2] = io_in_byte(CMOS_DATA_PORT) & 0xFF;

    return STATUS_SUCCESS;
}
