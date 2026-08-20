"""pawnio.py — a zero-dependency ctypes wrapper over PawnIOLib.dll.

This is the "no build required" way to talk to PawnIO: install the driver, then
run this script with a normal Python. It mirrors the C# host in host/csharp.

    python pawnio.py version
    python pawnio.py run  <module.amx|bin> <function> <outCount> [argHex ...]
    python pawnio.py cpuid   <cpuid.amx|bin>
    python pawnio.py sysinfo <sysinfo.amx|bin>

Requirements: Windows, PawnIO installed (PawnIOLib.dll + driver), and an
elevated (Administrator) prompt — kernel access is privileged.

SPDX-License-Identifier: 0BSD
"""

from __future__ import annotations

import ctypes
import os
import sys
from ctypes import (
    POINTER,
    byref,
    c_char_p,
    c_size_t,
    c_uint32,
    c_uint64,
    c_void_p,
)

# PawnIOLib returns HRESULTs; S_OK == 0, failures are negative (high bit set).
HRESULT = ctypes.c_long


def _load_library() -> "ctypes.WinDLL":
    if os.name != "nt":
        raise RuntimeError("PawnIO runs on Windows only (PawnIOLib.dll is native).")

    candidates = ["PawnIOLib.dll"]
    for var in ("ProgramW6432", "ProgramFiles", "ProgramFiles(x86)"):
        base = os.environ.get(var)
        if base:
            candidates.append(os.path.join(base, "PawnIO", "PawnIOLib.dll"))

    last: Exception | None = None
    for path in candidates:
        try:
            return ctypes.WinDLL(path)
        except OSError as exc:  # not found / wrong bitness
            last = exc
    raise FileNotFoundError(
        "PawnIOLib.dll not found. Install PawnIO (scripts/fetch-pawnio.ps1) "
        "or place PawnIOLib.dll next to this script."
    ) from last


class PawnIoError(RuntimeError):
    def __init__(self, what: str, hr: int) -> None:
        super().__init__(f"{what} failed: HRESULT 0x{hr & 0xFFFFFFFF:08X}")
        self.hr = hr


class PawnIO:
    """Bindings + a small object wrapper around a loaded module."""

    def __init__(self) -> None:
        lib = _load_library()

        lib.pawnio_version.argtypes = [POINTER(c_uint32)]
        lib.pawnio_version.restype = HRESULT
        lib.pawnio_open.argtypes = [POINTER(c_void_p)]
        lib.pawnio_open.restype = HRESULT
        lib.pawnio_load.argtypes = [c_void_p, c_char_p, c_size_t]
        lib.pawnio_load.restype = HRESULT
        lib.pawnio_execute.argtypes = [
            c_void_p,               # handle
            c_char_p,               # name
            POINTER(c_uint64),      # input
            c_size_t,               # in_count
            POINTER(c_uint64),      # output
            c_size_t,               # out_count
            POINTER(c_size_t),      # return_size
        ]
        lib.pawnio_execute.restype = HRESULT
        lib.pawnio_close.argtypes = [c_void_p]
        lib.pawnio_close.restype = HRESULT

        self._lib = lib
        self._handle = c_void_p()

    # -- lifecycle ---------------------------------------------------------

    @staticmethod
    def version() -> int:
        lib = _load_library()
        lib.pawnio_version.argtypes = [POINTER(c_uint32)]
        lib.pawnio_version.restype = HRESULT
        v = c_uint32()
        _check(lib.pawnio_version(byref(v)), "pawnio_version")
        return v.value

    def load_file(self, path: str) -> "PawnIO":
        blob = to_blob(path)
        _check(self._lib.pawnio_open(byref(self._handle)), "pawnio_open")
        _check(self._lib.pawnio_load(self._handle, blob, len(blob)), "pawnio_load")
        return self

    def execute(self, name: str, inputs: list[int], out_count: int) -> list[int]:
        in_arr = (c_uint64 * max(len(inputs), 1))(*inputs)
        out_arr = (c_uint64 * max(out_count, 1))()
        ret = c_size_t(0)
        _check(
            self._lib.pawnio_execute(
                self._handle,
                name.encode("ascii"),
                in_arr, len(inputs),
                out_arr, out_count,
                byref(ret),
            ),
            f'pawnio_execute("{name}")',
        )
        cells = ret.value // ctypes.sizeof(c_uint64)
        return list(out_arr[: min(cells, out_count)])

    def close(self) -> None:
        if self._handle:
            self._lib.pawnio_close(self._handle)
            self._handle = c_void_p()

    def __enter__(self) -> "PawnIO":
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()


def to_blob(path: str) -> bytes:
    """Wrap a module file into pawnio_load's [4-byte LE sig size][sig][amx] form.

    A raw .amx gets a zero-length signature (unrestricted driver only); a signed
    .bin from the official releases is already a blob and is passed through.
    """
    data = open(path, "rb").read()
    if path.lower().endswith(".amx"):
        return b"\x00\x00\x00\x00" + data
    return data


def _check(hr: int, what: str) -> None:
    if hr < 0:
        raise PawnIoError(what, hr)


# -- tiny CLI --------------------------------------------------------------

def _chars4(cell: int) -> str:
    out = []
    for i in range(4):
        b = (cell >> (i * 8)) & 0xFF
        out.append(chr(b) if 0x20 <= b < 0x7F else "")
    return "".join(out)


def _main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 64

    cmd = argv[0].lower()
    if cmd == "version":
        print(f"PawnIO version: {PawnIO.version()}")
        return 0

    if cmd == "run":
        if len(argv) < 4:
            print("usage: run <module.amx|bin> <function> <outCount> [argHex ...]")
            return 64
        file, func, out_count = argv[1], argv[2], int(argv[3])
        inputs = [int(x, 16) for x in argv[4:]]
        with PawnIO().load_file(file) as m:
            cells = m.execute(func, inputs, out_count)
        for i, c in enumerate(cells):
            print(f"  out[{i}] = 0x{c:016X}  ({c})")
        return 0

    if cmd == "cpuid":
        with PawnIO().load_file(argv[1]) as m:
            v = m.execute("ioctl_vendor", [], 4)
            print("vendor :", _chars4(v[0]) + _chars4(v[1]) + _chars4(v[2]))
            b = m.execute("ioctl_brand", [], 12)
            print("brand  :", "".join(_chars4(x) for x in b).strip())
        return 0

    if cmd == "sysinfo":
        with PawnIO().load_file(argv[1]) as m:
            o = m.execute("ioctl_sysinfo", [], 8)
        arch = {1: "x86-64", 2: "ARM64"}.get(o[0], f"unknown({o[0]})")
        print(f"arch      : {arch}")
        print(f"cpu_count : {o[1]}")
        print("vendor    :", _chars4(o[2]) + _chars4(o[3]) + _chars4(o[4]))
        print(f"tsc       : {o[6]}")
        return 0

    print(f"unknown command: {cmd}")
    print(__doc__)
    return 64


if __name__ == "__main__":
    try:
        raise SystemExit(_main(sys.argv[1:]))
    except (PawnIoError, FileNotFoundError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
