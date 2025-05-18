# PWS Shim

`pws.cmd` is a four-line batch wrapper that standardises two PowerShell launch
patterns and makes them available system-wide.

| Command | Result |
|---------|--------|
| `pws` | Opens a **new** console window.<br>Prefers **pwsh 7**; falls back to Windows PowerShell 5.1. |
| `pws <script.ps1> [args]` | Runs the script in the **current** console. |

Both modes use:

```
-NoLogo -NoProfile -ExecutionPolicy Bypass
```

---

## How it works

* **Shim path** `C:\Tools\pws.cmd` (added to machine PATH).  
* **Engine preference** first matching `pwsh.exe`; otherwise the inbox 5.1 engine.  
* **Label flow** `goto` avoids `%var%` pre-expansion; no delayed-expansion quirks.  
* **Installer** `Install-PwsShim.ps1` self-elevates once, rewrites only when the
  shim content or PATH entry changes (idempotent).

---

## Installation

### A. Local copy (recommended)

```powershell
# any console – auto-elevates if needed
.\Install-PwsShim.ps1
```

### B. Stream directly from GitHub

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -Command "iwr -UseBasicParsing 'https://raw.githubusercontent.com/secwest/Install-PwsShim/refs/heads/main/Install-PwsShim.ps1' | iex"
```

After either method open a **new** shell so PATH is refreshed.

---

## Usage examples

```console
C:\> pws
# → new pwsh window if installed

C:\> pws .\build.ps1 -Verbose
# → runs build.ps1 in current window

C:\> pws -
# → executes script piped via STDIN
```

---

## Flags, security notes, customisation

### 1 Flags always passed

| Flag | Meaning | Caveats |
|------|---------|---------|
| `-NoLogo` | Hides banner text. | None |
| `-NoProfile` | Skips *all* profile scripts. | Aliases/modules in profiles are not loaded. |
| `-ExecutionPolicy Bypass` | Disables the local execution-policy gate for this process. | Any script runs; AMSI/Defender/AppLocker remain active. |

**Why *Bypass* matters**

* Ignores GPO/registry policy and zone identifiers.  
* Fine for controlled CI agents; risky on multi-user hosts.

### 2 Running profile scripts manually

`-NoProfile` stops PowerShell from loading these four files at start-up:

| Variable | Scope |
|----------|-------|
| `$PROFILE.AllUsersAllHosts` |
| `$PROFILE.AllUsersCurrentHost` |
| `$PROFILE.CurrentUserAllHosts` |
| `$PROFILE.CurrentUserCurrentHost` (alias `$PROFILE`) |

Dot-source whichever ones you need after `pws` launches:

```powershell
. $PROFILE.CurrentUserAllHosts           # user-wide tweaks
. $PROFILE                               # user + current host
```

To reload *all* profiles in the usual order:

```powershell
foreach ($p in $PROFILE.AllUsersAllHosts,
                 $PROFILE.AllUsersCurrentHost,
                 $PROFILE.CurrentUserAllHosts,
                 $PROFILE.CurrentUserCurrentHost) {
    if (Test-Path $p) { . $p }
}
```

### 3 Changing defaults

* **Different policy**

  ```batch
  -NoLogo -NoProfile -ExecutionPolicy RemoteSigned
  ```

* **Keep profiles in interactive mode**

  ```batch
  if "%~1"=="" (
      start "" "%PS%" -NoLogo -ExecutionPolicy Bypass   &rem profiles load
  ) else (
      ...
  )
  ```

* **Extra flags** – `-WorkingDirectory`, `-WindowStyle Hidden`, `-Command ...`

Edit the here-string in `Install-PwsShim.ps1`; re-run the installer.

### 4 Safe-usage checklist

1. Use trusted or signed scripts if you keep *Bypass*.  
2. Adjust probe order if multiple pwsh builds exist.  
3. No AV exclusions needed; AMSI still scans.  
4. Redirect output if you need transcripts; `pws` inherits parent logging.  
5. `pws` does **not** auto-elevate; child shells keep caller privilege.

---

## Recovery / rollback

```powershell
Remove-Item C:\Tools\pws.cmd
$envPath = [Environment]::GetEnvironmentVariable('Path','Machine') -split ';' |
           Where-Object { $_ -ne 'C:\Tools' } -join ';'
[Environment]::SetEnvironmentVariable('Path',$envPath,'Machine')
# log off or open a new shell
```

Re-run *Install-PwsShim.ps1* any time to recreate the shim.

---

## Quick policy reference

| Environment | Recommended policy |
|-------------|--------------------|
| Solo dev box | `Bypass` |
| Build agent (trusted repos) | `Bypass` |
| Shared / multi-tenant server | `RemoteSigned` or `AllSigned`; optionally load profiles in interactive mode only. |
| Air-gapped environment | `Bypass`, but sign scripts to track provenance. |
