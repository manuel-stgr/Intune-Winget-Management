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


# Components & Script Description
When configuring Intune Win32 Apps or Proactive Remediations, always set "Run script as 32-bit process on 64-bit clients" to `No`.
Running under 32-bit PowerShell causes path redirection errors for `%ProgramFiles%`, registry lookup failures `(missing standard HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall keys)`, and context mismatches when interacting with `winget.exe` in the `SYSTEM` context.

## 1. Detection-Script
` Detect-WingetApp.ps1
`
- Purpose: Custom Intune detection script used to verify whether a specific application is already installed on the endpoint.

###Configuration:
Before using this in Intune, the `$AppId` variable must be adjusted directly inside the `Detect-WingetApp.ps1` file for the respective application (e.g., $AppID = "Notepad++.Notepad++" or $AppID = "VideoLAN.VLC").

## 2. Install & Uninstall Script

###`Manage-WingetApp.ps1`

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
  - Install, with or without Installer-Type:
    ```
    powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Install -AppId "Notepad++.Notepad++" -InstallerType "wix"
    ```
    ```
    powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Install -AppId "Notepad++.Notepad++"
    ```
    - In the case of VLC, it is better to use the InstallerType nullsoft (exe).
      ```
      "powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Install -AppId "VideoLAN.VLC" -InstallerType "nullsoft"
      ```
    
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

## 3. Maintenance Scripts (Intune Remediation)
`
Detection-WingetUpdates.ps1
`
- Purpose: Serves as the detection rule for Intune Proactive Remediations. Checks if pending software updates are available via Winget.

`
Remediation-WingetUpdates-All.ps1
`
- Purpose: Triggers a full system update for all installed applications supported by Winget (winget upgrade --all).

`
Remediation-WingetUpdates-Specified.ps1
`
- Purpose: Performs targeted updates, upgrading only the specific application IDs defined within the script array.

# Author & License
- Author: manuel-stgr
- License: Distributed under the MIT License. See LICENSE for details.

