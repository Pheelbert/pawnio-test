// PawnIO.cs — a tiny, dependency-free C# wrapper over PawnIOLib.dll.
//
// PawnIOLib.dll is the user-mode library that ships with PawnIO (it lands in
// C:\Program Files\PawnIO when you install the driver). It hides the raw
// DeviceIoControl protocol behind five functions:
//
//     pawnio_version(&version)                         -> HRESULT
//     pawnio_open(&handle)                             -> HRESULT
//     pawnio_load(handle, blob, size)                  -> HRESULT
//     pawnio_execute(handle, name, in, in_n,
//                    out, out_n, &return_size)         -> HRESULT
//     pawnio_close(handle)                             -> HRESULT
//
// All values crossing the boundary are 64-bit cells (ULONG64), matching the
// modules we compile with -C64.
//
// SPDX-License-Identifier: 0BSD

using System.Runtime.InteropServices;

namespace PawnIoLab;

/// <summary>Raw P/Invoke declarations for PawnIOLib.dll.</summary>
internal static class Native
{
    private const string Dll = "PawnIOLib";

    // Teach the runtime where to find PawnIOLib.dll even if it isn't next to the
    // executable or on PATH: fall back to the default install directory.
    static Native()
    {
        NativeLibrary.SetDllImportResolver(typeof(Native).Assembly, (name, asm, path) =>
        {
            if (name != Dll)
                return IntPtr.Zero;

            if (NativeLibrary.TryLoad(name, asm, path, out var h))
                return h;

            foreach (var candidate in CandidatePaths())
                if (File.Exists(candidate) && NativeLibrary.TryLoad(candidate, out h))
                    return h;

            return IntPtr.Zero;
        });
    }

    private static IEnumerable<string> CandidatePaths()
    {
        var exeDir = AppContext.BaseDirectory;
        yield return Path.Combine(exeDir, "PawnIOLib.dll");

        foreach (var env in new[] { "ProgramW6432", "ProgramFiles", "ProgramFiles(x86)" })
        {
            var pf = Environment.GetEnvironmentVariable(env);
            if (!string.IsNullOrEmpty(pf))
                yield return Path.Combine(pf, "PawnIO", "PawnIOLib.dll");
        }
    }

    [DllImport(Dll)] internal static extern int pawnio_version(out uint version);
    [DllImport(Dll)] internal static extern int pawnio_open(out IntPtr handle);

    [DllImport(Dll)]
    internal static extern int pawnio_load(IntPtr handle, byte[] blob, nuint size);

    [DllImport(Dll, CharSet = CharSet.Ansi)]
    internal static extern int pawnio_execute(
        IntPtr handle,
        [MarshalAs(UnmanagedType.LPStr)] string name,
        ulong[] input, nuint inCount,
        ulong[] output, nuint outCount,
        out nuint returnSize);

    [DllImport(Dll)] internal static extern int pawnio_close(IntPtr handle);
}

/// <summary>Thrown when a PawnIOLib call returns a failing HRESULT.</summary>
public sealed class PawnIoException(string what, int hr)
    : Exception($"{what} failed: HRESULT 0x{hr:X8} ({Describe(hr)})")
{
    public int HResult2 { get; } = hr;

    private static string Describe(int hr) => (uint)hr switch
    {
        0x80070005 => "E_ACCESSDENIED — run as Administrator",
        0x80070002 => "not found - check the module path or function name",
        0x8007007E => "PawnIOLib.dll not found — install PawnIO first",
        0xD0000225 => "STATUS_NOT_FOUND — no such exported function in the module",
        _ => "see winerror.h / ntstatus.h"
    };
}

/// <summary>
/// A loaded PawnIO module instance. Open the driver, load a module blob, then
/// call its exported <c>ioctl_*</c> functions by name.
/// </summary>
public sealed class PawnIoModule : IDisposable
{
    private IntPtr _handle;

    private PawnIoModule(IntPtr handle) => _handle = handle;

    /// <summary>PawnIO protocol/driver version reported by the library.</summary>
    public static uint Version()
    {
        Check(Native.pawnio_version(out var v), nameof(Native.pawnio_version));
        return v;
    }

    /// <summary>Open the driver and load a module from a file (.amx or .bin).</summary>
    public static PawnIoModule LoadFile(string path)
    {
        var blob = ToBlob(path);
        Check(Native.pawnio_open(out var handle), nameof(Native.pawnio_open));
        try
        {
            Check(Native.pawnio_load(handle, blob, (nuint)blob.Length), nameof(Native.pawnio_load));
        }
        catch
        {
            Native.pawnio_close(handle);
            throw;
        }
        return new PawnIoModule(handle);
    }

    /// <summary>
    /// Invoke an exported <c>ioctl_*</c> function. <paramref name="input"/> are the
    /// input cells; <paramref name="outCount"/> is how many output cells to request.
    /// Returns exactly the cells the driver wrote back.
    /// </summary>
    public ulong[] Execute(string name, ulong[] input, int outCount)
    {
        // Marshalling an empty array can pass a null pointer; give the library a
        // valid (unused) pointer while still reporting a count of zero.
        var inBuf = input.Length == 0 ? new ulong[1] : input;
        var outBuf = outCount == 0 ? new ulong[1] : new ulong[outCount];

        Check(Native.pawnio_execute(
                  _handle, name,
                  inBuf, (nuint)input.Length,
                  outBuf, (nuint)outCount,
                  out var returnSize),
              $"pawnio_execute(\"{name}\")");

        var cells = (int)returnSize;
        if (cells is < 0 or > 4096) cells = outCount;
        Array.Resize(ref outBuf, Math.Min(cells, outCount));
        return outBuf;
    }

    /// <summary>
    /// Wrap a module file into the blob layout pawnio_load expects:
    /// <c>[4-byte LE signature size][signature][amx]</c>.
    /// A raw <c>.amx</c> gets a zero-length signature (loads only on the
    /// <b>unrestricted</b> driver). A <c>.bin</c> from the official releases is
    /// already a signed blob and is passed through unchanged.
    /// </summary>
    public static byte[] ToBlob(string path)
    {
        var data = File.ReadAllBytes(path);
        if (path.EndsWith(".amx", StringComparison.OrdinalIgnoreCase))
        {
            var blob = new byte[4 + data.Length];   // first 4 bytes stay zero
            Buffer.BlockCopy(data, 0, blob, 4, data.Length);
            return blob;
        }
        return data;
    }

    private static void Check(int hr, string what)
    {
        if (hr < 0) throw new PawnIoException(what, hr);
    }

    public void Dispose()
    {
        if (_handle != IntPtr.Zero)
        {
            Native.pawnio_close(_handle);
            _handle = IntPtr.Zero;
        }
    }
}
