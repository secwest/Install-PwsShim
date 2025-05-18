<#
.SYNOPSIS
    Installs or updates the global “pws” shim under C:\Tools.
    Relaunches itself elevated if the current process lacks admin rights.

.DESCRIPTION
    • Self-elevation guard: spawns an elevated copy of the script if needed.
    • Creates / overwrites C:\Tools\pws.cmd with a dual-mode wrapper:
        – no arguments  → interactive powershell.exe …
        – first token   → -File <script> <args>
    • Adds C:\Tools to the machine PATH when missing.
    • Idempotent: rerunning changes nothing once state is correct.

.NOTES
    Tested on Windows 10/11 with Windows PowerShell 5.1 and PowerShell 7.4.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Self-elevation ────────────────────────────────────────────────────────────
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
                [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltinRole]::Administrator)

    if ($isAdmin) { return }

    Write-Host 'Not running as Administrator – relaunching elevated …'

    # Build argument list: preserve original CLI args verbatim.
    $quotedArgs = $PsBoundParameters.Values + $args |
                  ForEach-Object { ($_ -replace '"','`"') } | ForEach-Object { "`"`"$_`"`"" }
    $argString  = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
                    '-File', "`"$PSCommandPath`"") + $quotedArgs
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argString -Verb RunAs
    exit
}
Ensure-Admin

# ─── Parameters ───────────────────────────────────────────────────────────────
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
'@  # literal string — keep left-aligned

# ─── Main logic ───────────────────────────────────────────────────────────────
# 1.  Create target directory if absent
if (-not (Test-Path -LiteralPath $shimFolder)) {
    New-Item -ItemType Directory -Path $shimFolder -Force | Out-Null
}

# 2.  Write / update shim when content differs
$rewrite = $true
if (Test-Path -LiteralPath $shimFile) {
    $existing = Get-Content -LiteralPath $shimFile -Raw -Encoding ASCII
    $rewrite  = ($existing -ne $shimBody)
}
if ($rewrite) {
    Set-Content -LiteralPath $shimFile -Value $shimBody -Encoding ASCII
}

# 3.  Add folder to machine PATH if required
$pathMachine = [Environment]::GetEnvironmentVariable('Path','Machine')
$pathParts   = $pathMachine -split ';'
$pathPatched = $false
if ($pathParts -notcontains $shimFolder) {
    [Environment]::SetEnvironmentVariable(
        'Path', ($pathParts + $shimFolder) -join ';', 'Machine')
    $pathPatched = $true
}

# 4.  Summary
Write-Host "Shim location : $shimFile"
Write-Host ("State         : {0}" -f (if ($rewrite) { 'content (re)written' } else { 'up-to-date' }))
if ($pathPatched) {
    Write-Host "PATH update   : added C:\Tools (new shells required to see it)"
} else {
    Write-Host "PATH update   : already present"
}
