<#
.SYNOPSIS
    Installs or updates the global “pws” shim in C:\Tools.
    *Self-elevates* and keeps the elevated window open when done.

.DESCRIPTION
    • If not running as Administrator, relaunches itself with:
        -NoExit -NoLogo -NoProfile -ExecutionPolicy Bypass -File <thisScript>
      The original instance exits right away.
    • Drops / updates C:\Tools\pws.cmd:
        - No arguments  → interactive PowerShell with hard-wired flags
        - Script given  → same flags + -File <script> <args>
    • Adds C:\Tools to the machine PATH if missing (idempotent).

.NOTES
    Tested on Windows 10/11 (PowerShell 5.1 & 7.4).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Self-elevation─────────────────────────────────────────────────────────────
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
                [Security.Principal.WindowsIdentity]::GetCurrent() `
               ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    if ($isAdmin) { return }

    Write-Host 'Not running as Administrator – relaunching elevated …'

    # Re-quote original arguments so they survive the hop intact
    $escapedArgs = $args | ForEach-Object { '"{0}"' -f ($_ -replace '"','`"') }

    $invokeArgs  = @(
        '-NoExit','-NoLogo','-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-File', "`"$PSCommandPath`""
    ) + $escapedArgs

    Start-Process -FilePath 'powershell.exe' -ArgumentList ($invokeArgs -join ' ') -Verb RunAs
    exit   # abandon non-elevated copy
}
Ensure-Admin

# ── Constants ────────────────────────────────────────────────────────────────
$shimFolder = 'C:\Tools'
$shimFile   = Join-Path $shimFolder 'pws.cmd'

$shimBody = @'
:: pws.cmd — dual-mode shim for "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass"
@echo off
if "%~1"=="" (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
        -NoLogo -NoProfile -ExecutionPolicy Bypass
) else (
    set "script=%~1"
    shift
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
        -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
)
'@  # keep flush-left; do not indent closing quote

# ── Main logic ────────────────────────────────────────────────────────────────
# 1  Ensure target directory
if (-not (Test-Path -LiteralPath $shimFolder)) {
    New-Item -ItemType Directory -Path $shimFolder -Force | Out-Null
}

# 2  Write/update shim if content differs
$rewrite = $true
if (Test-Path -LiteralPath $shimFile) {
    $existing = Get-Content -LiteralPath $shimFile -Raw -Encoding ASCII
    $rewrite  = ($existing -ne $shimBody)
}
if ($rewrite) {
    Set-Content -LiteralPath $shimFile -Value $shimBody -Encoding ASCII
}

# 3  Add C:\Tools to machine PATH if needed
$pathMachine = [Environment]::GetEnvironmentVariable('Path','Machine')
$pathParts   = $pathMachine -split ';'
$pathPatched = $false
if ($pathParts -notcontains $shimFolder) {
    [Environment]::SetEnvironmentVariable(
        'Path', ($pathParts + $shimFolder) -join ';', 'Machine')
    $pathPatched = $true
}

# 4  Summary
Write-Host "Shim location : $shimFile"
Write-Host ("State         : {0}" -f (if ($rewrite) { 'content (re)written' } else { 'up-to-date' }))
if ($pathPatched) {
    Write-Host "PATH update   : added C:\Tools (new shells required to see it)"
} else {
    Write-Host "PATH update   : already present"
}

# prompt remains because we launched with -NoExit
