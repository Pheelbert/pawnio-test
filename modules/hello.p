//  hello.p — the smallest useful PawnIO module.
//
//  What you learn here:
//    * the module lifecycle: main() runs at load, unload() runs at unload
//    * debug_print(), which writes to the kernel debugger (DebugView / WinDbg)
//    * a fixed-size IOCTL that user space can call by name ("ioctl_hello")
//
//  Every PawnIO module is a single .p file that #includes <pawnio.inc>.
//
//  SPDX-License-Identifier: 0BSD

#include <pawnio.inc>

// main() is called once, when the driver loads this module's bytecode.
// Returning anything other than STATUS_SUCCESS aborts the load.
NTSTATUS:main() {
    // NOTE: PawnIO's debug_print only understands INTEGER format specifiers
    // (%d, %x, %c). Format strings are UNPACKED strings, written ''like this''
    // (two single quotes) rather than "like this" (which is a packed string).
    debug_print(''[hello] loaded: arch=%d, cpu_count=%d'', _:get_arch(), cpu_count());
    return STATUS_SUCCESS;
}

// unload() is optional; it runs when the module is unloaded. Use it to release
// anything main()/IOCTLs allocated (io_space_map, virtual_alloc, ...).
public NTSTATUS:unload() {
    debug_print(''[hello] unloaded'');
    return STATUS_SUCCESS;
}

// DEFINE_IOCTL_SIZED(name, in_cells, out_cells) declares a function that user
// space can invoke through pawnio_execute(). The name MUST start with "ioctl_".
//
// The driver hands the handler four things:
//     in[]      input cells copied from user space   (each cell is 64-bit)
//     in_size   number of input cells                (validated == in_cells)
//     out[]     output cells copied back to user space
//     out_size  number of output cells               (validated == out_cells)
//
// If the caller's sizes don't match, the macro returns STATUS_INVALID_PARAMETER
// before your code runs, so inside the body the sizes are guaranteed.
//
//   in[0]  -> any value you want echoed back
//   out[0] <- architecture (ARCH_X64 = 1, ARCH_A64 = 2)
//   out[1] <- logical CPU count
//   out[2] <- in[0], echoed
DEFINE_IOCTL_SIZED(ioctl_hello, 1, 3) {
    out[0] = _:get_arch();
    out[1] = cpu_count();
    out[2] = in[0];
    debug_print(''[hello] ioctl_hello in[0]=0x%x'', in[0]);
    return STATUS_SUCCESS;
}
