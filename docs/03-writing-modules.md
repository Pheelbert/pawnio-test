# 3. Writing modules

A module is one `.p` file that `#include <pawnio.inc>` and implements a few
functions. Start from `modules/hello.p`; this page explains the machinery.

## Anatomy

```pawn
#include <pawnio.inc>

NTSTATUS:main() {            // runs once at load; return != SUCCESS aborts load
    // validate hardware, allocate/map resources, cache pointers
    return STATUS_SUCCESS;
}

public NTSTATUS:unload() {   // optional; runs at unload — free what main() took
    return STATUS_SUCCESS;
}

DEFINE_IOCTL_SIZED(ioctl_do_thing, 1, 1) {   // callable from user space
    out[0] = in[0] + 1;
    return STATUS_SUCCESS;
}
```

- **`main()`** — initialization. A subtle gotcha: a module whose `main()` calls
  *only one* native can trip a compiler/interpreter edge case, so the official
  `Echo` module deliberately touches two. Our modules call `get_arch()` plus one
  more, which also serves as an architecture check.
- **`unload()`** — cleanup. If you `io_space_map`/`virtual_alloc` in `main()`,
  free it here.
- **`ioctl_*`** — the operations user space can call by name.

## The IOCTL macros

From [`pawnio.inc`](../modules/include/pawnio.inc):

```pawn
// Fixed sizes — the driver validates them before your code runs.
#define DEFINE_IOCTL_SIZED(name, in_cells, out_cells) \
    forward NTSTATUS:name(in[in_cells], in_size, out[out_cells], out_size); \
    public  NTSTATUS:name(in[in_cells], in_size, out[out_cells], out_size) \
        if (((in_cells)!=0 && in_size!=(in_cells)) || ((out_cells)!=0 && out_size!=(out_cells))) \
            return STATUS_INVALID_PARAMETER; \
        else

// Dynamic sizes — you validate in_size / out_size yourself.
#define DEFINE_IOCTL(name) \
    forward NTSTATUS:name(in[...], in_size, out[...], out_size); \
    public  NTSTATUS:name(in[...], in_size, out[...], out_size)
```

Inside a handler you always have:

| Name | Meaning |
|---|---|
| `in[]` | input cells from user space |
| `in_size` | number of input cells |
| `out[]` | output cells to return |
| `out_size` | number of output cells |

Rules of thumb:
- The name **must start with `ioctl_`** (also the string user space passes to
  `pawnio_execute`), and stay ≤ 31 characters.
- Prefer `DEFINE_IOCTL_SIZED` — you get free size validation.
- A size of **`0` means "don't validate / any size"**; the generated `in[0]` is
  an *unsized* array, so use it only when you won't index a fixed slot
  (`ioctl_vendor` takes `0` input cells, for example).
- Return `STATUS_SUCCESS` or an appropriate `STATUS_*` from
  [`ntstatus.inc`](../modules/include/ntstatus.inc) (`STATUS_ACCESS_DENIED`,
  `STATUS_INVALID_PARAMETER`, `STATUS_NOT_SUPPORTED`, …).

## Cells are 64-bit

With `-C64`, every cell is a 64-bit value. `in[]`/`out[]` map 1:1 to the
`ULONG64[]` your host passes/receives. When a value is really 32-bit (CPUID
registers, an I/O byte), the meaningful bits sit in the low part of the cell;
mask with `& 0xFFFFFFFF` / `& 0xFF` as needed.

## Two patterns worth copying

**Whitelisting** (turn a dangerous native into a safe operation) — `modules/msr.p`:

```pawn
stock allow_read(msr) {
    return msr == IA32_TIME_STAMP_COUNTER || msr == IA32_APERF /* ... */;
}
DEFINE_IOCTL_SIZED(ioctl_read_msr, 1, 1) {
    if (!allow_read(in[0])) return STATUS_ACCESS_DENIED;
    new value; new NTSTATUS:s = msr_read(in[0], value);
    if (s != STATUS_SUCCESS) return s;
    out[0] = value; return STATUS_SUCCESS;
}
```

**Per-core execution** (set affinity → act → restore) — `modules/msr.p`:

```pawn
new old[2];
if (cpu_set_affinity(in[1], old) != STATUS_SUCCESS) return /* ... */;
new value; new NTSTATUS:s = msr_read(in[0], value);
cpu_restore_affinity(old);          // always restore
```

## Gotchas that will bite you

1. **Strings: packed vs unpacked.** `"abc"` is a *packed* string;
   `''abc''` is *unpacked* (one char per cell). PawnIO natives like
   `debug_print` and `get_proc_address` expect **unpacked** strings, so write
   `debug_print(''hi %d'', x)`. (The left pair may also be backticks: `` ``hi'' ``.)
2. **A trailing `\` in a `//` comment** is a line-continuation to the
   preprocessor → `error 049`. Don't end comment lines with a backslash (this
   repo hit it once in an ASCII diagram — see the git history of `sysinfo.p`).
3. **`main()` with a single native call** can misbehave; touch two.
4. **Semicolons & parentheses are required.** Always terminate
   statements and parenthesize `if (...)`.
5. **The default prefix include collides** with PawnIO's `core.inc` (both define
   `min`, `max`, …). The build passes **`-p`** to block it — use the provided
   build scripts and you'll never see this.

## Compiling

Use the scripts (they pin the exact compiler and flags):

```powershell
scripts\build.ps1               # -> build\*.amx
```

Under the hood it runs, per module:

```
pawncc modules\<name>.p -imodules\include -C64 -p -obuild\<name>.amx
```

- `-C64` 64-bit cells · `-p` block the default prefix include · `-i` header search path

The output `.amx` is raw bytecode. To *load* it you wrap it in a blob — see the
[user-space API](04-userspace-api.md) — and you need the right driver edition
(see [signing & editions](05-signing-and-editions.md)).
