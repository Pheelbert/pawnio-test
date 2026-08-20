#Requires -Version 5.1
<#
.SYNOPSIS
    Set up the dev environment for pawnio-test: .NET 8 SDK + C++ build tools.

.DESCRIPTION
    Checks for (and installs if missing):
      1. .NET 8 SDK  — needed to build/run the C# host (host\csharp)
      2. Visual Studio C++ build tools — needed to compile the signature tools

    Run from an elevated (Administrator) PowerShell for installation.
    Without elevation, it reports what is missing but cannot install.

.PARAMETER SkipCpp
    Skip the C++ toolchain check (only set up .NET).

.NOTES
    SPDX-License-Identifier: 0BSD
#>
[CmdletBinding()]
param(
    [switch]$SkipCpp
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "    [OK] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "    [!!] $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "    [FAIL] $m" -ForegroundColor Red }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isAdmin = Test-Admin
$allGood = $true

# ---------- 1. .NET 8 SDK ---------------------------------------------------

Write-Step "Checking .NET 8 SDK"

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
$hasSdk = $false

if ($dotnet) {
    $sdks = & dotnet --list-sdks 2>&1
    if ($LASTEXITCODE -eq 0 -and $sdks) {
        $net8 = $sdks | Where-Object { $_ -match '^8\.' }
        if ($net8) {
            $ver = ($net8 | Select-Object -First 1) -replace '\s.*$', ''
            Write-Ok ".NET SDK $ver already installed"
            $hasSdk = $true
        }
    }
}

if (-not $hasSdk) {
    # Check if only the runtime is installed (no SDK)
    $runtimes = $null
    if ($dotnet) {
        $runtimes = & dotnet --list-runtimes 2>&1
    }

    if ($runtimes -and ($runtimes | Where-Object { $_ -match 'Microsoft\.NETCore\.App 8\.' })) {
        Write-Warn ".NET 8 runtime found but NO SDK. The SDK is needed to build/run the C# host."
    } else {
        Write-Warn ".NET 8 not found at all."
    }

    if (-not $isAdmin) {
        Write-Err "Cannot install without elevation. Re-run as Administrator, or install manually:"
        Write-Host "         https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Gray
        $allGood = $false
    } else {
        Write-Host "    Installing .NET 8 SDK via winget..." -ForegroundColor Gray
        $wingetOk = $false
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            & winget install Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -eq 0) {
                Write-Ok ".NET 8 SDK installed. You may need to restart your terminal for 'dotnet' to be on PATH."
                $wingetOk = $true
            } else {
                Write-Warn "winget exited with code $LASTEXITCODE. Trying direct download..."
            }
        }

        if (-not $wingetOk) {
            Write-Host "    Downloading .NET 8 SDK installer..." -ForegroundColor Gray
            $installerUrl = 'https://dot.net/v1/dotnet-install.ps1'
            $installScript = Join-Path $env:TEMP 'dotnet-install.ps1'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $installerUrl -OutFile $installScript -UseBasicParsing
            & $installScript -Channel 8.0 -InstallDir "$env:ProgramFiles\dotnet"
            if ($LASTEXITCODE -eq 0) {
                Write-Ok ".NET 8 SDK installed to $env:ProgramFiles\dotnet"
                Write-Warn "Add to PATH if not already: $env:ProgramFiles\dotnet"
            } else {
                Write-Err "Installation failed. Install manually: https://dotnet.microsoft.com/download/dotnet/8.0"
                $allGood = $false
            }
        }
    }
}

# ---------- 2. C++ build tools (cl.exe via VS2022) --------------------------

if (-not $SkipCpp) {
    Write-Step "Checking C++ build tools (cl.exe)"

    $vcvarsall = $null
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWhere) {
        $installPath = & $vsWhere -latest -property installationPath 2>$null
        if ($installPath) {
            $candidate = Join-Path $installPath "VC\Auxiliary\Build\vcvarsall.bat"
            if (Test-Path $candidate) { $vcvarsall = $candidate }
        }
    }

    if ($vcvarsall) {
        Write-Ok "Found: $vcvarsall"
        # Quick smoke test
        $test = cmd /c "`"$vcvarsall`" x64 >nul 2>&1 && cl.exe 2>&1" | Select-Object -First 1
        if ($test -match 'Compiler Version') {
            Write-Ok "cl.exe works: $($test.Trim())"
        } else {
            Write-Warn "vcvarsall.bat found but cl.exe test failed. C++ workload may be incomplete."
            $allGood = $false
        }
    } else {
        Write-Warn "Visual Studio C++ build tools not found."
        Write-Host "         Install via Visual Studio Installer -> 'Desktop development with C++'" -ForegroundColor Gray
        Write-Host "         Or: winget install Microsoft.VisualStudio.2022.BuildTools" -ForegroundColor Gray
        $allGood = $false
    }
}

# ---------- 3. Quick project sanity checks -----------------------------------

Write-Step "Checking project files"

$checks = @(
    @{ Path = 'host\csharp\PawnIoLab.csproj'; Desc = 'C# host project' },
    @{ Path = 'tools\verify_module.cpp';       Desc = 'Signature verifier source' },
    @{ Path = 'tools\sign_module.cpp';         Desc = 'Module signer source' },
    @{ Path = 'tools\build.bat';               Desc = 'Tools build script' },
    @{ Path = 'scripts\fetch-pawnio.ps1';      Desc = 'PawnIO fetch script' },
    @{ Path = 'scripts\build.ps1';             Desc = 'Module build script' }
)

foreach ($c in $checks) {
    if (Test-Path $c.Path) {
        Write-Ok "$($c.Desc): $($c.Path)"
    } else {
        Write-Warn "Missing: $($c.Path) ($($c.Desc))"
    }
}

# ---------- 4. PawnIO driver status ------------------------------------------

Write-Step "Checking PawnIO driver"

$svc = Get-Service -Name 'PawnIO' -ErrorAction SilentlyContinue
if ($svc) {
    Write-Ok "PawnIO service: $($svc.Status)"
} else {
    Write-Warn "PawnIO service not installed. Run:  scripts\fetch-pawnio.ps1"
}

$lib = Get-ChildItem -Path @($env:ProgramW6432, $env:ProgramFiles) `
    -Filter 'PawnIOLib.dll' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($lib) {
    Write-Ok "PawnIOLib.dll: $($lib.FullName)"
} else {
    Write-Warn "PawnIOLib.dll not found (installed with PawnIO)"
}

# ---------- Summary ----------------------------------------------------------

Write-Step "Summary"
if ($allGood) {
    Write-Host "    Everything looks good. Next steps:" -ForegroundColor Green
    Write-Host "      1. Install PawnIO driver:  scripts\fetch-pawnio.ps1 -Modules"
    Write-Host "      2. Build signature tools:  tools\build.bat"
    Write-Host "      3. Run the demo:           scripts\run-demo.ps1"
} else {
    Write-Host "    Some items need attention (see warnings above)." -ForegroundColor Yellow
}
