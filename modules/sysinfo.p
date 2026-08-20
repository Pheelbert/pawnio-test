//  sysinfo.p — one call that dumps a bunch of system facts.
//
//  What you learn here:
//    * composing several natives + helpers into one richer output buffer
//    * rdtsc() (time-stamp counter) and rdrand() (hardware RNG)
//
//  This is the pattern most real modules follow: a single IOCTL gathers a
//  block of related values so user space makes one round-trip instead of many.
//
//  SPDX-License-Identifier: 0BSD

#include <pawnio.inc>

NTSTATUS:main() {
    new CPUArch:arch = get_arch();
    if (arch != ARCH_X64) {
        debug_print(''[sysinfo] not x86-64 (arch=%d), refusing load'', _:arch);
        return STATUS_NOT_SUPPORTED;
    }
    debug_print(''[sysinfo] loaded'');
    return STATUS_SUCCESS;
}

// Gather everything into one 8-cell block.
//   out[0] = architecture (1 = x64, 2 = arm64)
//   out[1] = logical CPU count
//   out[2] = vendor EBX  ] together, these three cells hold the 12-char
//   out[3] = vendor EDX  ]  vendor id ("GenuineIntel", "AuthenticAMD", ...)
//   out[4] = vendor ECX  ]
//   out[5] = family<<16 | model<<8 | stepping
//   out[6] = TSC sampled with rdtsc()
//   out[7] = a 64-bit RDRAND value (0 if RDRAND is unavailable)
DEFINE_IOCTL_SIZED(ioctl_sysinfo, 0, 8) {
    new regs[4];
    cpuid(0, 0, regs);

    out[0] = _:get_arch();
    out[1] = cpu_count();
    out[2] = regs[1]; // EBX
    out[3] = regs[3]; // EDX
    out[4] = regs[2]; // ECX
    out[5] = get_cpu_fms();
    out[6] = rdtsc();

    new rnd = 0;
    rdrand(rnd);      // returns 0/1 for success; rnd stays 0 if unsupported
    out[7] = rnd;

    return STATUS_SUCCESS;
}
