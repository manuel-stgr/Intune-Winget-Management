<#
.SYNOPSIS
   Checks if specific Winget-APP updates are available.
 
.DESCRIPTION
   First, it is checked whether the specified hour has passed; the check for winget updates only takes place from that point onwards for defined App IDs.
 
.NOTES
   Version:         2.2
   Github-Author:   manuel-stgr
   License-URL:     https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
   Creation Date:   2026-08-14
   Purpose/Change:  Fix WingetPath Bug
#>


# ---------------------------------------------------------------------------
# Time-Configuration
# ---------------------------------------------------------------------------

$schedule = @{
    "Monday"    = @(@{ Start = "12:30"; End = "16:30" })
    "Tuesday"   = @(@{ Start = "00:00"; End = "01:30" })
    "Wednesday" = @() # Blocked all day
    "Thursday"  = @(@{ Start = "14:00"; End = "23:59" })
    "Friday"    = @(
                    @{ Start = "08:00"; End = "12:30" }, # Multiple windows per day are supported
                    @{ Start = "14:00"; End = "18:00" }
                  )
    "Saturday"  = @(@{ Start = "00:00"; End = "23:59" })
    "Sunday"    = @(@{ Start = "00:00"; End = "23:59" })
}


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
    # Add additional Winget IDs here
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
Write-Log "Starting targeted Winget update detection" "INFO" "Green"


# ---------------------------------------------------------------------------
# delete Log after 20MB
# ---------------------------------------------------------------------------

if ((Test-Path -Path $LogPath) -and ((Get-Item -Path $LogPath).Length -gt 20MB)) {
    
    Clear-Content -Path $LogPath -Force -ErrorAction SilentlyContinue

    Write-Log "Log reset, reached 20MB" "WARN" "Yellow"
}



# ---------------------------------------------------------------------------
# Time window check
# ---------------------------------------------------------------------------

$now = Get-Date
$currentDay  = $now.DayOfWeek.ToString()
$currentTime = $now.TimeOfDay

$todayWindows = $schedule[$currentDay]
$isAllowed    = $false

# Check all configured time windows for today
foreach ($window in $todayWindows) {
    $start = [TimeSpan]::Parse($window.Start)
    $end   = [TimeSpan]::Parse($window.End)

    if ($currentTime -ge $start -and $currentTime -le $end) {
        $isAllowed = $true
        break
    }
}

if (-not $isAllowed) {
    Write-Log "Time ($($now.ToString('dddd HH:mm'))) is outside the allowed maintenance window. Maintenance skipped." "INFO" "Yellow"
    exit 0
}

# ---------------------------------------------------------------------------
# Determine winget.exe path 
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
