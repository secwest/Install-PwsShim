# PWS Shim

`pws.cmd` is a four-line batch wrapper that standardises two PowerShell launch
patterns and makes them available system-wide.

| Command                         | Result |
|---------------------------------|--------|
| `pws`                           | Opens a **new** console window.<br>Uses **pwsh 7** if present, otherwise Windows PowerShell 5.1. |
| `pws <script.ps1> [args]`       | Runs the script in the **current** console. |

Both modes run with the flags:

```
-NoLogo -NoProfile -ExecutionPolicy Bypass
```

---

## How it works

* **Shim location** – `C:\Tools\pws.cmd`
* **Engine preference** – first `pwsh.exe` found in common locations or on
  `PATH`; falls back to the inbox 5.1 executable.
* **Label flow** – `goto` blocks ensure variables expand only after they are
  set, avoiding delayed-expansion quirks.

---

## Installation

### A. Local copy (recommended)

```powershell
# any console – the installer self-elevates if required
.\Install-PwsShim.ps1
```

### B. Stream directly from GitHub

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -Command "iwr -UseBasicParsing 'https://raw.githubusercontent.com/secwest/Install-PwsShim/refs/heads/main/Install-PwsShim.ps1' | iex"
```

Open a **new** shell after installation so the updated PATH is loaded.

---

## Usage examples

```console
C:\> pws
# → new pwsh window (if installed)

C:\> pws .\deploy.ps1 -Stage Prod
# → runs deploy.ps1 in current window

C:\> pws -
# → executes script piped via STDIN
```

---

## Flags, security notes, customisation

### 1. Flags the shim always passes

| Flag | Meaning | Why it is used | Caveats |
|------|---------|---------------|---------|
| `-NoLogo` | Hides banner text. | Cleaner output. | None. |
| `-NoProfile` | Skips all profile scripts. | Deterministic startup; avoids broken profiles. | No profile aliases/module autoloads. |
| `-ExecutionPolicy Bypass` | Ignores local policy for this process. | Works the same on dev boxes and locked-down servers. | Any script will run; use a stricter policy if untrusted code can reach `pws`. |

#### Why *Bypass* can be risky

* Does **not** disable AMSI, Defender, or AppLocker.
* Does ignore GPO/registry policy and zone identifiers.
* Acceptable for controlled pipelines; risky on multi-user hosts.

### 2. Changing defaults

* **Change policy**

  ```batch
  -NoLogo -NoProfile -ExecutionPolicy RemoteSigned
  ```

* **Load profiles only in interactive mode**

  ```batch
  if "%~1"=="" (
      start "" "%PS%" -NoLogo -ExecutionPolicy Bypass
  ) else (
      ...
  )
  ```

* **Extra flags**

  * `-WorkingDirectory <path>`
  * `-WindowStyle Hidden`
  * `-Command "<one-liner>"`

Update the here-string in *Install-PwsShim.ps1* and re-run the installer; it
overwrites the shim only when the content changed.

### 3. Safe-usage checklist

1. Use signed or trusted scripts if you keep *Bypass*.
2. Adjust probe order if multiple pwsh builds are installed.
3. No special AV exclusions are needed; AMSI still scans.
4. Redirect output if you need transcripts; `pws` inherits parent logging.
5. `pws` does not auto-elevate; child shells keep caller privileges.

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

| Environment type | Recommended policy |
|------------------|--------------------|
| Single-user dev box | Defaults are fine (`Bypass`). |
| Build agent (trusted repos) | Defaults are fine. |
| Shared jump box / multi-tenant server | `RemoteSigned` or `AllSigned`; maybe load profiles in interactive mode. |
| Air-gapped environment | Keep `Bypass`, but sign scripts to track provenance. |
