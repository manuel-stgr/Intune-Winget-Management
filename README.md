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
    ├── Detection-WingetUpdates.ps1
    ├── Remediation-WingetUpdates-All.ps1
    └── Remediation-WingetUpdates-Specified.ps1
```


# Components & Script Description
When configuring Intune Win32 Apps or Proactive Remediations, always set "Run script as 32-bit process on 64-bit clients" to `No`.
Running under 32-bit PowerShell causes path redirection errors for `%ProgramFiles%`, registry lookup failures `(missing standard HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall keys)`, and context mismatches when interacting with `winget.exe` in the `SYSTEM` context.

## 1. Detection-Script
` Detect-WingetApp.ps1
`
- Purpose: Custom Intune detection script used to verify whether a specific application is already installed on the endpoint.

## 2. Install & Uninstall Script
`Manage-WingetApp.ps1
`
- Purpose: Universal Win32 App deployment script that handles both the installation and uninstallation of specified Winget packages.
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
    - Sometimes it is better to use the original application uninstaller method, like this (especially VideoLAN.VLC):
        ```
        "%ProgramFiles%\VideoLAN\VLC\uninstall.exe" /S
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

