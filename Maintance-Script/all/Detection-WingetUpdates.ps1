<#
.SYNOPSIS
   Checks if Winget-APP updates are available.
 
.DESCRIPTION
  First, it is checked whether the specified hour has passed; the check for winget updates (ALL) only takes place from that point onwards.
 
.NOTES
  Version:        2.2
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
  Purpose/Change: Fix WingetPath Bug
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
    "Saturday"  = @(@{ Start = "00:00"; End = "23:59" }) # all day
    "Sunday"    = @(@{ Start = "00:00"; End = "23:59" }) # all day
}


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
$LogPath      = "$LogDirectory\Winget-AllUpdate.log"


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
Write-Log "Starting Detection: Automatic Winget maintenance" "INFO" "Green"

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
# Check for available updates
# ---------------------------------------------------------------------------

# Temporarily force the language to English for the current process
$oldLang = $env:PreferredUILanguages
$env:PreferredUILanguages = "en-US"

try {
    # Execute update check
    $upgradeOutput = & $wingetExe upgrade --include-unknown --accept-source-agreements 2>&1
}
finally {
    # Restore original language setting
    $env:PreferredUILanguages = $oldLang
}

# Purely English parsing
$hasUpdates = $false
$pastHeader = $false

foreach ($line in $upgradeOutput) {
    # Search for table header separator line (--- or ───)
    if ($line -match '^(---|───|\-\-\-)') {
        $pastHeader = $true
        continue
    }

    # Check data rows after the header
    if ($pastHeader -and $line.Trim().Length -gt 0) {
        # Only English exclusions required now!
        if ($line -notmatch "upgrades available" -and 
            $line -notmatch "selected source" -and
            $line -notmatch "installed package") {
            $hasUpdates = $true
            break
        }
    }
}


if ($hasUpdates) {
    Write-Log "Updates are available, and we are within the scheduled time window." "INFO" "Gray"
    exit 1 # Intune Remediation required
} else {
    Write-Log "All apps are up to date." "INFO" "Green"
    exit 0 # No action required
}
