# PWS Shim

A 4-line batch wrapper that streamlines two PowerShell launch patterns:

| Command | Result |
|---------|--------|
| `pws` | Opens a **new** console window (prefers `pwsh.exe` 7, falls back to `powershell.exe` 5.1). |
| `pws <script.ps1> [args]` | Runs the script in the **current** console with identical flags. |

Flags always used: `-NoLogo -NoProfile -ExecutionPolicy Bypass`.

---

## How it works

* **Location** – shim lives at **`C:\Tools\pws.cmd`**  
  * First loop searches common `pwsh.exe` paths, then defaults to the inbox 5.1 engine.  
  * Label flow (`goto`) prevents early `%variable%` expansion.
* **Installer** – `Install-PwsShim.ps1`  
  * Self-elevates once (`Run as Administrator`, `-NoExit`).  
  * Writes/updates `pws.cmd` **only when content differs** (idempotent).  
  * Adds `C:\Tools` to the machine PATH exactly once—no duplicates.

---

## Installation

```powershell
# any console – script self-elevates if required
.\Install-PwsShim.ps1
```

Open a **new** shell afterwards so the updated PATH is loaded.

---

## Usage examples

```console
C:\> pws
# → new pwsh window if available; otherwise Windows PowerShell

C:\> pws .\deploy.ps1 -Stage Prod
# → executes deploy.ps1 in the current window

C:\> pws -
# → executes script piped via STDIN
```

---

## Uninstall

1. Remove `C:\Tools\pws.cmd`.  
2. Delete `C:\Tools` from the machine PATH if you no longer need it.  
3. Close and reopen any consoles.
