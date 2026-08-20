// Program.cs — a small command-line playground for PawnIO modules.
//
//   pawnlab version
//   pawnlab hello    <hello.amx|bin>   [valueHex]
//   pawnlab cpuid    <cpuid.amx|bin>
//   pawnlab sysinfo  <sysinfo.amx|bin>
//   pawnlab msr      <msr.amx|bin> <msrIndexHex> [cpuIndex]
//   pawnlab cmos     <portio.amx|bin>
//   pawnlab run      <module.amx|bin> <function> <outCount> [argHex ...]
//
// The typed commands (hello/cpuid/...) know how to decode a specific module's
// output into something readable; `run` is the generic escape hatch that calls
// any exported ioctl_* by name, exactly like `PawnIOUtil`.
//
// Requires: PawnIO installed (for PawnIOLib.dll + the driver) and an elevated
// (Administrator) terminal, because talking to a kernel driver is privileged.
//
// SPDX-License-Identifier: 0BSD

using System.Globalization;
using PawnIoLab;

try
{
    return Run(args);
}
catch (PawnIoException ex)
{
    Console.Error.WriteLine($"error: {ex.Message}");
    return 1;
}
catch (DllNotFoundException)
{
    Console.Error.WriteLine("error: PawnIOLib.dll not found. Install PawnIO first "
        + "(scripts/fetch-pawnio.ps1), or copy PawnIOLib.dll next to this program.");
    return 2;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"error: {ex.Message}");
    return 1;
}

static int Run(string[] args)
{
    if (args.Length == 0) { Usage(); return 64; }

    switch (args[0].ToLowerInvariant())
    {
        case "version":
            var ver = PawnIoModule.Version();
            Console.WriteLine($"PawnIO version: {ver} (0x{ver:X})");
            return 0;

        case "hello": return Hello(args);
        case "cpuid": return Cpuid(args);
        case "sysinfo": return SysInfo(args);
        case "msr": return Msr(args);
        case "cmos": return Cmos(args);
        case "run": return Generic(args);

        case "-h" or "--help" or "help": Usage(); return 0;
        default:
            Console.Error.WriteLine($"unknown command: {args[0]}");
            Usage();
            return 64;
    }
}

// ---- typed demos --------------------------------------------------------

static int Hello(string[] a)
{
    Need(a, 2, "hello <hello.amx|bin> [valueHex]");
    ulong value = a.Length > 2 ? ParseHex(a[2]) : 0xDEADBEEFUL;

    using var m = PawnIoModule.LoadFile(a[1]);
    var o = m.Execute("ioctl_hello", new[] { value }, 3);
    Console.WriteLine($"arch        : {ArchName(o[0])}");
    Console.WriteLine($"cpu_count   : {o[1]}");
    Console.WriteLine($"echoed value: 0x{o[2]:X}");
    return 0;
}

static int Cpuid(string[] a)
{
    Need(a, 2, "cpuid <cpuid.amx|bin>");
    using var m = PawnIoModule.LoadFile(a[1]);

    var v = m.Execute("ioctl_vendor", Array.Empty<ulong>(), 4);
    var vendor = Chars4(v[0]) + Chars4(v[1]) + Chars4(v[2]);
    ulong fms = v[3];
    Console.WriteLine($"vendor  : {vendor}");
    Console.WriteLine($"family  : 0x{(fms >> 16) & 0xFF:X}  "
        + $"model: 0x{(fms >> 8) & 0xFF:X}  stepping: 0x{fms & 0xFF:X}");

    var b = m.Execute("ioctl_brand", Array.Empty<ulong>(), 12);
    var brand = string.Concat(b.Select(Chars4)).Trim('\0', ' ');
    Console.WriteLine($"brand   : {brand}");

    // Show the raw-passthrough form too: leaf 1, subleaf 0.
    var r = m.Execute("ioctl_cpuid", new ulong[] { 1, 0 }, 4);
    Console.WriteLine($"leaf 1  : eax=0x{(uint)r[0]:X8} ebx=0x{(uint)r[1]:X8} "
        + $"ecx=0x{(uint)r[2]:X8} edx=0x{(uint)r[3]:X8}");
    return 0;
}

