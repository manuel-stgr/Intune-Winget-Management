<#
.SYNOPSIS
    Installs targeted updates via Winget.
 
.DESCRIPTION
    Installs updates only for a specific list of defined Winget application IDs.

.NOTES
  Version:        1.0
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
  Purpose/Change: Creation
#>

[CmdletBinding()]
param (
    [string]$LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Winget-AutoUpdate.log"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    
    $logDir = Split-Path $LogPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

Write-Log "=========================================="
Write-Log "Starting targeted Winget update process"

# ---------------------------------------------------------------------------
# 0. 64-bit PowerShell Redirection
# ---------------------------------------------------------------------------
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    & "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit $LASTEXITCODE
}

# ---------------------------------------------------------------------------
# 1. Define allowed applications (Winget App IDs)
# ---------------------------------------------------------------------------
$appsToUpdate = @(
    "Mozilla.Firefox",
    "VideoLAN.VLC",
    "Notepad++.Notepad++"
    # Add additional Winget IDs here.
)

# ---------------------------------------------------------------------------
# 2. Determine the path to winget.exe
# ---------------------------------------------------------------------------

$wingetExe = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe) {
    Write-Log "winget.exe not Found!" "ERROR"
    exit 1
}

# ---------------------------------------------------------------------------
# 3. Execute Updates for defined apps
# ---------------------------------------------------------------------------

$hasErrors = $false

foreach ($appId in $appsToUpdate) {
    Write-Log "Checking/Updating application: $appId"

    $upgradeArgs = @(
        "upgrade",
        "--exact",
        "--id", $appId,
        "--silent",
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--include-unknown"
    )

    $process = Start-Process -FilePath $wingetExe -ArgumentList $upgradeArgs -Wait -NoNewWindow -PassThru

    # Successfully updated, 0x8A15001C (-1978335204) = No update availablear
    if ($process.ExitCode -eq 0) {
        Write-Log "Successfully updated: $appId" "SUCCESS"
    } elseif ($process.ExitCode -eq -1978335204) {
        Write-Log "No update available or app not installed: $appId" "INFO"
    } else {
        Write-Log "Failed to update $appId with exit code: $($process.ExitCode)" "WARN"
        $hasErrors = $true
    }
}

if ($hasErrors) {
    Write-Log "Maintenance completed with some errors." "WARN"
} else {
    Write-Log "All defined applications processed successfully." "SUCCESS"
}

exit 0
