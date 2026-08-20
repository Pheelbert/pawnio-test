# 2. Native functions reference

Every function a module can call, taken from the vendored
[`modules/include/native.inc`](../modules/include/native.inc) and
[`extra.inc`](../modules/include/extra.inc). These *are* PawnIO's capabilities —
this is "what is possible."

**Conventions**
- A **cell is 64-bit** (modules compile with `-C64`).
- `&value` means an output parameter (pass a variable; the native writes it).
- Many natives return an `NTSTATUS:` — check it against `STATUS_SUCCESS`.
- Tags you'll see: `VA:` (kernel virtual address), `VAProc:` (function pointer),
  `CPUArch:`, `NTSTATUS:`, `Void:` (no meaningful return).
- 🟢 safe/read-only · 🟡 privileged but usually fine · 🔴 can crash/brick — know
  exactly what you're doing.

---

## Debugging & architecture

| Native | Notes |
|---|---|
| `NTSTATUS:debug_print(const fmt[], ...)` | 🟢 Kernel-debugger print (DebugView/WinDbg). **Integer specifiers only** (`%d %x %c`). The format must be an **unpacked** string — write it `''like this''`. |
| `CPUArch:get_arch()` | 🟢 `ARCH_X64` (1) or `ARCH_A64` (2). |
| `cpu_count()` | 🟢 Logical CPU count. |

## CPU pinning (MSRs & per-core state are per-core!)

| Native | Notes |
|---|---|
| `NTSTATUS:cpu_set_affinity(which, old[2])` | 🟡 Pin the current thread to logical CPU `which`; saves prior affinity into `old`. |
| `NTSTATUS:cpu_restore_affinity(old[2])` | 🟡 Restore affinity saved above. **Always** restore. |

See `modules/msr.p` → `ioctl_read_msr_on` for the set/read/restore pattern.

## Model-specific registers (MSRs)

| Native | Notes |
|---|---|
| `NTSTATUS:msr_read(msr, &value)` | 🟡 `rdmsr` on the current core. |
| `NTSTATUS:msr_write(msr, value)` | 🔴 `wrmsr`. Wrong values can hang/reset the box. |

Reading an undefined MSR raises `#GP`; the native returns a failing NTSTATUS
rather than crashing. **Whitelist** the MSRs you expose (see `modules/msr.p`).

## Timers, counters, RNG

| Native | Notes |
|---|---|
| `rdtsc()` | 🟢 Time-stamp counter. |
| `rdtscp(&pid)` | 🟢 TSC + processor id. |
| `NTSTATUS:readpmc(pmc, value)` | 🟡 Read a performance counter. |
| `rdrand(&v)` | 🟢 64-bit hardware RNG; returns 0/1 for success. |
| `rdseed(&v)` | 🟢 64-bit hardware seed; returns 0/1 for success. |
| `NTSTATUS:microsleep(us)` | 🟢 Sleep microseconds. (`microsleep2` in extra.inc is a busy-wait.) |

## CPUID & control/debug registers

| Native | Notes |
|---|---|
| `Void:cpuid(leaf, subleaf, out[4])` | 🟢 `out` = EAX, EBX, ECX, EDX. The friendliest native to start with. |
| `cr_read(cr)` / `Void:cr_write(cr, value)` | 🟡 / 🔴 Control registers (CR0/CR4/…). Writing is extremely dangerous. |
| `dr_read(dr)` / `Void:dr_write(dr, value)` | 🟡 / 🔴 Debug registers. |
| `NTSTATUS:xcr_read(xcr, &value)` / `xcr_write(xcr, value)` | 🟡 / 🔴 Extended control registers (XCR0…). |
| `mxcsr_read()` / `Void:mxcsr_write(v)` | 🟡 SSE control/status. |

## Physical memory

| Native | Notes |
|---|---|
| `NTSTATUS:physical_read_byte/word/dword/qword(pa, &value)` | 🟡 Read from a physical address (must already be mapped by the kernel). |
| `NTSTATUS:physical_write_byte/word/dword/qword(pa, value)` | 🔴 Write physical memory. Trivially bricks/corrupts if misused. |

## MMIO & kernel virtual memory

