<#
.SYNOPSIS
    Installs targeted updates via Winget.
 
.DESCRIPTION
    Installs updates only for a specific list of defined Winget application IDs.

.NOTES
  Version:        1.0
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-14
  Purpose/Change: Creation
#>


# ---------------------------------------------------------------------------
# 64-bit PowerShell Redirection
# ---------------------------------------------------------------------------

if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    & "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit $LASTEXITCODE
}

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

$wingetExe = Get-ChildItem -Path "$env:LocalAppData\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe) {
    Write-Log "winget.exe not Found!" "ERROR" "Red"
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
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--include-unknown"
    )

    $process = Start-Process -FilePath $wingetExe -ArgumentList $upgradeArgs -Wait -NoNewWindow -PassThru

    # Successfully updated, 0x8A15001C (-1978335204) = No update availablear
    if ($process.ExitCode -eq 0) {
        Write-Log "Successfully updated: $appId" "INFO" "Green"
    } elseif ($process.ExitCode -eq -1978335204) {
        Write-Log "No update available or app not installed: $appId" "INFO" "Green"
    } else {
        Write-Log "Failed to update $appId with exit code: $($process.ExitCode)" "WARN" "Yellow"
        $hasErrors = $true
    }
}

if ($hasErrors) {
    Write-Log "Maintenance completed with some errors." "WARN" "Yellow"
} else {
    Write-Log "All defined applications processed successfully." "INFO" "Green"
}

exit 0