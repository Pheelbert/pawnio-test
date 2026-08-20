//  echo.p — input/output buffer mechanics.
//
//  What you learn here:
//    * DEFINE_IOCTL_SIZED  — fixed input/output cell counts (validated for you)
//    * DEFINE_IOCTL         — dynamic sizes; YOU validate in_size / out_size
//    * moving data between the in[] and out[] cell arrays
//
//  A "cell" is one 64-bit value (the module is compiled with -C64). The same
//  cells appear on the user-space side as ULONG64 in the input/output arrays
//  passed to pawnio_execute().
//
//  SPDX-License-Identifier: 0BSD

#include <pawnio.inc>

NTSTATUS:main() {
    // Touch two natives so the loader is happy (a single-native module can trip
    // a compiler/interpreter edge case, per the official Echo module).
    new CPUArch:arch = get_arch();
    debug_print(''[echo] loaded, arch=%d'', _:arch);
    return STATUS_SUCCESS;
}

// Bitwise NOT of one cell (this is the canonical official "Echo" operation).
//   in[0]  -> value
//   out[0] <- ~value
DEFINE_IOCTL_SIZED(ioctl_not, 1, 1) {
    out[0] = ~in[0];
    return STATUS_SUCCESS;
}

// Add two cells.
//   in[0], in[1] -> operands
//   out[0]       <- in[0] + in[1]
DEFINE_IOCTL_SIZED(ioctl_add, 2, 1) {
    out[0] = in[0] + in[1];
    return STATUS_SUCCESS;
}

// Dynamic-size echo. DEFINE_IOCTL (no sizes) accepts any in_size/out_size, so
// the handler is responsible for staying in bounds. We copy as many cells as
// fit in BOTH buffers; the driver returns out_size cells to the caller.
DEFINE_IOCTL(ioctl_echo) {
    new n = min(in_size, out_size);
    for (new i = 0; i < n; i++)
        out[i] = in[i];
    debug_print(''[echo] copied %d cells'', n);
    return STATUS_SUCCESS;
}
