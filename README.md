# Intune Winget Management Toolkit

A flexible PowerShell toolkit for deploying, uninstalling, and automatically maintaining software via the **Windows Package Manager (Winget)** in **Microsoft Intune**.

---

## 📁 Repository Structure

```text
.
├── Detection-Script/
│   └── Detect-WingetApp.ps1
│
├── Install-Uninstall-Script/
│   ├── intune-package/
│   │   └── Manage-WingetApp.intunewin
│   └── source/
│       └── Manage-WingetApp.ps1
│
└── Maintenance-Script/
    ├── all/
    │   ├── Detection-WingetUpdates.ps1
    │   └── Remediation-WingetUpdates.ps1
    ├── auto/
    │   ├── Detection-WingetUpdates.ps1
    │   └── Remediation-WingetUpdates.ps1
    └── specified/
        ├── Detection-WingetUpdates.ps1
        └── Remediation-WingetUpdates.ps1
```
## 📁 Logging & Local Database Paths

To ensure transparency during deployment and enable tracking for automated updates, the framework stores logs and inventory state in a central location on the client endpoint (`C:\ProgramData\IntuneWingetManagement\`).

### Path Definitions

* **Log Directory:** `C:\ProgramData\IntuneWingetManagement\Logs`
* **Inventory Database:** `C:\ProgramData\IntuneWingetManagement\WingetInventory.json`

---

### Functionality

1. **Centralized Logging**
   All installation, uninstallation, detection, and remediation events are logged here with timestamps. This is essential for troubleshooting issues directly on client endpoints.

2. **JSON Inventory Database (`WingetInventory.json`)**
   - Automatically generated/updated when apps are installed/uninstalled via `Manage-WingetApp.ps1`.
   - Stores metadata (such as `AppID`, installation date, and `InstallerType`) for every application deployed through this framework.
   - Serves as the single source of truth for the **`auto/` maintenance mode**, ensuring that auto-updates only apply to managed applications without interfering with software installed manually by users.


# Components & Script Description
When configuring Intune Win32 Apps or Proactive Remediations, always set "Run script as 32-bit process on 64-bit clients" to `No`.
Running under 32-bit PowerShell causes path redirection errors for `%ProgramFiles%`, registry lookup failures `(missing standard HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall keys)`, and context mismatches when interacting with `winget.exe` in the `SYSTEM` context.

## 1. Detection-Script
` Detect-WingetApp.ps1`
- Purpose: Custom Intune detection script used to verify whether a specific application is already installed on the endpoint.

### Configuration:
Before using this in Intune, the `$AppId` variable must be adjusted directly inside the `Detect-WingetApp.ps1` file for the respective application (e.g., `$AppID = "Notepad++.Notepad++"` or $AppID = "VideoLAN.VLC").

## 2. Install & Uninstall Script

`Manage-WingetApp.ps1`

- Purpose: Universal Win32 App deployment script that handles both the installation and uninstallation of specified Winget packages.

#### Script Parameters

| Parameter | Required | Type | Allowed Values | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-Action` | **Yes** | String | `Install`, `Uninstall` | Defines whether to install or remove the specified application. |
| `-AppId` | **Yes** | String | *String* | The exact Winget package ID (e.g., `Notepad++.Notepad++`). |
| `-InstallerType` | **No** | String | `wix`, `nullsoft`, `msi`, `exe`, `inno`, `burn`, `msix`, `portable`, `zip` | Overrides/forces a specific installer architecture during installation. |
| `-CustomUninstallString` | **No** | String | *String* | Custom uninstallation command line used as a fallback if Winget uninstallation fails or isn't supported. |

---
  
- Example (Notepad++, VLC):
  - Install without InstallerType
    ```
    powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Install -AppId "Notepad++.Notepad++"
    ```
  - Install with InstallerType
    ```
    powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Install -AppId "Notepad++.Notepad++" -InstallerType "wix"
    ```
    In some cases it is better to use a custom InstallerType:
    - Bypass Default Installer Conflicts: Winget packages sometimes default to installer formats (like `.msi` or generic `.exe`) that may fail in the Intune `SYSTEM` context or trigger unwanted reboot prompts. Specifying an explicit type (e.g., `nullsoft` for NSIS-based installers like VLC) forces Winget to download and parse the exact installer framework required for clean, silent deployments.
    - Ensure Silent Execution: Certain Winget manifests do not pass the correct silent flags by default for all available installer types. Forcing a specific installer type (e.g., `inno`, `wix`, or `msi`) guarantees that Winget applies the matching standardized quiet switches (`/VERYSILENT`, `/qn`, etc.).
    - Target Specific Application Architectures: When an application provides multiple installer architectures under a single Winget ID, overriding the installer type helps ensure the script deploys the intended binary build reliably across all managed endpoints.
    
  - Uninstall:
    ```
    powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Uninstall -AppId "Notepad++.Notepad++"
    ```
    - Sometimes it is better to use the original application uninstaller method, like this (especially VideoLAN.VLC). The script also attempts to locate an uninstallation method locally (in case Winget or a custom command fails).
        ```
        powershell.exe -ExecutionPolicy Bypass -File .\Manage-WingetApp.ps1 -Action unInstall -AppId "VideoLAN.VLC" -CustomUninstallString '"%ProgramFiles%\VideoLAN\VLC\uninstall.exe" /S'
        ```

`Manage-WingetApp.intunewin
`
- Purpose: Pre-packaged .intunewin file ready for direct upload to the Microsoft Intune Admin Center (win32-APP).

## 3. Maintenance Scripts (Intune Proactive Remediations)

The `Maintenance-Script/` folder contains script pairs designed for **Microsoft Intune Proactive Remediations**. These scripts automate software patch management via WinGet across your endpoints.

The framework provides **three distinct deployment modes** depending on your update strategy:

```
└── Maintenance-Script/
    ├── all/
    │   ├── Detection-WingetUpdates.ps1
    │   └── Remediation-WingetUpdates.ps1
    ├── auto/
    │   ├── Detection-WingetUpdates.ps1
    │   └── Remediation-WingetUpdates.ps1
    └── specified/
        ├── Detection-WingetUpdates.ps1
        └── Remediation-WingetUpdates.ps1
```
### Update Modes Overview
1. `all/` ** Full System Upgrade **
   - Scope: Upgrades all WinGet-supported applications installed on the endpoint.
   - Behavior: Runs `winget upgrade --all` to keep all software updated regardless of how it was originally installed.
2. `auto/` ** Managed Applications Only ** (recommended)
   - Scope: Upgrades only applications that were deployed via this framework.
   - Behavior: Checks against a local JSON tracking database created during app deployment. Unmanaged or user-installed software is ignored.
3. `specified/` ** Targeted Application List **
   - Scope: Upgrades a curated list of applications.
   - Behavior: Targets only specific AppID entries hardcoded inside an array within the script (e.g., `$appsToUpdate` = @("7zip.7zip", "Google.Chrome")).

# Author & License
- Author: manuel-stgr
- License: Distributed under the MIT License. See LICENSE for details.

