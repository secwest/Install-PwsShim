# PWS Shim — Usage & Execution-Policy Notes

`pws` is a wrapper that starts PowerShell with fixed flags.  
Those flags matter for security, automation repeatability, and user
experience. Read this once before deploying.

---

## Quick recap

| Invocation | Behaviour | Flags passed |
|------------|-----------|--------------|
| `pws` | Opens a new console window | `-NoLogo -NoProfile -ExecutionPolicy Bypass` |
| `pws <script.ps1> [args]` | Runs `<script.ps1>` in the current console | same |

*Engine Preference* – The shim uses **`pwsh.exe` 7 +** when found;
otherwise it falls back to Windows PowerShell 5.1.

---

## Flag explanations

| Flag | What it does | Impact |
|------|--------------|--------|
| `-NoLogo` | Hides the banner text. | Cleaner logs, no side effects. |
| `-NoProfile` | Skips all profile scripts (`AllUsers` + `CurrentUser`). | Deterministic startup; custom aliases/modules in profiles are unavailable. |
| `-ExecutionPolicy Bypass` | Ignores the local execution-policy check *for this process only*. | Any script will run; AMSI, antivirus, and AppLocker remain active. |

### Alternate execution-policy values

| Policy | Typical use |
|--------|-------------|
| `Restricted` | Blocks all scripts; interactive only. |
| `AllSigned` | Runs scripts **only** if they are digitally signed and trusted. |
| `RemoteSigned` | Local scripts run freely; scripts from the internet must be signed. |
| `Unrestricted` | Runs any script but prompts for approval on remote code. |
| `Bypass` | No policy check, no prompts. |
| `Undefined` | Uses the effective policy from GPO or registry. |

---

## Practical guidance

* **Automation pipelines / build agents**  
  *Bypass* is common; the script set is controlled and transient.
* **Shared jump boxes, multi-user servers**  
  Use *RemoteSigned* or *AllSigned* to prevent opportunistic script drops.
* **Interactive day-to-day use**  
  Keep *Bypass* for convenience, but run only trusted code.

Changing the policy is a one-line edit in the shim; pick what fits your risk
model before distributing to others.

---

## Path & removal

* The shim is installed at **`C:\Tools\pws.cmd`**.  
* `C:\Tools` is appended to the system **PATH** so `pws` resolves everywhere.

To remove: delete `pws.cmd` and drop `C:\Tools` from PATH, then restart any
open shells.
