<#
.SYNOPSIS
  Create or update C:\Tools\pws.cmd and add C:\Tools to the machine PATH.

.DESCRIPTION
  * Drops a dual-mode shim:
      pws              -> opens a new PowerShell window
      pws <file.ps1>   -> runs the script in the current window
    Flags used in both modes:
      -NoLogo -NoProfile -ExecutionPolicy Bypass
  * Prefers pwsh 7 if it exists, falls back to Windows PowerShell 5.1.
  * Self-elevates once, then exits if no changes are needed (idempotent).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- elevate if needed -------------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent() `
         ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $admin) {
    $childArgs = @(
        '-NoExit','-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
        '-File',"`"$PSCommandPath`""
    ) + ($args | ForEach-Object { "`"$_`"" })

    Start-Process powershell.exe -ArgumentList $childArgs -Verb RunAs
    exit
}

# --- paths -------------------------------------------------------------------
$dir  = 'C:\Tools'
$file = "$dir\pws.cmd"

$body = @'
@echo off
setlocal

rem choose pwsh 7 if present; else use Windows PowerShell 5.1
for %%P in ("%ProgramFiles%\PowerShell\pwsh.exe" ^
            "%ProgramFiles%\PowerShell\7\pwsh.exe" ^
            "%ProgramFiles%\PowerShell\7-preview\pwsh.exe" ^
            "pwsh.exe") do (
    if not defined PS if exist "%%~P" set "PS=%%~P"
)
if not defined PS set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

rem no args -> new window ; args -> run script here
if "%~1"=="" goto interactive

:runfile
set "script=%~1"
shift
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
goto :eof

:interactive
start "" "%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass
goto :eof
'@

# --- create directory --------------------------------------------------------
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# --- write shim only when content changed -----------------------------------
$rewrite = (-not (Test-Path $file)) -or ((Get-Content $file -Raw) -ne $body)
if ($rewrite) {
    $enc = if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -ge 7) {
        'UTF8NoBOM'
    } else {
        'Ascii'
    }
    Set-Content -Path $file -Value $body -Encoding $enc
    $fileState = 'written/updated'
} else {
    $fileState = 'up-to-date'
}

# --- ensure C:\Tools is in PATH ---------------------------------------------
$parts = [Environment]::GetEnvironmentVariable('Path','Machine') -split ';'
if ($parts -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', ($parts + $dir) -join ';','Machine')
    $pathState = 'added to PATH (open new shell)'
} else {
    $pathState = 'PATH already contained C:\Tools'
}

Write-Host "pws.cmd $fileState -- $pathState"
