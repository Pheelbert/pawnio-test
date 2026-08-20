#Requires -Version 5.1
<#
.SYNOPSIS
    Fetch and install the already-signed PawnIO driver, and optionally the
    official signed modules. This is the "get a working driver without building
    or signing anything" step.

.DESCRIPTION
    PawnIO ships as a WHQL-path-signed kernel driver plus a user-mode library
    (PawnIOLib.dll). You do NOT build the driver yourself — you install the
    signed release. This script:

      1. downloads PawnIO_setup.exe from the latest official release,
      2. installs it silently (the officially SIGNED edition by default),
      3. locates PawnIOLib.dll and the PawnIO service so you can confirm it
         is live, and
      4. (optional) downloads the official SIGNED modules (*.bin).

    Editions:
      * SIGNED (default)  — loads on any machine, even with Secure Boot / HVCI,
                            but ONLY runs modules signed by the PawnIO author.
                            Use this with the official *.bin modules.
      * UNRESTRICTED      — runs ANY module you compile (your own .amx), but
        (-Unrestricted)     requires Windows test signing to be enabled. The
                            installer is launched interactively so you can pick
                            it; expect a reboot into test-signing mode.

.PARAMETER Unrestricted
    Install the unrestricted (developer) edition instead of the signed one.

.PARAMETER Modules
    Also download the official signed modules (*.bin) into .\official-modules.

.PARAMETER NoInstall
    Only download PawnIO_setup.exe; do not run it.

.EXAMPLE
    # Normal use: signed driver + official signed modules
    powershell -ExecutionPolicy Bypass -File scripts\fetch-pawnio.ps1 -Modules

.EXAMPLE
    # Developer use: run your own compiled .amx modules
    powershell -ExecutionPolicy Bypass -File scripts\fetch-pawnio.ps1 -Unrestricted

.NOTES
    Run from an elevated (Administrator) PowerShell — installing a kernel driver
    is privileged. SPDX-License-Identifier: 0BSD
#>
[CmdletBinding()]
param(
    [switch]$Unrestricted,
    [switch]$Modules,
    [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$DownloadDir = Join-Path $RepoRoot '.pawnio'
$InstallerUrl = 'https://github.com/namazso/PawnIO.Setup/releases/latest/download/PawnIO_setup.exe'
$ModulesApi   = 'https://api.github.com/repos/namazso/PawnIO.Modules/releases/latest'

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Warn($m) { Write-Host "warn: $m" -ForegroundColor Yellow }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin) -and -not $NoInstall) {
    throw "Please run this from an elevated (Administrator) PowerShell to install the driver. " +
          "Or pass -NoInstall to just download the installer."
}

New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null

# 1. Download the signed installer -----------------------------------------
$installer = Join-Path $DownloadDir 'PawnIO_setup.exe'
Write-Step "Downloading PawnIO installer -> $installer"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $InstallerUrl -OutFile $installer -UseBasicParsing
Write-Host ("    {0:N0} bytes" -f (Get-Item $installer).Length)

if ($NoInstall) {
    Write-Step "Downloaded only (-NoInstall). Installer: $installer"
    return
}

# 2. Install ----------------------------------------------------------------
if ($Unrestricted) {
    Write-Warn "Unrestricted edition selected."
    Write-Warn "The installer will open interactively — choose the UNRESTRICTED edition."
    Write-Warn "It requires Windows test signing (the installer explains how); a reboot is expected."
    Start-Process -FilePath $installer -Wait
} else {
    Write-Step "Installing the officially SIGNED edition (silent)..."
    $p = Start-Process -FilePath $installer `
        -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        Write-Warn "Installer exit code $($p.ExitCode). If it failed, run it interactively: $installer"
    }
}

# 3. Verify -----------------------------------------------------------------
Write-Step "Verifying installation..."
$progDirs = @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)}) |
    Where-Object { $_ } | Select-Object -Unique
$lib = Get-ChildItem -Path $progDirs `
    -Filter 'PawnIOLib.dll' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($lib) { Write-Host "    PawnIOLib.dll : $($lib.FullName)" -ForegroundColor Green }
else      { Write-Warn "PawnIOLib.dll not found under Program Files (install may have failed)." }

$svc = Get-Service -Name 'PawnIO' -ErrorAction SilentlyContinue
if ($svc) { Write-Host "    Service PawnIO: $($svc.Status)" -ForegroundColor Green }
else      { Write-Warn "PawnIO service not found. Check the installer output." }

$drv = Get-ChildItem -Path $progDirs `
    -Filter 'PawnIO.sys' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($drv) { Write-Host "    Signed driver : $($drv.FullName)" -ForegroundColor Green }

# 4. Official signed modules (optional) ------------------------------------
if ($Modules) {
    Write-Step "Downloading official signed modules..."
    $outDir = Join-Path $RepoRoot 'official-modules'
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $rel = Invoke-RestMethod -Uri $ModulesApi -Headers @{ 'User-Agent' = 'pawnio-test' }
    $asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
    if (-not $asset) { throw "No .zip asset on the latest PawnIO.Modules release." }

    $zip = Join-Path $DownloadDir $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
    $tmp = Join-Path $DownloadDir 'modules_extract'
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force

    # Flatten every *.bin into official-modules\
    Get-ChildItem -Path $tmp -Filter '*.bin' -Recurse |
        ForEach-Object { Copy-Item $_.FullName -Destination $outDir -Force }
    $bins = Get-ChildItem -Path $outDir -Filter '*.bin'
    Write-Host "    $($bins.Count) signed module(s) -> $outDir" -ForegroundColor Green
    $bins | ForEach-Object { Write-Host "      $($_.Name)" }
    Write-Host "    (release $($rel.tag_name))"
}

Write-Step "Done. Try:  dotnet run --project host\csharp -- version"
