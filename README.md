# PWS Shim

A minimal wrapper that short-hands two common PowerShell invocation patterns.

---

## Features

* **Dual-mode behaviour**
  * `pws` → interactive PowerShell (`-NoLogo -NoProfile -ExecutionPolicy Bypass`).
  * `pws <script.ps1> [args]` → same flags, plus `-File <script>`.

* **Global availability**
  * Installs `pws.cmd` in **`C:\Tools`**.
  * Adds **`C:\Tools`** to the machine-wide **PATH** (idempotent).

* **Self-elevating installer**
  * `Install-PwsShim.ps1` relaunches itself with *Run as Administrator* when required.

---

## Installation

```powershell
# Any console is fine – the script self-elevates if needed
.\Install-PwsShim.ps1
