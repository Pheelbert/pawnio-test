#Requires -Version 5.1
<#
.SYNOPSIS
    Compile modules\*.p into build\*.amx on Windows.

.DESCRIPTION
    Building modules needs the Pawn compiler (pawncc), NOT the Windows DDK — you
    are compiling bytecode, not a driver. This script finds a compiler in order:

      1. pawncc.exe on PATH or in .tools\
      2. otherwise, if WSL is available, it delegates to scripts/build.sh, which
         downloads the exact pinned compiler and builds there.

    If neither is available it prints how to get one. The simplest option on
    Windows is usually WSL ("wsl --install"), which then "just works".

.PARAMETER Modules
    Specific module names to build (default: all).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\build.ps1
.NOTES
    SPDX-License-Identifier: 0BSD
#>
[CmdletBinding()]
param([string[]]$Modules)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ModulesDir = Join-Path $RepoRoot 'modules'
$IncludeDir = Join-Path $ModulesDir 'include'
$OutDir     = Join-Path $RepoRoot 'build'

# Same flags the official modules use: 64-bit cells, strict syntax, no default prefix.
$Flags = @('-C64', '-;+', '-(+', '-p')

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

function Find-Pawncc {
    $onPath = Get-Command 'pawncc.exe','pawncc' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    $cached = Join-Path $RepoRoot '.tools\pawncc.exe'
    if (Test-Path $cached) { return $cached }
    return $null
}

$pawncc = Find-Pawncc
if (-not $pawncc) {
    # Fall back to WSL + the shell build if we can.
    if (Get-Command 'wsl.exe' -ErrorAction SilentlyContinue) {
        Write-Step "No pawncc.exe found; building via WSL (scripts/build.sh)..."
        Push-Location $RepoRoot
        try   { & wsl.exe bash ./scripts/build.sh @Modules }
        finally { Pop-Location }
        exit $LASTEXITCODE
    }
    Write-Host @"
error: no Pawn compiler found.

Pick one of these (any works):
  * Install WSL, then re-run this script:   wsl --install
    (it will build with the exact pinned compiler automatically)
  * Put a Windows pawncc.exe (CompuPhase Pawn 4.1.x) at:
        $($RepoRoot)\.tools\pawncc.exe
  * Or just download the compiled modules from GitHub Actions
    (Actions tab -> latest run -> 'modules' artifact).
"@ -ForegroundColor Red
    exit 1
}

Write-Step "Using compiler: $pawncc"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$sources =
    if ($Modules) {
        $Modules | ForEach-Object {
            $base = $_ -replace '\.p$',''
            Join-Path $ModulesDir "$base.p"
        }
    } else {
        Get-ChildItem -Path $ModulesDir -Filter '*.p' | ForEach-Object FullName
    }

$failed = 0
foreach ($src in $sources) {
    $name = [IO.Path]::GetFileNameWithoutExtension($src)
    $amx  = Join-Path $OutDir "$name.amx"
    Write-Host ("  compiling {0,-12} " -f $name) -NoNewline
    & $pawncc $src "-i$IncludeDir" @Flags "-o$amx" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path $amx)) {
        Write-Host ("ok  ({0} bytes)" -f (Get-Item $amx).Length) -ForegroundColor Green
    } else {
        Write-Host "FAILED" -ForegroundColor Red
        & $pawncc $src "-i$IncludeDir" @Flags "-o$amx"   # re-run to show errors
        $failed = 1
    }
}

if ($failed) { throw "one or more modules failed to compile" }
Write-Step "Built modules into $OutDir"
