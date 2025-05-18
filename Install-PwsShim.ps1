<#
.SYNOPSIS
    Installs or updates the global “pws” shim under C:\Tools.
    • Auto-elevates (with -NoExit) if not already running as Administrator.
    • Writes C:\Tools\pws.cmd:
        – 0 args  →  new console window:   start "" powershell.exe …
        – 1+ args →  -File <script> <args>
    • Adds C:\Tools to the machine PATH when missing (idempotent).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Self-elevate ─────────────────────────────────────────────────────────────
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
               [Security.Principal.WindowsIdentity]::GetCurrent() `
              ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    if ($isAdmin) { return }

    Write-Host 'Not running as Administrator – relaunching elevated …'

    $escaped = $args | ForEach-Object { '"{0}"' -f ($_ -replace '"','`"') }
    $invoke  = @(
        '-NoExit','-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
        '-File', "`"$PSCommandPath`""
    ) + $escaped

    Start-Process -FilePath 'powershell.exe' -ArgumentList ($invoke -join ' ') -Verb RunAs
    exit
}
Ensure-Admin

# ── Shim contents ────────────────────────────────────────────────────────────
$shimFolder = 'C:\Tools'
$shimFile   = Join-Path $shimFolder 'pws.cmd'

$shimBody = @'
:: pws.cmd — dual-mode shim for "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass"
@echo off
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

:: ── no arguments → spawn new window
if "%~1"=="" (
    start "" "%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass
    goto :eof
)

:: ── first token = script file → run in current console
set "script=%~1"
shift
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
goto :eof
'@

# ── Write shim & PATH logic ─────────────────────────────────────────────────
if (-not (Test-Path $shimFolder)) {
    New-Item -ItemType Directory -Path $shimFolder -Force | Out-Null
}

$rewrite = $true
if (Test-Path $shimFile) {
    $rewrite = ((Get-Content $shimFile -Raw -Encoding ASCII) -ne $shimBody)
}
if ($rewrite) {
    Set-Content $shimFile -Value $shimBody -Encoding ASCII
}

$pathMachine = [Environment]::GetEnvironmentVariable('Path','Machine')
$pathParts   = $pathMachine -split ';'
$pathPatched = $false
if ($pathParts -notcontains $shimFolder) {
    [Environment]::SetEnvironmentVariable('Path', ($pathParts + $shimFolder) -join ';', 'Machine')
    $pathPatched = $true
}

# ── Summary ─────────────────────────────────────────────────────────────────
$state = $(if ($rewrite) { 'content (re)written' } else { 'up-to-date' })
Write-Host "Shim location : $shimFile"
Write-Host "State         : $state"
if ($pathPatched) {
    Write-Host "PATH update   : added C:\Tools  (open a new shell to pick it up)"
} else {
    Write-Host "PATH update   : already present"
}
# console stays open because script was launched with -NoExit
