# PWS Shim

A tiny batch wrapper that standardises two PowerShell launch patterns:

| Command | Result |
|---------|--------|
| `pws` | Opens a **new** console window (prefers `pwsh.exe` 7, falls back to Windows PowerShell 5.1). |
| `pws <script.ps1> [args]` | Runs the script in the **current** console. |

Flags always used in both modes:

```
-NoLogo -NoProfile -ExecutionPolicy Bypass
```

---

## Installation

```powershell
# any console – script self-elevates if required
.\Install-PwsShim.ps1
```

The installer:

* Creates or updates **`C:\Tools\pws.cmd`**.
* Adds **`C:\Tools`** to the machine **PATH** once.
* Runs idempotently – re-runs do nothing if state is already correct.

Open a **new** shell after the first install so the updated PATH is loaded.

---

## Usage examples

```console
C:\> pws
# → new pwsh window if installed

C:\> pws .\deploy.ps1 -Stage Prod
# → runs deploy.ps1 in the current window

C:\> pws -
# → executes script piped via STDIN
```

---

## Flag details, warnings, and customisation

### 1  Flags the shim always passes

| Flag | Meaning | Rationale | Caveats |
|------|---------|-----------|---------|
| `-NoLogo` | Suppresses banner text. | Cleaner logs and pipelines. | None. |
| `-NoProfile` | Skips all profile scripts. | Deterministic startup; avoids breakage from user profiles. | Custom aliases / autoloads are unavailable. |
| `-ExecutionPolicy Bypass` | Ignores local execution-policy check **for this process only**. | Works the same on dev boxes and locked-down servers without GPO edits. | **Security** – any script will run; use a stricter policy if untrusted code can hit `pws`. |

`Bypass` does **not** disable AMSI, Defender, or AppLocker, but it does ignore
registry / GPO policy and zone identifiers.

---

### 2  Changing the defaults

* **Different execution policy**

  ```batch
  -NoLogo -NoProfile -ExecutionPolicy RemoteSigned
  ```

  Edit the here-string in `Install-PwsShim.ps1`, then re-run the installer.

* **Load profiles in interactive mode only**

  ```batch
  if "%~1"=="" (
      start "" "%PS%" -NoLogo -ExecutionPolicy Bypass
  ) else (
      ...
  )
  ```

* **Extra flags**  
  `-WorkingDirectory <path>` (pwsh 7)  
  `-WindowStyle Hidden` (for scheduled tasks)  
  `-Command "<one-liner>"`

---

### 3  Safe-usage checklist

1. **Signed code or trusted repo** – if you keep `Bypass`, ensure only trusted
   scripts are reachable via `pws`.
2. **Version pinning** – shim picks the *first* `pwsh.exe` it finds; adjust the
   probe order if you run multiple side-by-side versions.
3. **Antivirus exclusions** – none needed; AMSI remains active.
4. **Logging** – the new-window path inherits the parent log settings; redirect
   if you need transcripts.
5. **Elevation** – `pws` itself does not auto-elevate; child shells run with the
   same privilege as the caller.

---

### 4  Recovery / rollback

```powershell
Remove-Item C:\Tools\pws.cmd
$envPath = [Environment]::GetEnvironmentVariable('Path','Machine') -split ';' |
           Where-Object { $_ -ne 'C:\Tools' } -join ';'
[Environment]::SetEnvironmentVariable('Path',$envPath,'Machine')
# log off or open a new shell
```

Re-run `Install-PwsShim.ps1` at any time to recreate the shim.

---

### 5  Quick reference

| Environment | Recommended policy |
|-------------|--------------------|
| Single-user dev box | Defaults are fine. |
| Build agent (trusted repos only) | Defaults are fine. |
| Shared jump box / multi-tenant server | Use `RemoteSigned` or `AllSigned`; consider loading profiles in interactive mode. |
| Air-gapped environment | Keep `Bypass`, but sign scripts to track provenance. |
