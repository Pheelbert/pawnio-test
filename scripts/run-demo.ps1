#Requires -Version 5.1
<#
.SYNOPSIS
    End-to-end demo: build the host, then exercise PawnIO modules.

.DESCRIPTION
    Picks whatever is available on this machine:
      * if your own build\*.amx exist (unrestricted driver), it runs the
        learning modules (hello / cpuid / sysinfo);
      * if official-modules\Echo.bin exists (signed driver), it runs that too.

    It never installs anything. Run scripts\fetch-pawnio.ps1 first to get the
    driver, and scripts\build.ps1 (or build.sh) to compile your modules.

.NOTES
    Run elevated (Administrator). SPDX-License-Identifier: 0BSD
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Host_    = Join-Path $RepoRoot 'host\csharp'
$Build    = Join-Path $RepoRoot 'build'
$Official = Join-Path $RepoRoot 'official-modules'

function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

# Sanity: is the driver present?
if (-not (Get-Service -Name 'PawnIO' -ErrorAction SilentlyContinue)) {
    Write-Host "PawnIO service not found. Run scripts\fetch-pawnio.ps1 first." -ForegroundColor Yellow
}

Write-Step "Building the C# host (dotnet build)"
& dotnet build -c Release --nologo -v minimal $Host_
if ($LASTEXITCODE -ne 0) { throw "host build failed (is the .NET SDK installed?)" }

function Invoke-Lab { param([Parameter(ValueFromRemainingArguments)]$a)
    & dotnet run --project $Host_ -c Release --no-build -- @a
}

Write-Step "PawnIO version"
Invoke-Lab version

if (Test-Path (Join-Path $Build 'hello.amx')) {
    Write-Step "Your modules (unrestricted driver)"
    Invoke-Lab hello   (Join-Path $Build 'hello.amx')   '0xCAFE'
    Invoke-Lab cpuid   (Join-Path $Build 'cpuid.amx')
    Invoke-Lab sysinfo (Join-Path $Build 'sysinfo.amx')
} else {
    Write-Host "  (no build\*.amx yet — run scripts\build.ps1 to compile your modules)" -ForegroundColor DarkGray
}

if (Test-Path (Join-Path $Official 'Echo.bin')) {
    Write-Step "Official signed module: Echo (ioctl_not)"
    Invoke-Lab run (Join-Path $Official 'Echo.bin') ioctl_not 1 0x12345678
} else {
    Write-Host "  (no official-modules\Echo.bin — run fetch-pawnio.ps1 -Modules)" -ForegroundColor DarkGray
}

Write-Step "Demo complete."
