# 4. User-space API (PawnIOLib)

User programs talk to PawnIO through **PawnIOLib.dll** (installed to
`C:\Program Files\PawnIO`). It wraps the raw `DeviceIoControl` protocol in five
functions. This repo binds them from C# ([`host/csharp/PawnIO.cs`](../host/csharp/PawnIO.cs))
and Python ([`host/python/pawnio.py`](../host/python/pawnio.py)).

## The five functions

```c
HRESULT pawnio_version(ULONG* version);
HRESULT pawnio_open(HANDLE* handle);
HRESULT pawnio_load(HANDLE handle, const void* blob, size_t size);
HRESULT pawnio_execute(HANDLE handle, const char* name,
                       const ULONG64* in,  size_t in_count,
                       ULONG64*       out, size_t out_count,
                       size_t*        return_size);
HRESULT pawnio_close(HANDLE handle);
```

- Everything returns an **HRESULT**; `S_OK == 0`, negative means failure. Both
  hosts throw/raise on failure with the hex code.
- `in`/`out` are arrays of **64-bit cells** (`ULONG64`) — the same cells your
  module sees as `in[]`/`out[]`.
- `name` is the exported handler name, e.g. `"ioctl_read_msr"` (≤ 31 chars, no
  auto-prefixing — pass it exactly).
- `return_size` comes back in **bytes**; divide by 8 for the cell count.

Typical lifecycle: `open` → `load` (once) → `execute` (many times) → `close`.

## The blob format (important!)

`pawnio_load` does **not** take a raw `.amx`. It takes a **blob**:

```
[ 4-byte little-endian signature size ][ signature bytes ][ amx bytes ]
```

- **Official signed `.bin`** modules (from the PawnIO.Modules releases) are
  *already* blobs — signature size > 0, real signature. Pass their bytes as-is.
- **Your own `.amx`** has no signature. Wrap it with a **zero-length signature**:
  four `0x00` bytes followed by the `.amx`. That loads only on the
  **unrestricted** driver (which skips signature checks).

Both hosts do this for you (`ToBlob` / `to_blob`): a `.amx` path is wrapped with
a zero signature, a `.bin` path is passed through unchanged. This mirrors exactly
what the official `PawnIOUtil test` command does.

## C# usage

```csharp
using PawnIoLab;

Console.WriteLine($"PawnIO version {PawnIoModule.Version():X}");

using var m = PawnIoModule.LoadFile(@"build\msr.amx");     // open + load
ulong[] o = m.Execute("ioctl_read_msr", new ulong[] { 0x10 }, outCount: 1);
Console.WriteLine($"TSC MSR = 0x{o[0]:X}");
// Dispose() -> pawnio_close
```

Notes from the binding:
- Size parameters are `size_t` → marshalled as **`nuint`**.
- The host installs a `NativeLibrary` resolver so `PawnIOLib.dll` is found in
  `C:\Program Files\PawnIO` even if it isn't next to the exe or on PATH.
- The project targets **x64** because PawnIOLib.dll is native 64-bit.

## Python usage (no build)

```python
from pawnio import PawnIO
with PawnIO().load_file(r"build\cpuid.amx") as m:
    regs = m.execute("ioctl_cpuid", [1, 0], 4)   # leaf 1, subleaf 0
    print(hex(regs[0]))
```

`ctypes` argtypes/restypes are set so pointers and `size_t` marshal correctly;
`WinDLL` is loaded lazily and searched in `Program Files\PawnIO`.

## The generic runner (like PawnIOUtil)

Both hosts expose a `run` command that mirrors the official `PawnIOUtil`
interactive syntax — `function outCount arg1 arg2 …`:

```powershell
dotnet run --project host\csharp -- run build\echo.amx ioctl_add 1 2 3
#   out[0] = 0x0000000000000005  (5)

python host\python\pawnio.py run build\echo.amx ioctl_add 1 2 3
```

## Error decoding

Common HRESULTs you'll meet:

| HRESULT | Meaning / fix |
|---|---|
| `0x80070005` | `E_ACCESSDENIED` — run elevated (Administrator). |
| `0x8007007E` | `PawnIOLib.dll` not found — install PawnIO. |
| `0xC0000xxx` wrapped | An `NTSTATUS` from the driver/module (e.g. `0xC0000022` access denied → your whitelist rejected the request; `0xC000000D` invalid parameter → wrong `in`/`out` counts). |
| load fails on the signed driver | You tried to load an unsigned `.amx`. Use a signed `.bin`, or the unrestricted edition. See [signing & editions](05-signing-and-editions.md). |

## Requirements

- **Windows**, with the PawnIO driver installed (`scripts/fetch-pawnio.ps1`).
- **Administrator** — talking to a kernel driver is privileged.
- **x64** host process.
