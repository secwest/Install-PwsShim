# Install-PwsShim.ps1 – What It Does and How to Use It

`Install-PwsShim.ps1` is a one-time helper that **adds a tiny launcher,
`pws.cmd`, to C:\Tools and makes sure that folder is on the system PATH**.
Run it once, open a new shell, and you can type `pws` anywhere.

---

## 1 What the installer script does, step by step

| Step | Action |
|------|--------|
| 1 | **Self-elevates** with `Run as Administrator` (using `-NoExit` so you can read the summary). |
| 2 | Builds the batch **shim** and stores it in `C:\Tools\pws.cmd`. |
| 3 | Adds `C:\Tools` to the *machine* PATH if it is not already there. |
| 4 | Prints `pws.cmd written/updated -- added to PATH …` or an “up-to-date” message. |

> **Idempotent:** if the file content and PATH entry already match, the script
> exits after step 1 with no changes.

---

## 2 What the shim itself does

```text
pws               → opens a new PowerShell window
pws <file.ps1> …  → runs the script in the current window
```

Both modes run with these flags:

* `-NoLogo` – no banner text
* `-NoProfile` – ignore user/system profiles
* `-ExecutionPolicy Bypass` – skip the local policy check

### Engine preference

1. Looks for **pwsh.exe 7+** in common install locations and on PATH.  
2. Falls back to **Windows PowerShell 5.1** (`%SystemRoot%\System32\…`).

### Why label flow (`goto`) is used

Batch variables expand when the line is parsed.  
By jumping to labels *after* setting variables (`script`, `PS`), we guarantee
the correct values are used without delayed expansion quirks.

---

## 3 Security & flag options

| Flag | Default | Alternate choices |
|------|---------|-------------------|
| `-ExecutionPolicy` | `Bypass` (no policy check) | `RemoteSigned`, `AllSigned`, `Undefined`, `Restricted` |
| `-NoProfile` | Enabled | Remove it if you need profile functions/aliases in interactive mode. |

To change flags: edit the here-string in **Install-PwsShim.ps1**, rerun the
installer; it will overwrite the shim because the content changed.

---

## 4 Install / verify / uninstall

### Install

```powershell
# any console – elevation handled automatically
.\Install-PwsShim.ps1
# open a new shell
```

### Verify

```console
C:\> pws
# → new pwsh window (if pwsh 7 present)

C:\> pws .\hello.ps1 arg1 arg2
# → hello.ps1 runs in current window
```

### Uninstall

```powershell
Remove-Item C:\Tools\pws.cmd
$envPath = [Environment]::GetEnvironmentVariable('Path','Machine') -split ';' |
           Where-Object { $_ -ne 'C:\Tools' } -join ';'
[Environment]::SetEnvironmentVariable('Path',$envPath,'Machine')
# log off or open a new shell
```

---

## 5 Summary

* One installer, one batch file, one PATH entry – nothing else.
* Safe to re-run; makes no changes when the system is already configured.
* Works on any Windows box with PowerShell 5.1; automatically uses PowerShell 7
  when available.
