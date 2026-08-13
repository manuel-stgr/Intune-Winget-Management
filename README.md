# Intune-Winget-Management
A flexible PowerShell toolkit for deploying, uninstalling, and automatically maintaining software via the Windows Package Manager (Winget) in Microsoft Intune (also possible for On-Prem-AD).

#Repository Structure
.
├── Detecion-Script/
│   └── Detect-WingetApp.ps1
│
├── Install-UNinstall-Script/
│   ├── intune-package/
│   │   └── Manage-WingetApp.intunewin
│   └── source/
│       └── Manage-WingetApp.ps1
│
└── Maintance-Script/
    ├── Detection-WingetUpdates.ps1
    ├── Remediation-WingetUpdates-All.ps1
    └── Remediation-WingetUpdates-Specified.ps1

# Components & Script Description
## Detection-Script
