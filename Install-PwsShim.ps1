<#
.SYNOPSIS
    Install or update `C:\Tools\pws.cmd` and ensure `C:\Tools` is on the
    machine PATH; self-elevates and is idempotent.

.DESCRIPTION
    • Drops a dual-mode shim:  
        - no args → new PowerShell window (-NoLogo -NoProfile -ExecutionPolicy Bypass)  
        - file arg → runs script in current window with same flags  
    • Adds C:\Tools to HKLM PATH if missing.  
    • Rewrites nothing and exits cleanly when state is already correct.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── elevation guard ──
if (-not ([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
{
    Start-Process powershell.exe `
        -ArgumentList @('-NoExit','-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
                        '-File',"`"$PSCommandPath`"") + ($args|ForEach-Object{"`"$_`""}) `
        -Verb RunAs
    exit
}

# paths and template
$dir  = 'C:\Tools'
$file = "$dir\pws.cmd"
$body = @'
@echo off
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if "%~1"=="" (
    start "" "%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass
) else (
    set "s=%~1" & shift
    "%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%s%" %*
)
'@

# ensure dir
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# write only if content differs
if ((Test-Path $file) -and ((Get-Content $file -Raw) -eq $body)) {
    $fileState = 'up-to-date'
} else {
    Set-Content $file -Value $body -Encoding ASCII
    $fileState = 'written/updated'
}

# ensure PATH contains dir
$path = [Environment]::GetEnvironmentVariable('Path','Machine') -split ';'
if ($path -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', ($path + $dir) -join ';','Machine')
    $pathState = 'added to PATH (new shells required)'
} else {
    $pathState = 'PATH already contained C:\Tools'
}

Write-Host "pws.cmd $fileState — $pathState"