static int SysInfo(string[] a)
{
    Need(a, 2, "sysinfo <sysinfo.amx|bin>");
    using var m = PawnIoModule.LoadFile(a[1]);
    var o = m.Execute("ioctl_sysinfo", Array.Empty<ulong>(), 8);

    var vendor = Chars4(o[2]) + Chars4(o[3]) + Chars4(o[4]);
    ulong fms = o[5];
    Console.WriteLine($"arch      : {ArchName(o[0])}");
    Console.WriteLine($"cpu_count : {o[1]}");
    Console.WriteLine($"vendor    : {vendor}");
    Console.WriteLine($"family    : 0x{(fms >> 16) & 0xFF:X}  "
        + $"model: 0x{(fms >> 8) & 0xFF:X}  stepping: 0x{fms & 0xFF:X}");
    Console.WriteLine($"tsc       : {o[6]}");
    Console.WriteLine($"rdrand    : 0x{o[7]:X16}");
    return 0;
}

static int Msr(string[] a)
{
    Need(a, 3, "msr <msr.amx|bin> <msrIndexHex> [cpuIndex]");
    ulong index = ParseHex(a[2]);
    using var m = PawnIoModule.LoadFile(a[1]);

    ulong value;
    if (a.Length > 3)
    {
        ulong cpu = ulong.Parse(a[3], CultureInfo.InvariantCulture);
        value = m.Execute("ioctl_read_msr_on", new[] { index, cpu }, 1)[0];
        Console.WriteLine($"MSR 0x{index:X} on CPU {cpu} = 0x{value:X16} ({value})");
    }
    else
    {
        value = m.Execute("ioctl_read_msr", new[] { index }, 1)[0];
        Console.WriteLine($"MSR 0x{index:X} = 0x{value:X16} ({value})");
    }
    return 0;
}

static int Cmos(string[] a)
{
    Need(a, 2, "cmos <portio.amx|bin>");
    using var m = PawnIoModule.LoadFile(a[1]);
    var o = m.Execute("ioctl_rtc_time", Array.Empty<ulong>(), 3);
    // CMOS RTC values are usually BCD: 0x59 means 59.
    Console.WriteLine($"RTC (raw)  : {o[2]:X2}:{o[1]:X2}:{o[0]:X2}  (hex = BCD digits)");
    Console.WriteLine($"RTC (dec)  : {Bcd(o[2]):D2}:{Bcd(o[1]):D2}:{Bcd(o[0]):D2}");
    return 0;
}

// ---- generic runner (like PawnIOUtil) -----------------------------------

static int Generic(string[] a)
{
    Need(a, 4, "run <module.amx|bin> <function> <outCount> [argHex ...]");
    string file = a[1];
    string func = a[2];
    int outCount = int.Parse(a[3], CultureInfo.InvariantCulture);
    var input = a.Skip(4).Select(ParseHex).ToArray();

    using var m = PawnIoModule.LoadFile(file);
    var o = m.Execute(func, input, outCount);

    Console.WriteLine($"{func} returned {o.Length} cell(s):");
    for (int i = 0; i < o.Length; i++)
        Console.WriteLine($"  out[{i}] = 0x{o[i]:X16}  ({o[i]})");
    return 0;
}

// ---- helpers ------------------------------------------------------------

static string ArchName(ulong a) => a switch { 1 => "x86-64", 2 => "ARM64", _ => $"unknown({a})" };

// Low 32 bits of a cell -> 4 little-endian ASCII characters.
static string Chars4(ulong reg)
{
    Span<char> c = stackalloc char[4];
    for (int i = 0; i < 4; i++)
    {
        int b = (int)((reg >> (i * 8)) & 0xFF);
        c[i] = b is >= 0x20 and < 0x7F ? (char)b : '\0';
    }
    return new string(c);
}

static ulong Bcd(ulong v) => ((v >> 4) & 0xF) * 10 + (v & 0xF);

static ulong ParseHex(string s)
{
    s = s.Trim();
    if (s.StartsWith("0x", StringComparison.OrdinalIgnoreCase)) s = s[2..];
    return ulong.Parse(s, NumberStyles.HexNumber, CultureInfo.InvariantCulture);
}

static void Need(string[] a, int n, string usage)
{
    if (a.Length < n) throw new ArgumentException($"usage: pawnlab {usage}");
}

static void Usage()
{
    Console.WriteLine(
        """
        pawnlab — a PawnIO module playground

          pawnlab version
          pawnlab hello    <hello.amx|bin>   [valueHex]
          pawnlab cpuid    <cpuid.amx|bin>
          pawnlab sysinfo  <sysinfo.amx|bin>
          pawnlab msr      <msr.amx|bin> <msrIndexHex> [cpuIndex]
          pawnlab cmos     <portio.amx|bin>
          pawnlab run      <module.amx|bin> <function> <outCount> [argHex ...]

        Notes:
          * Pass a .amx (your own build) only if the UNRESTRICTED driver is
            installed. Pass a signed .bin to use with the official driver.
          * Run from an elevated (Administrator) terminal.
        """);
}
