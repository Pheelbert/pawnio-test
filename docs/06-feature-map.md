# 6. Feature map — "I want to do X"

A task-oriented index into PawnIO's capabilities. Each row links the goal to the
native(s) you'd use, a local example, and the official module that does it for
real hardware.

| I want to… | Native(s) | Local example | Official module |
|---|---|---|---|
| Print debug output | `debug_print` | every module | all |
| Detect arch / CPU count | `get_arch`, `cpu_count` | `hello.p`, `sysinfo.p` | many |
| Read CPU vendor / brand / features | `cpuid`, `get_cpu_fms` | `cpuid.p`, `sysinfo.p` | (used widely) |
| Read a CPU temperature / power MSR | `msr_read` (+ affinity) | `msr.p` | `IntelMSR.p`, `AMDFamily17.p`, `ZhaoxinMSR.p` |
| Read a per-core counter (APERF/MPERF/PMC) | `cpu_set_affinity` + `msr_read`/`readpmc` | `msr.p` (`ioctl_read_msr_on`) | `IntelMSR.p` |
| Change a tuning/OC MSR | `msr_write` 🔴 | — (writes intentionally omitted) | `IntelMSR.p` (whitelisted writes) |
| Talk to a Super-I/O / EC chip (fans, temps) | `io_in_*`, `io_out_*` | `portio.p` | `LpcIO.p`, `IsaBridgeEC.p`, `LpcACPIEC.p` |
| Read the RTC / CMOS | `io_out_byte`+`io_in_byte` | `portio.p` (`ioctl_rtc_time`) | — |
| Enumerate/read a PCI device | `pci_config_read_*` | — (see docs) | `SmbusPIIX4.p`, `SmbusI801.p` |
| Access a device's MMIO registers | `io_space_map` + `virtual_*` | — (see docs) | `IntelMCHBAR.p`, `SmbusIntelSkylakeIMC.p` |
| Read/write physical memory | `physical_read/write_*` 🔴 | — | (advanced modules) |
| Read an SMBus/I²C sensor | ports or MMIO, per chipset | — | `SmbusI801.p`, `SmbusNCT6793.p` |
| Query Dell laptop fan/thermal | `query_dell_smm` | — | `DellSMM.p` |
| Get a hardware random number | `rdrand`, `rdseed` | `sysinfo.p` | — |
| Time something precisely | `rdtsc`, `rdtscp` | `sysinfo.p` | — |
| Call an arbitrary kernel function | `get_proc_address` + `invoke` 🔴 | — (see `extra.inc` `microsleep2`) | (rare) |
| Read AMD SMU / RyzenSMU registers | MMIO + mailbox | — | `RyzenSMU.p` |

🔴 = can crash or damage hardware; understand it fully first.

## Study path for going deep

1. **Warm up (safe, universal):** `cpuid.p` → `sysinfo.p`. Pure reads, results
   you can verify against `wmic`/CPU-Z.
2. **Real hardware registers:** `msr.p`. Learn affinity and whitelisting — the
   two ideas behind every serious module.
3. **Buses & chips:** read the official `IntelMSR.p`, then `LpcIO.p`
   (port I/O to a Super-I/O chip), then `SmbusI801.p` (PCI + MMIO + a protocol).
   These are compact and show the natives used the way real tools use them.
4. **Write your own:** copy `hello.p`, add an `ioctl_` that reads a register you
   care about on your board, build with `scripts\build.ps1`, and call it from the
   host. Whitelist aggressively.

## Where the official modules live

[github.com/namazso/PawnIO.Modules](https://github.com/namazso/PawnIO.Modules) —
the `.p` sources are short and well worth reading. Signed `.bin` builds ship in
that repo's Releases; `scripts/fetch-pawnio.ps1 -Modules` downloads them for you.
