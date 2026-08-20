#Requires -Version 5.1
<#
.SYNOPSIS
    Compile modules\*.p into build\*.amx.

.DESCRIPTION
    Building modules needs the Pawn compiler (pawncc), NOT the Windows DDK — you
    are compiling bytecode, not a driver. This script finds a compiler in order:

      1. pawncc.exe on PATH
      2. pawncc.exe in .tools\
      3. auto-downloads the CompuPhase Pawn toolkit installer into .tools\ and
         extracts pawncc.exe from it.

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
$ToolsDir   = Join-Path $RepoRoot '.tools'

$PawnVersion    = '4.1.7487'
$PawnInstallerUrl = "https://www.compuphase.com/pawn/pawn-$PawnVersion.exe"

# 64-bit cells (the default since 4.1.7487, but explicit for clarity) and no
# default prefix include (avoids collisions with PawnIO's core.inc).
$Flags = @('-C64', '-p')

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

function Find-Pawncc {
    $onPath = Get-Command 'pawncc.exe','pawncc' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    $cached = Join-Path $ToolsDir 'pawncc.exe'
    if (Test-Path $cached) { return $cached }
    return $null
}

function Install-Pawncc {
    Write-Step "Downloading Pawn compiler v$PawnVersion..."
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

    $installer = Join-Path $ToolsDir "pawn-$PawnVersion.exe"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $PawnInstallerUrl -OutFile $installer -UseBasicParsing
    Write-Host ("    downloaded {0:N0} bytes" -f (Get-Item $installer).Length)

    # NSIS installer: /S = silent, /D= = install directory (no quotes, must be last).
    Write-Step "Installing Pawn compiler to $ToolsDir\pawn..."
    $installDir = Join-Path $ToolsDir 'pawn'
    $p = Start-Process -FilePath $installer `
        -ArgumentList "/S","/D=$installDir" `
        -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        throw "Pawn installer failed with exit code $($p.ExitCode)."
    }

    # Copy pawncc.exe (and its DLL) up to .tools\ for easy discovery.
    $binDir = Join-Path $installDir 'bin'
    if (-not (Test-Path $binDir)) { $binDir = $installDir }
    $files = @()
    $files += Get-ChildItem -Path $binDir -Filter 'pawncc*' -ErrorAction SilentlyContinue
    $files += Get-ChildItem -Path $binDir -Filter 'pawnc.dll' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Copy-Item $f.FullName -Destination $ToolsDir -Force
    }

    $result = Join-Path $ToolsDir 'pawncc.exe'
    if (-not (Test-Path $result)) {
        throw "pawncc.exe not found after install. Check $ToolsDir\pawn for the compiler."
    }
    return $result
}

$pawncc = Find-Pawncc
if (-not $pawncc) {
    $pawncc = Install-Pawncc
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
    $ErrorActionPreference = 'Continue'
    & $pawncc $src "-i$IncludeDir" @Flags "-o$amx" 2>&1 | Out-Null
    $ec = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($ec -eq 0 -and (Test-Path $amx)) {
        Write-Host ("ok  ({0} bytes)" -f (Get-Item $amx).Length) -ForegroundColor Green
    } else {
        Write-Host "FAILED" -ForegroundColor Red
        $ErrorActionPreference = 'Continue'
        & $pawncc $src "-i$IncludeDir" @Flags "-o$amx"
        $ErrorActionPreference = 'Stop'
        $failed = 1
    }
}

if ($failed) { throw "one or more modules failed to compile" }
Write-Step "Built modules into $OutDir"
