# PWS PowerShell Launch Shim

`pws.cmd` is a small batch wrapper plus a one-time installer that
standardises two PowerShell launch patterns and places them on every shell in
Windows.

| Command | Result |
|---------|--------|
| `pws` | Opens a **new** console window (prefers **pwsh 7**, otherwise Windows PowerShell 5.1). |
| `pws <script.ps1> [args]` | Runs the script in the **current** console. |

Both modes always supply:

```
-NoLogo -NoProfile -ExecutionPolicy Bypass
```

---

## 1  What the installer (`Install-PwsShim.ps1`) does

| Step | Action |
|------|--------|
| 1 | **Self-elevates** via *Run as Administrator* (`-NoExit` keeps the summary visible). |
| 2 | Builds `C:\Tools\pws.cmd` from an internal here-string.<br> • Prefers the first **`pwsh.exe` 7** it finds.<br> • Falls back to the inbox **PowerShell 5.1** executable. |
| 3 | Writes/rewrites **only if file content changed** (idempotent). |
| 4 | Adds **`C:\Tools`** to the machine `PATH` if missing. |
| 5 | Prints whether the file was written/updated and whether `PATH` was touched. |

Re-running the installer when nothing has changed exits after step 1.

---

## 2  Inside the shim

```batch
@echo off
setlocal
rem -- pick engine: first pwsh 7, else Windows PowerShell 5.1 -------------
for %%P in ("%ProgramFiles%\PowerShell\pwsh.exe" ^
            "%ProgramFiles%\PowerShell\7\pwsh.exe" ^
            "%ProgramFiles%\PowerShell\7-preview\pwsh.exe" ^
            "pwsh.exe") do (
    if not defined PS if exist "%%~P" set "PS=%%~P"
)
if not defined PS set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

rem -- branch on argument count ------------------------------------------
if "%~1"=="" goto interactive

:runfile
set "script=%~1"
shift
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
goto :eof

:interactive
start "" "%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass
goto :eof
```

* **Label flow** guarantees `%script%` expands after it’s set—no delayed
  expansion required.
* `start` creates a detached window for interactive sessions; scripts stay in
  the parent window.

---

## 3  Installation methods

### A Local copy (recommended)

```powershell
# any console – auto-elevates if necessary
.\Install-PwsShim.ps1
```

### B Stream directly from GitHub (no file on disk first)

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -Command "iwr -UseBasicParsing 'https://raw.githubusercontent.com/secwest/Install-PwsShim/refs/heads/main/Install-PwsShim.ps1' | iex"
```

Open a **new** shell afterward so the updated `PATH` is loaded.

---

## 4  Using the shim

```console
C:\> pws
# → new pwsh window if installed, else 5.1

C:\> pws .\deploy.ps1 -Stage Prod
# → runs deploy.ps1 in the same window

C:\> pws -
# → executes script piped via STDIN
```

---

## 5  Flags, security notes, customisation

### 5.1  Flags always passed

| Flag | Meaning | Rationale | Caveats |
|------|---------|-----------|---------|
| `-NoLogo` | Suppresses banner text. | Cleaner logs and pipelines. | None. |
| `-NoProfile` | Skips **all** profile scripts (`AllUsers*`, `CurrentUser*`). | Deterministic startup; avoids crashes from broken profiles. | No aliases or module autoloads from profiles. |
| `-ExecutionPolicy Bypass` | Ignores local execution-policy check *for this process only*. | Works the same on dev boxes, build agents, and locked-down servers. | Any script runs; use a stricter policy if untrusted code can reach `pws`. |

**Why *Bypass* can be risky**

* Does **not** disable AMSI, Defender, or AppLocker.  
* Does ignore GPO/registry policy and zone identifiers.  
* Acceptable for CI pipelines; riskier on multi-user hosts.

### 5.2  Running profile scripts manually

`-NoProfile` blocks PowerShell’s automatic loading sequence.  
Dot-source only what you need:

```powershell
. $PROFILE                       # current user + current host
. $PROFILE.CurrentUserAllHosts   # user-wide for all hosts
. $PROFILE.AllUsersAllHosts      # system-wide for all hosts
```

Reload *all* four in startup order:

```powershell
foreach ($p in $PROFILE.AllUsersAllHosts,
                 $PROFILE.AllUsersCurrentHost,
                 $PROFILE.CurrentUserAllHosts,
                 $PROFILE.CurrentUserCurrentHost) {
    if (Test-Path $p) { . $p }
}
```

### 5.3  Changing defaults

* **Different policy**

  ```batch
  -NoLogo -NoProfile -ExecutionPolicy RemoteSigned
  ```

* **Load profiles only when interactive**

  ```batch
  if "%~1"=="" (
      start "" "%PS%" -NoLogo -ExecutionPolicy Bypass   &rem profiles load here
  ) else (
      ...
  )
  ```

* **Extra flags**

  * `-WorkingDirectory <path>`
  * `-WindowStyle Hidden`
  * `-Command "<one-liner>"`

Edit the here-string in `Install-PwsShim.ps1`; rerun the installer—it rewrites
only if content changed.

### 5.4  Safe-usage checklist

1. Signed or trusted scripts if you keep *Bypass*.  
2. Adjust probe order if multiple pwsh versions exist.  
3. No AV exclusions needed; AMSI stays active.  
4. Redirect output if you need transcripts—`pws` inherits parent logging.  
5. The shim does **not** auto-elevate; child shells keep caller privilege.

---

## 6  Recovery / rollback

```powershell
Remove-Item C:\Tools\pws.cmd
$envPath = [Environment]::GetEnvironmentVariable('Path','Machine') -split ';' |
           Where-Object { $_ -ne 'C:\Tools' } -join ';'
[Environment]::SetEnvironmentVariable('Path',$envPath,'Machine')
# log off or open a new shell
```

Re-run *Install-PwsShim.ps1* any time to recreate the shim.

---

## 7  Quick policy guide

### Alternate execution-policy values

| Policy | Typical use |
|--------|-------------|
| `Restricted` | Blocks all scripts; interactive only. |
| `AllSigned` | Runs scripts **only** if they are digitally signed and trusted. |
| `RemoteSigned` | Local scripts run freely; scripts from the internet must be signed. |
| `Unrestricted` | Runs any script but prompts for approval on remote code. |
| `Bypass` | No policy check, no prompts. |
| `Undefined` | Uses the effective policy from GPO or registry. |


| Environment | Recommended execution policy |
|-------------|-----------------------------|
| Solo dev box | `Bypass` |
| Build agent (trusted repos) | `Bypass` |
| Shared / multi-tenant server | `RemoteSigned` or `AllSigned`; optionally load profiles in interactive sessions only. |
| Air-gapped environment | `Bypass`, but sign scripts to track provenance. |
