<#
.SYNOPSIS
    Installs targeted updates via Winget.
 
.DESCRIPTION
    Installs updates only for a specific list of defined Winget application IDs.

.NOTES
  Version:        2.3
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-14
  Purpose/Change: remove Toast Message
#>

# ---------------------------------------------------------------------------
# Configuration Winget-AppIDs
# ---------------------------------------------------------------------------
$appsToUpdate = @(
    "Mozilla.Firefox",
    "VideoLAN.VLC",
    "Notepad++.Notepad++"
    # Add additional Winget IDs here.
)


# ---------------------------------------------------------------------------
# 64-bit PowerShell Redirection
# ---------------------------------------------------------------------------

if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    & "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit $LASTEXITCODE
}



# ---------------------------------------------------------------------------
# Logging Configuration
# ---------------------------------------------------------------------------

$LogDirectory = "$env:ProgramData\IntuneWingetManagement\Logs"
$LogPath      = "$LogDirectory\Winget-SepcifiedUpdate.log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry  = "[$TimeStamp] [$Level] $Message"
    
    Add-Content -Path $LogPath -Value $LogEntry -ErrorAction SilentlyContinue
    Write-Host $LogEntry -ForegroundColor $Color
}

Write-Log "==========================================" "INFO" "Gray"
Write-Log "Starting targeted Winget update process" "INFO" "Green"


# ---------------------------------------------------------------------------
# Determine the path to winget.exe
# ---------------------------------------------------------------------------

# 1. Check global WindowsApps directory first (works in SYSTEM & User contexts)
$wingetExe = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

# 2. Fallback: User AppData path
if (-not $wingetExe) {
    $wingetExe = Get-ChildItem -Path "$env:LocalAppData\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue | 
                 Sort-Object LastWriteTime -Descending | 
                 Select-Object -ExpandProperty FullName -First 1
}

# 3. Fallback: PATH environment lookup
if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

# Validation and exit handling
if (-not $wingetExe -or -not (Test-Path $wingetExe)) {
    # WinGet not Found -> App is considered non-existent.
    Write-Log "Couldn't find Winget on the host."
    exit 1
}



# ---------------------------------------------------------------------------
# Execute Updates for defined apps
# ---------------------------------------------------------------------------


$hasErrors = $false

foreach ($appId in $appsToUpdate) {
    Write-Log "Checking/Updating application: $appId"

    $upgradeArgs = @(
        "upgrade",
        "--exact",
        "--id", $appId,
        "--silent",
        "--disable-interactivity",
        "--force",
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--include-unknown"
    )

    $process = Start-Process -FilePath $wingetExe -ArgumentList $upgradeArgs -Wait -NoNewWindow -PassThru

    # Successfully updated, 0x8A15001C (-1978335204) = No update availablear
    switch ($process.ExitCode) {
        0 {
            Write-Log "Successfully updated: $appId" "SUCCESS" "Green"
        }
        -1978335204 {
            Write-Log "No update available or app not installed: $appId" "INFO" "Green"
        }
        -1978335189 {
            Write-Log "Failed to update ${appId}: Application is currently running." "WARN" "Yellow"
            $hasErrors = $true
        }
        -2147012894 {
            Write-Log "Failed to update ${appId}: Network timeout occurred during download." "WARN" "Yellow"
            $hasErrors = $true
        }
        default {
            Write-Log "Failed to update ${appId} with exit code: $($process.ExitCode)" "WARN" "Yellow"
            $hasErrors = $true
        }
    }
}


if ($hasErrors) {
    Write-Log "Maintenance completed with some errors." "WARN" "Yellow"
} else {
    Write-Log "All defined applications processed successfully." "INFO" "Green"
}

exit 0
