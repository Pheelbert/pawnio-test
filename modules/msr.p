//  msr.p — read Model-Specific Registers (MSRs), the safe way.
//
//  What you learn here:
//    * the msr_read(index, &value) native
//    * pinning execution to one logical CPU with cpu_set_affinity /
//      cpu_restore_affinity (MSRs are per-core!)
//    * WHITELISTING: a real module never exposes "read any MSR" to user space,
//      because some MSRs fault (#GP) and others leak secrets. It exposes only
//      the specific registers it needs. This is exactly how the official
//      IntelMSR / AMDMSR modules are written.
//
//  SPDX-License-Identifier: 0BSD

#include <pawnio.inc>

// A few registers that exist on essentially all modern x86-64 parts and are
// safe to read. (Intel and AMD share many architectural MSR indices.)
#define IA32_TIME_STAMP_COUNTER (0x10)
#define IA32_MPERF              (0xE7)   // actual performance clock counter
#define IA32_APERF              (0xE8)   // actual performance frequency counter
#define IA32_MISC_ENABLE        (0x1A0)  // misc feature enables

// Returns 1 if the MSR index is one we allow reading, else 0.
stock allow_read(msr) {
    return msr == IA32_TIME_STAMP_COUNTER
        || msr == IA32_MPERF
        || msr == IA32_APERF
        || msr == IA32_MISC_ENABLE;
}

NTSTATUS:main() {
    new CPUArch:arch = get_arch();
    if (arch != ARCH_X64) {
        debug_print(''[msr] not x86-64 (arch=%d), refusing load'', _:arch);
        return STATUS_NOT_SUPPORTED;
    }
    debug_print(''[msr] loaded, %d CPUs'', cpu_count());
    return STATUS_SUCCESS;
}

// Read a whitelisted MSR on whichever CPU the driver happens to run us on.
//   in[0]  = MSR index (must be whitelisted)
//   out[0] = 64-bit MSR value
DEFINE_IOCTL_SIZED(ioctl_read_msr, 1, 1) {
    if (!allow_read(in[0]))
        return STATUS_ACCESS_DENIED;

    new value;
    new NTSTATUS:status = msr_read(in[0], value);
    if (status != STATUS_SUCCESS)
        return status;

    out[0] = value;
    return STATUS_SUCCESS;
}

// Read a whitelisted MSR pinned to a specific logical CPU. Because RDMSR reads
// the register on the *current* core, reading e.g. per-core counters requires
// setting affinity first, then restoring it.
//   in[0]  = MSR index (must be whitelisted)
//   in[1]  = logical CPU index (0 .. cpu_count()-1)
//   out[0] = value
DEFINE_IOCTL_SIZED(ioctl_read_msr_on, 2, 1) {
    if (!allow_read(in[0]))
        return STATUS_ACCESS_DENIED;
    if (in[1] < 0 || in[1] >= cpu_count())
        return STATUS_INVALID_PARAMETER;

    new old[2];
    new NTSTATUS:status = cpu_set_affinity(in[1], old);
    if (status != STATUS_SUCCESS)
        return status;

    new value;
    status = msr_read(in[0], value);

    // Always restore affinity, even if the read failed.
    cpu_restore_affinity(old);

    if (status != STATUS_SUCCESS)
        return status;

    out[0] = value;
    return STATUS_SUCCESS;
}
