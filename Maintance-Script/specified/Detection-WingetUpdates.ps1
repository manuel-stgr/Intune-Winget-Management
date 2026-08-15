<#
.SYNOPSIS
   Checks if specific Winget-APP updates are available.
 
.DESCRIPTION
   First, it is checked whether the specified hour has passed; the check for winget updates only takes place from that point onwards for defined App IDs.
 
.NOTES
   Version:         1.1
   Github-Author:   manuel-stgr
   License-URL:     https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
   Creation Date:   2026-08-14
   Purpose/Change:  make Script clearer
#>

# ---------------------------------------------------------------------------
# Time-Configuration
# ---------------------------------------------------------------------------

$startHour = 14

# ---------------------------------------------------------------------------
# Configuration Winget-AppIDs
# ---------------------------------------------------------------------------

$appsToUpdate = @(
    "Mozilla.Firefox",
    "VideoLAN.VLC",
    "Notepad++.Notepad++"
    # Add additional Winget IDs here
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
Write-Log "Starting targeted Winget update detection" "INFO" "Green"


# ---------------------------------------------------------------------------
# delete Log after 20MB
# ---------------------------------------------------------------------------

if ((Test-Path -Path $LogPath) -and ((Get-Item -Path $LogPath).Length -gt 20MB)) {
    
    Clear-Content -Path $LogPath -Force -ErrorAction SilentlyContinue

    Write-Log "Log reset, reached 20MB" "WARN" "Yellow"
}



# ---------------------------------------------------------------------------
# Time window check (14:00 to 24:00)
# ---------------------------------------------------------------------------

$currentHour = (Get-Date).Hour

if ($currentHour -lt $startHour) {
    # Outside the maintenance window -> No action required for Intune
    Write-Log "Time ($(Get-Date -Format 'HH:mm')) is before 2:00 PM. Maintenance skipped." "INFO" "Yellow"
    exit 0
}

# ---------------------------------------------------------------------------
# Determine winget.exe path 
# ---------------------------------------------------------------------------

$wingetExe = Get-ChildItem -Path "$env:LocalAppData\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe -or -not (Test-Path $wingetExe)) {
    Write-Log "winget.exe not found." "ERROR" "Red"
    exit 0
}

# ---------------------------------------------------------------------------
# Check for available updates (Filtered by $appsToUpdate)
# ---------------------------------------------------------------------------

# Silently update package sources
& $wingetExe source update --accept-source-agreements | Out-Null

# Capture overall upgrade output as text
$upgradeList = & $wingetExe upgrade --accept-source-agreements | Out-String

$pendingUpdates = @()

foreach ($appId in $appsToUpdate) {
    # Mask dots in IDs for exact regex matching
    $escapedId = [regex]::Escape($appId)
    
    if ($upgradeList -match $escapedId) {
        $pendingUpdates += $appId
    }
}

if ($pendingUpdates.Count -gt 0) {
    Write-Log "Updates available for: $($pendingUpdates -join ', ')" "INFO" "Yellow"
    # Exit code 1 signals to Intune: Action required! Start remediation script.
    exit 1
} else {
    Write-Log "All specified apps are up to date (or none are installed)." "INFO" "Green"
    # Exit code 0 signals to Intune: Everything is fine, no action required.
    exit 0
}
