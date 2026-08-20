# pawnio-test — a hands-on PawnIO lab

A learning playground for **[PawnIO](https://pawnio.eu/)**: write tiny kernel
"modules" in the Pawn language, compile them to bytecode, and run them through
the **already-signed** PawnIO driver from a normal user-mode program.

Everything here is small, heavily commented, and **verified to compile with the
real Pawn compiler**. You do not build or sign a kernel driver — you fetch the
signed one and talk to it.

> ⚠️ **PawnIO gives real, unrestricted kernel access** (MSRs, physical memory,
> I/O ports, PCI config…). That is the whole point, and also the whole danger.
> Read [`docs/05-signing-and-editions.md`](docs/05-signing-and-editions.md) and
> the safety notes before running anything. Use a machine you can afford to
> crash.

---

## What is PawnIO, in one picture

PawnIO is a **single signed kernel driver that runs sandboxed [Pawn](https://www.compuphase.com/pawn/pawn.htm)
bytecode.** Instead of writing and signing your own `.sys` (hard, and a security
risk), you write a small *module*, compile it to an `.amx`, and load it into the
driver. The driver exposes low-level "native" functions to your module and lets
user space call your module's exported `ioctl_*` functions by name.

```
  your user-mode app  ──pawnio_execute("ioctl_read_msr", …)──►  PawnIOLib.dll
        (C# / Python / …)                                            │
                                                                DeviceIoControl
                                                                     ▼
  ┌───────────────────────────── PawnIO.sys (signed) ─────────────────────────┐
  │   64-bit Pawn VM (AMX)                                                     │
  │      runs YOUR module's bytecode  ──calls──►  natives: msr_read, cpuid,    │
  │                                               physical_read, io_in_byte,   │
  │      returns cells to user space              pci_config_read, …          │
  └───────────────────────────────────────────────────────────────────────────┘
```

This is why projects like **LibreHardwareMonitor** and **FanControl** use it:
one audited, signed driver replaces a zoo of unsafe "BYOVD" hardware drivers.
See [`docs/01-architecture.md`](docs/01-architecture.md) for the full story.

---

## Two ways to use it (pick your lane)

PawnIO ships in two editions. **This distinction is the single most important
thing to understand** — it decides whether you can run *your own* modules.

| | **Signed edition** (default) | **Unrestricted edition** |
|---|---|---|
| Driver signature | Officially signed; loads with Secure Boot / HVCI | Needs **Windows test signing** + reboot |
| What modules load | **Only** modules signed by the PawnIO author | **Any** module you compile |
| Use it to… | Run the official signed `*.bin` modules | Write & run **your own** `.amx` |
| This repo's role | Call official modules from your own host | Everything in `modules/` |

- **Lane A — "just work with the signed driver."** Install the signed edition,
  download the official signed modules, and drive them from the host in
  `host/`. No test signing, works on a normal machine.
- **Lane B — "learn to author modules."** Install the unrestricted edition
  (test signing), compile the modules in `modules/`, and run them. This is the
  deep-learning path.

Full explanation: [`docs/05-signing-and-editions.md`](docs/05-signing-and-editions.md).

---

## Quickstart

### 0. Get the tools
- **Windows** to actually load the driver (PawnIO is a Windows kernel driver).
- **.NET 8 SDK** for the C# host (or just use the Python host — no build).
- A **Pawn compiler** only if you want to build modules locally; CI builds
  them for you, or place `pawncc.exe` in `.tools\`.

### Lane A — signed driver + official modules (no test signing)

```powershell
# From an elevated PowerShell:
scripts\fetch-pawnio.ps1 -Modules      # installs signed driver + official *.bin

# Round-trip a value through the official "Echo" module (bitwise NOT):
dotnet run --project host\csharp -- run official-modules\Echo.bin ioctl_not 1 0x0f0f
#   out[0] = 0xFFFFFFFFFFFFF0F0
```

### Lane B — your own modules (unrestricted driver)

```powershell
scripts\fetch-pawnio.ps1 -Unrestricted   # installs dev driver (enables test signing)

scripts\build.ps1                         # -> build\*.amx

# Read CPUID the deep way — module does cpuid, host decodes the strings:
dotnet run --project host\csharp -- cpuid   build\cpuid.amx
dotnet run --project host\csharp -- sysinfo build\sysinfo.amx
dotnet run --project host\csharp -- hello   build\hello.amx 0xCAFE
```

No .NET? The Python host is identical and needs no build:

```powershell
python host\python\pawnio.py cpuid build\cpuid.amx
```

---

## The example modules

Each is a self-contained `.p` in [`modules/`](modules/), ordered from trivial to
advanced. They only use **safe, universal** operations.

| Module | Teaches | Key natives |
|---|---|---|
| [`hello.p`](modules/hello.p) | lifecycle, `debug_print`, a fixed IOCTL | `get_arch`, `cpu_count` |
| [`echo.p`](modules/echo.p) | fixed vs dynamic IOCTLs, in/out cells | — |
| [`cpuid.p`](modules/cpuid.p) | reading CPUID, decoding strings | `cpuid`, `get_cpu_fms` |
| [`msr.p`](modules/msr.p) | MSRs, per-core affinity, **whitelisting** | `msr_read`, `cpu_set_affinity` |
| [`sysinfo.p`](modules/sysinfo.p) | composing many natives in one call | `cpuid`, `rdtsc`, `rdrand` |
| [`portio.p`](modules/portio.p) | legacy port I/O (**advanced**) | `io_out_byte`, `io_in_byte` |

The full catalogue of what PawnIO can do — every native, with a safe example —
is in [`docs/02-native-functions.md`](docs/02-native-functions.md).

---

## Repo layout

```
modules/            your Pawn modules (.p) + vendored PawnIO headers (include/)
host/csharp/        C# console host over PawnIOLib.dll  (primary)
host/python/        ctypes host — zero build
scripts/            build.ps1 / fetch-pawnio.ps1 / run-demo.ps1
docs/               deep-dive guides (start with 01-architecture.md)
.github/workflows/  CI: compiles modules on every push, uploads artifacts
```

## Documentation

1. [Architecture](docs/01-architecture.md) — driver, VM, IOCTL protocol, security model
2. [Native functions reference](docs/02-native-functions.md) — everything a module can call
3. [Writing modules](docs/03-writing-modules.md) — anatomy, macros, cells, gotchas
4. [User-space API](docs/04-userspace-api.md) — PawnIOLib, the blob format, calling by name
5. [Signing & editions](docs/05-signing-and-editions.md) — signed vs unrestricted, test signing
6. [Feature map](docs/06-feature-map.md) — "I want to do X" → which native + example

## Credits

PawnIO, the driver, PawnIOLib, the module headers, and the `pawncc` build are all
by **[namazso](https://namazso.eu/)** and contributors. This repo is an
independent, unofficial learning project and bundles only the 0BSD-licensed
headers (see [`modules/include/NOTICE`](modules/include/NOTICE)); everything else
is downloaded from official sources at build/run time.
