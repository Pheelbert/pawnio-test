# modules/

PawnIO modules (`.p`) — small, heavily commented, and verified to compile. Read
them in this order: `hello` → `echo` → `cpuid` → `msr` → `sysinfo` → `portio`.

`include/` holds the PawnIO headers, vendored from
[namazso/PawnIO.Modules](https://github.com/namazso/PawnIO.Modules) (0BSD; see
`include/NOTICE`). Refresh with `../scripts/refresh-headers.sh`.

## Build

```bash
../scripts/build.sh            # Linux/macOS/WSL/CI -> ../build/*.amx
# or on Windows:  ..\scripts\build.ps1
```

Each module compiles with the official flags:

```
pawncc <name>.p -iinclude -C64 -;+ -(+ -p
```

See [`../docs/03-writing-modules.md`](../docs/03-writing-modules.md) for the
anatomy, the IOCTL macros, and the gotchas (unpacked `''strings''`, no trailing
`\` in comments, `-p` to block the default prefix).

## Run

The compiled `.amx` are **unsigned** → they load only on the **unrestricted**
driver. Then:

```powershell
dotnet run --project ..\host\csharp -- cpuid ..\build\cpuid.amx
```
