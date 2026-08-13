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
## 1. Detection-Script
` Detect-WingetApp.ps1
`
Purpose: Custom Intune detection script used to verify whether a specific application is already installed on the endpoint.

## 2. Install & Uninstall Script
```text 
Manage-WingetApp.ps1
```
- Purpose: Universal Win32 App deployment script that handles both the installation and uninstallation of specified Winget packages.

```text 
Manage-WingetApp.intunewin
```
- Purpose: Pre-packaged .intunewin file ready for direct upload to the Microsoft Intune Admin Center (win32-APP).

## 3. Maintenance Scripts (Intune Remediation)
```text 
Detection-WingetUpdates.ps1
```
- Purpose: Serves as the detection rule for Intune Proactive Remediations. Checks if pending software updates are available via Winget.

```text 
Remediation-WingetUpdates-All.ps1
```
- Purpose: Triggers a full system update for all installed applications supported by Winget (winget upgrade --all).

```text 
Remediation-WingetUpdates-Specified.ps1
```
- Purpose: Performs targeted updates, upgrading only the specific application IDs defined within the script array.

# Author & License
- Author: manuel-stgr
- License: Distributed under the MIT License. See LICENSE for details.

