# PWS Shim

A minimal wrapper that short-hands two common PowerShell invocation patterns.

---

## Features

* **Dual-mode behaviour**
  * `pws` → interactive PowerShell (`-NoLogo -NoProfile -ExecutionPolicy Bypass`).
  * `pws <script.ps1> [args]` → same flags, plus `-File <script>`.

* **Global availability**
  * Installs `pws.cmd` in **`C:\Tools`**.
  * Adds **`C:\Tools`** to the machine-wide **PATH** if missing.

* **Self-elevating installer with persistent window**
  * `Install-PwsShim.ps1` relaunches itself as *Run as Administrator*  
    (using `-NoExit`) when necessary, so the elevated console stays open.

---

## Installation

```powershell
# From any console – elevation handled automatically
.\Install-PwsShim.ps1