| Native | Notes |
|---|---|
| `VA:io_space_map(pa, size)` | 🟡 Map an MMIO physical range to a VA (0 on failure). **Must be unmapped.** |
| `Void:io_space_unmap(VA:va, size)` | 🟡 Unmap it (do this in `unload()` if mapped in `main()`). |
| `NTSTATUS:virtual_read_byte/word/dword/qword(VA:va, &value)` | 🟡 Read kernel VA (e.g. a mapped MMIO region). |
| `NTSTATUS:virtual_write_byte/word/dword/qword(VA:va, value)` | 🔴 Write kernel VA. |
| `VA:virtual_alloc(size)` | 🟡 Allocate non-paged memory (0 on OOM). **Must be freed.** |
| `virtual_free(VA:va)` | 🟡 Free a `virtual_alloc`. |

`native.inc` defines `VA:` pointer arithmetic and `const VA:NULL`, so you can do
`va + 0x10`, `va2 - va1`, etc.

## I/O ports (legacy x86)

| Native | Notes |
|---|---|
| `io_in_byte/word/dword(port)` | 🟡 `in` instruction. Reading is usually safe. |
| `io_out_byte/word/dword(port, value)` | 🔴 `out` instruction. Writing an unknown port can hang/reset hardware. |

Example: `modules/portio.p` reads the CMOS/RTC via ports `0x70`/`0x71`.

## PCI configuration space

| Native | Notes |
|---|---|
| `NTSTATUS:pci_config_read_byte/word/dword/qword(bus, device, function, offset, &value)` | 🟡 Read PCI config (vendor/device id, BARs, …). |
| `NTSTATUS:pci_config_write_byte/word/dword/qword(bus, device, function, offset, value)` | 🔴 Write PCI config. |

## Advanced kernel plumbing

| Native | Notes |
|---|---|
| `VAProc:get_proc_address(name[])` | 🔴 Resolve a kernel export by name (0 if not found). `name` is an **unpacked** string. |
| `NTSTATUS:invoke(VAProc:address, &retval, a0=0 … a15=0)` | 🔴 Call an arbitrary kernel function pointer with up to 16 args. This is the "escape hatch" and the sharpest edge in the whole API. |
| `bool:query_dell_smm(const in[6], out[6])` | 🟡 Dell SMM BIOS call (fan/thermal on Dell laptops). |
| `Void:interrupts_disable()` / `interrupts_enable()` | 🔴 Raise/lower IRQL to the max — keep the critical section tiny. |
| `Void:invlpg(va)` / `Void:invpcid(type, VA:descriptor)` | 🔴 TLB invalidation. |
| `Void:lidt/sidt/lgdt/sgdt(...)` | 🔴 Load/store IDT/GDT. |
| `Void:stac()` / `clac()` | 🔴 Toggle SMAP's AC flag. |
| `Void:wbinvd()` | 🔴 Write back + invalidate caches. |
| `Void:halt()` / `ud2()` / `int3()` / `int2c()` | 🔴 Raw instructions (mostly for experiments/debugging). |

## Helpers from `extra.inc` / `util.inc` (Pawn, not natives)

Handy building blocks so you don't reinvent them:

- `get_cpu_vendor()` → `CpuVendor:` (compares CPUID vendor via FNV hash)
- `get_cpu_fms()` and `cpu_fms_family/model/stepping(fms)`
- `get_tick_count()` (reads `KUSER_SHARED_DATA`)
- `BIT(n)`, `SIGN_EXTEND8/16/32(x)`, `CHAR4_CONST('A','B','C','D')`
- `copy()`, `pack_bytes_le()`, `unpack_bytes_le()`, `get_byte_le()`, `set_byte_le()`
- `min()`, `max()`, `clamp()`, `div_ceil()`, `div_floor()`
- `fnv1ab/aw/ad/aq(...)` FNV-1a hashing

---

### How to discover this yourself

Open [`native.inc`](../modules/include/native.inc) — it's the source of truth,
with a doc comment on every function. The official modules in
[namazso/PawnIO.Modules](https://github.com/namazso/PawnIO.Modules) are the best
real-world examples of each native in anger (e.g. `LpcIO.p` for port I/O,
`SmbusI801.p` for PCI + MMIO, `IntelMSR.p` for MSR whitelisting).
