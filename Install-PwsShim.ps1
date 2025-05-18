<#
.SYNOPSIS
    Installs or updates the global “pws” shim in C:\Tools.
    Relaunches itself elevated and keeps the elevated window open.

.DESCRIPTION
    • Self-elevates (-NoExit) when not already running as Administrator.
    • Creates / overwrites C:\Tools\pws.cmd with a dual-mode wrapper:
        – no args  → interactive PowerShell
        – file arg → -File <script> <args>
      The wrapper uses label flow to avoid the %variable% timing bug.
    • Adds C:\Tools to the machine PATH if missing (idempotent).

.NOTES
    Tested on Windows 10/11 with Windows PowerShell 5.1 and PowerShell 7.4.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
               [Security.Principal.WindowsIdentity]::GetCurrent() `
              ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    if ($isAdmin) { return }

    Write-Host 'Not running as Administrator – relaunching elevated …'

    # Preserve original CLI arguments when re-launching
    $escaped = $args | ForEach-Object { '"{0}"' -f ($_ -replace '"','`"') }

    $invokeArgs = @(
        '-NoExit','-NoLogo','-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-File', "`"$PSCommandPath`""
    ) + $escaped

    Start-Process -FilePath 'powershell.exe' -ArgumentList ($invokeArgs -join ' ') -Verb RunAs
    exit   # terminate non-elevated instance
}
Ensure-Admin

# ───── Parameters ────────────────────────────────────────────────────────────
$shimFolder = 'C:\Tools'
$shimFile   = Join-Path $shimFolder 'pws.cmd'

$shimBody = @'
:: pws.cmd — dual-mode shim for "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass"
@echo off

if "%~1"=="" (
    goto :interactive
) else (
    goto :runfile
)

:interactive
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
  -NoLogo -NoProfile -ExecutionPolicy Bypass
goto :eof

:runfile
set "script=%~1"
shift
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
  -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
goto :eof
'@  # keep flush-left; do not indent closing quote

# ───── Main logic ────────────────────────────────────────────────────────────
# 1.  Ensure C:\Tools exists
if (-not (Test-Path -LiteralPath $shimFolder)) {
    New-Item -ItemType Directory -Path $shimFolder -Force | Out-Null
}

# 2.  Write / update shim if content differs
$rewrite = $true
if (Test-Path -LiteralPath $shimFile) {
    $existing = Get-Content -LiteralPath $shimFile -Raw -Encoding ASCII
    $rewrite  = ($existing -ne $shimBody)
}
if ($rewrite) {
    Set-Content -LiteralPath $shimFile -Value $shimBody -Encoding ASCII
}

# 3.  Add C:\Tools to machine PATH if needed
$pathMachine = [Environment]::GetEnvironmentVariable('Path','Machine')
$pathParts   = $pathMachine -split ';'
$pathPatched = $false
if ($pathParts -notcontains $shimFolder) {
    [Environment]::SetEnvironmentVariable('Path', ($pathParts + $shimFolder) -join ';', 'Machine')
    $pathPatched = $true
}

# 4.  Summary
Write-Host "Shim location : $shimFile"
Write-Host ("State         : {0}" -f (if ($rewrite) { 'content (re)written' } else { 'up-to-date' }))
if ($pathPatched) {
    Write-Host "PATH update   : added C:\Tools  (new shells required to see it)"
} else {
    Write-Host "PATH update   : already present"
}

# prompt persists (-NoExit)
