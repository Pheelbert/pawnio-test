# host/

User-space programs that load a module and call its `ioctl_*` functions through
`PawnIOLib.dll`. Two equivalent hosts:

- **`csharp/`** — a small .NET 8 console app (primary). Clean P/Invoke bindings
  in [`PawnIO.cs`](csharp/PawnIO.cs), a CLI in [`Program.cs`](csharp/Program.cs).
- **`python/`** — a single-file `ctypes` wrapper, no build required.

Both need **Windows**, the **PawnIO driver installed**
(`../scripts/fetch-pawnio.ps1`), and an **elevated** prompt.

## C#

```powershell
dotnet run --project csharp -- version
dotnet run --project csharp -- cpuid   ..\build\cpuid.amx
dotnet run --project csharp -- msr     ..\build\msr.amx 0x10
dotnet run --project csharp -- run     ..\build\echo.amx ioctl_add 1 2 3
```

## Python

```powershell
python python\pawnio.py version
python python\pawnio.py cpuid ..\build\cpuid.amx
python python\pawnio.py run   ..\build\echo.amx ioctl_add 1 2 3
```

Both accept a `.amx` (your own build, unrestricted driver) or a signed `.bin`
(official module, signed driver) — they wrap the blob correctly either way. See
[`../docs/04-userspace-api.md`](../docs/04-userspace-api.md).
