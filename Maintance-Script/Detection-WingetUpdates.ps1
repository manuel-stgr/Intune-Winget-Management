<#
.SYNOPSIS
   Checks if Winget-APP updates are available.
 
.DESCRIPTION
  First, it is checked whether the specified hour has passed; the check for winget updates (ALL) only takes place from that point onwards.
 
.NOTES
  Version:        1.0
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
  Purpose/Change: Creation
#>

# ---------------------------------------------------------------------------
# 0. 64-bit PowerShell Redirection
# ---------------------------------------------------------------------------
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    & "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit $LASTEXITCODE
}


# ---------------------------------------------------------------------------
# 1. Time window check (14:00 to 24:00)
# ---------------------------------------------------------------------------
$currentHour = (Get-Date).Hour
$startHour = 14

if ($currentHour -lt $startHour) {
    # Outside the maintenance window -> No action required for Intune
    Write-Host "Time ($(Get-Date -Format 'HH:mm')) is before 2:00 PM. Maintenance skipped."
    exit 0
}

# ---------------------------------------------------------------------------
# 2. Determine winget.exe path 
# ---------------------------------------------------------------------------
$wingetExe = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe -or -not (Test-Path $wingetExe)) {
    Write-Host "winget.exe not found."
    exit 0
}

# ---------------------------------------------------------------------------
# 3. Check for available updates
# ---------------------------------------------------------------------------
# Silently update package sources
& $wingetExe source update --accept-source-agreements | Out-Null

# Check whether 'winget upgrade' lists applications.
$upgradeList = & $wingetExe upgrade --accept-source-agreements

# If the text contains "available updates" or version comparisons:
if ($upgradeList -match "v\d+\.\d+" -or $upgradeList -match "Upgrade" -or $upgradeList -match "available") {
    Write-Host "Updates are available, and we are within the scheduled time window."
    # Exit code 1 signals to Intune: Action required! Start remediation script.
    exit 1
} else {
    Write-Host "All apps are up to date."
    # Exit code 0 signals to Intune: Everything is fine, no action required.
    exit 0
}