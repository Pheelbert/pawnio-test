# 5. Signing & editions

The one thing that confuses everyone: **the officially signed driver will not
load modules you compiled yourself.** Here's why, and what to do about it.

## Two editions

PawnIO is built two ways (a compile-time switch, `PAWNIO_UNRESTRICTED`):

| | **Signed** (default) | **Unrestricted** (developer) |
|---|---|---|
| Driver signing | Officially signed → loads normally, even with **Secure Boot / HVCI** | Not production-signed → needs **test signing** enabled + reboot |
| Module check | **RSA signature verified** against a key baked into the driver | **No** signature check — any `.amx` loads |
| Who can add modules | Only the PawnIO author | You |
| Good for | Shipping products (LibreHardwareMonitor, FanControl) with official modules | **Developing and learning** to write modules |

The installer (`PawnIO_setup.exe`) lets you pick. `scripts/fetch-pawnio.ps1`
installs **signed** by default, or **unrestricted** with `-Unrestricted`.

## Why the split exists

If the signed driver loaded *any* module, PawnIO would itself become a universal
BYOVD tool: malware could sign nothing, drop a `physical_write`/`invoke` module,
and own the kernel — exactly what PawnIO exists to prevent. So the signed driver
only runs **author-signed** modules (the vetted ones in the official releases).
Arbitrary modules are confined to the unrestricted driver, which you can only run
by *deliberately* lowering your machine into test-signing mode. The friction is
the feature.

## Consequences for this repo

- The modules in `modules/` are **yours**, unsigned → they run on the
  **unrestricted** driver only.
- The official signed `*.bin` modules run on the **signed** driver.
- So:
  - **Learning to author** (the point of this repo) → unrestricted edition.
  - **Using the signed driver** → drive official `*.bin` modules from `host/`.

## Enabling test signing (unrestricted edition)

The installer walks you through it; manually it's:

```powershell
bcdedit /set testsigning on
# reboot
```

A "Test Mode" watermark appears on the desktop. To undo:

```powershell
bcdedit /set testsigning off
# reboot
```

Test signing lowers a security boundary (it lets *any* test-signed driver load).
Do it on a dev box, not a daily driver. On some systems Secure Boot must be off
to enable test signing.

## Signing a module (for completeness)

The official tooling can wrap an `.amx` into a signed blob:

```
PawnIOUtil sign  input.amx  output.bin  private_key.pem
```

But the *driver* only trusts the author's key, so self-signed blobs don't help
you on the signed edition — this is only useful to the PawnIO project itself when
it publishes official modules. For your own work, use the unrestricted driver and
load the raw `.amx` (the host wraps it with an empty signature automatically; see
[the blob format](04-userspace-api.md#the-blob-format-important)).

## Decision flowchart

```
Do you need to run YOUR OWN module?
├─ Yes → Unrestricted edition (test signing).  fetch-pawnio.ps1 -Unrestricted
│         Build with scripts/build.*, load build/<name>.amx.
└─ No, official modules are enough
          → Signed edition (no test signing).  fetch-pawnio.ps1 -Modules
            Load official-modules/<Name>.bin.
```
