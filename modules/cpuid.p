//  cpuid.p — read CPUID leaves. Safe, read-only, works on any x86-64 machine.
//
//  What you learn here:
//    * the cpuid(leaf, subleaf, out[4]) native (out = EAX, EBX, ECX, EDX)
//    * turning register dwords into ASCII strings (vendor / brand)
//    * the get_cpu_fms() / get_cpu_vendor() helpers from extra.inc
//
//  CPUID is the friendliest native to start with: it cannot damage anything and
//  returns the same data as the user-mode __cpuid intrinsic, so results are easy
//  to sanity-check.
//
//  SPDX-License-Identifier: 0BSD

#include <pawnio.inc>

NTSTATUS:main() {
    // CPUID is x86-only. Refuse to load on ARM64 so callers get a clear error.
    new CPUArch:arch = get_arch();
    if (arch != ARCH_X64) {
        debug_print(''[cpuid] not x86-64 (arch=%d), refusing load'', _:arch);
        return STATUS_NOT_SUPPORTED;
    }
    debug_print(''[cpuid] loaded'');
    return STATUS_SUCCESS;
}

// Raw CPUID passthrough.
//   in[0] = leaf    (EAX)
//   in[1] = subleaf (ECX)
//   out[0..3] = EAX, EBX, ECX, EDX  (only the low 32 bits are meaningful)
DEFINE_IOCTL_SIZED(ioctl_cpuid, 2, 4) {
    new regs[4];
    cpuid(in[0], in[1], regs);
    out[0] = regs[0];
    out[1] = regs[1];
    out[2] = regs[2];
    out[3] = regs[3];
    return STATUS_SUCCESS;
}

// Vendor id + family/model/stepping.
// The 12-char vendor id from leaf 0 is returned as EBX, EDX, ECX (that is the
// order the four-char chunks belong in — e.g. "Genu" "ineI" "ntel").
//   out[0] = EBX, out[1] = EDX, out[2] = ECX
//   out[3] = family<<16 | model<<8 | stepping   (see get_cpu_fms in extra.inc)
DEFINE_IOCTL_SIZED(ioctl_vendor, 0, 4) {
    new regs[4];
    cpuid(0, 0, regs);
    out[0] = regs[1]; // EBX
    out[1] = regs[3]; // EDX
    out[2] = regs[2]; // ECX
    out[3] = get_cpu_fms();
    return STATUS_SUCCESS;
}

// Processor brand string (48 ASCII chars) from extended leaves 0x80000002..4.
// Each leaf contributes EAX, EBX, ECX, EDX = 16 chars.
//   out[0..11] = the 12 register dwords, in order.
// The host reads the low 32 bits of each cell as 4 little-endian ASCII bytes.
DEFINE_IOCTL_SIZED(ioctl_brand, 0, 12) {
    new regs[4];
    for (new i = 0; i < 3; i++) {
        cpuid(0x80000002 + i, 0, regs);
        out[i * 4 + 0] = regs[0];
        out[i * 4 + 1] = regs[1];
        out[i * 4 + 2] = regs[2];
        out[i * 4 + 3] = regs[3];
    }
    return STATUS_SUCCESS;
}
