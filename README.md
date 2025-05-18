# PWS Shim

A tiny wrapper that abbreviates two common PowerShell launch patterns.

---

## Features

* **Dual-mode behaviour**
  * `pws` → interactive PowerShell (`-NoLogo -NoProfile -ExecutionPolicy Bypass`).
  * `pws <script.ps1> [args]` → same flags, plus `-File <script>`.

* **Global availability**
  * Installs `pws.cmd` in **`C:\Tools`**.
  * Adds **`C:\Tools`** to the machine-wide **PATH** if missing.

* **Self-elevating installer (window remains open)**
  * `Install-PwsShim.ps1` relaunches itself via *Run as Administrator*  
    using `-NoExit`, so the elevated console stays open for review.

* **Robust batch logic**
  * Uses label flow (`goto`) to avoid `%variable%` expansion timing bugs—no
    delayed-expansion quirks, no duplicate script arguments.

---

## Installation

```powershell
# From any console – the script will self-elevate if necessary
.\Install-PwsShim.ps1
