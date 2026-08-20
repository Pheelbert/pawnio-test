import struct
import sys
import os

if len(sys.argv) < 2:
    print(f"Usage: python {sys.argv[0]} <input.amx> [output.bin]")
    sys.exit(1)

input_path = sys.argv[1]
if len(sys.argv) >= 3:
    output_path = sys.argv[2]
else:
    base = os.path.splitext(input_path)[0]
    output_path = base + ".bin"

with open(input_path, "rb") as f:
    payload = f.read()

sig_len = 512
fake_sig = b"\xDE\xAD" * (sig_len // 2)

with open(output_path, "wb") as f:
    f.write(struct.pack("<I", sig_len))
    f.write(fake_sig)
    f.write(payload)

print(f"Wrote {output_path} ({4 + sig_len + len(payload)} bytes)")
print(f"  sig_len:  {sig_len}")
print(f"  sig:      {sig_len} bytes (dummy 0xDEAD pattern)")
print(f"  payload:  {len(payload)} bytes from {input_path}")
