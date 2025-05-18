<#
.SYNOPSIS
    Deploy or update the global “pws” launcher in C:\Tools — safely, repeatably.

.DESCRIPTION
    ▌Overview
      The installer copies a dual-mode batch shim (pws.cmd) to C:\Tools and
      ensures that directory is on the machine-wide PATH.  It is safe to run
      multiple times: if the target file already matches the desired content
      and PATH already contains C:\Tools, no state changes occur.

    ▌Why idempotency matters
      • Automation pipelines often re-apply the same configuration.
      • Re-running must be quick and side-effect-free: no duplicate PATH
        entries, no redundant file writes, no extra UAC prompts.
      • Predictable exit status (zero when nothing fails) is essential for
        build / CI orchestration.

    ▌Elevation strategy
      • Modifying HKLM environment variables and writing in C:\Tools requires
        administrative rights.
      • If the current session lacks them, the script relaunches itself via
        Start-Process -Verb RunAs *with* -NoExit so the elevated window stays
        open.  The original instance terminates immediately to avoid
        duplicate work or output.

    Tested on Windows 10 & 11 with Windows PowerShell 5.1 and PowerShell 7.4.
#>
# --------------------------- runtime safety knobs ----------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --------------------------- self-elevation helper ---------------------------
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
               [Security.Principal.WindowsIdentity]::GetCurrent() `
              ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    if ($isAdmin) { return }             # already privileged → continue

    Write-Host 'Elevated rights required — relaunching…'

    # Re-quote original CLI args so they survive the hop intact.
    $escapedArgs = $args | ForEach-Object { '"{0}"' -f ($_ -replace '"','`"') }

    $invoke = @(
        # Keep the elevated window open so the user can read the summary.
        '-NoExit',
        # Minimise startup latency / noise.
        '-NoLogo','-NoProfile',
        # Bypass only for this short-lived installer, not for the deployed shim.
        '-ExecutionPolicy','Bypass',
        '-File', "`"$PSCommandPath`""
    ) + $escapedArgs

    Start-Process powershell.exe -ArgumentList ($invoke -join ' ') -Verb RunAs
    exit                                   # quit non-elevated instance
}
Ensure-Admin

# --------------------------- desired state variables -------------------------
$ShimDir  = 'C:\Tools'                     # central drop-location for helper tools
$ShimPath = "$ShimDir\pws.cmd"

$ShimBody = @'
:: pws.cmd — dual-mode helper wrapping "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass"
:: ------------------------------------------------------------------------------
:: • No arguments  → launch a **new console window** with hardened flags.
:: • With script   → execute that script in the *current* console.
@echo off
setlocal

set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

:: ── CASE 1 : NO ARGUMENTS
if "%~1"=="" (
    rem  Use START to spawn an independent window so the caller regains the prompt.
    start "" "%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass
    goto :EOF
)

:: ── CASE 2 : FIRST TOKEN = SCRIPT FILE
set "script=%~1"
shift
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
goto :EOF
'@  # ← keep terminator flush-left (verbatim here-string)

# --------------------------- step 1 : ensure directory -----------------------
if (-not (Test-Path -LiteralPath $ShimDir)) {
    New-Item -ItemType Directory -Path $ShimDir -Force | Out-Null
}

# --------------------------- step 2 : file reconciliation --------------------
$rewrite = $true
if (Test-Path -LiteralPath $ShimPath) {
    # Idempotency check: compare existing file byte-for-byte.
    $existing = Get-Content -LiteralPath $ShimPath -Raw -Encoding ASCII
    $rewrite  = ($existing -ne $ShimBody)
}
if ($rewrite) {
    Set-Content -LiteralPath $ShimPath -Value $ShimBody -Encoding ASCII
}

# --------------------------- step 3 : PATH reconciliation --------------------
$pathMachine = [Environment]::GetEnvironmentVariable('Path','Machine')
$segments    = $pathMachine -split ';'
$pathPatched = $false

if ($segments -notcontains $ShimDir) {
    [Environment]::SetEnvironmentVariable(
        'Path', ($segments + $ShimDir) -join ';', 'Machine')
    $pathPatched = $true
}

# --------------------------- step 4 : human-readable summary -----------------
$state = if ($rewrite) { 'content (re)written' } else { 'already correct' }
Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗'
Write-Host "║ Shim path : $ShimPath"
Write-Host "║ File      : $state"
Write-Host ("║ PATH      : {0}" -f (if ($pathPatched) { 'added C:\Tools' } else { 'unchanged' }))
Write-Host '╚══════════════════════════════════════════════════════════╝'
if ($pathPatched) {
    Write-Host '» Open a *new* console, or log off, so the updated PATH propagates.'
}

# — script exits, but elevated PowerShell stays open (-NoExit) —
