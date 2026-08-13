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
## Detection-Script
```text 
Detect-WingetApp.ps1
```
