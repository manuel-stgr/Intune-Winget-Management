<#
.SYNOPSIS
   Checks if Winget-APP updates are available.
 
.DESCRIPTION
  First, it is checked whether the specified hour has passed; the check for winget updates (ALL) only takes place from that point onwards.
 
.NOTES
  Version:        1.2
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
  Purpose/Change: make Script clearer
#>


# ---------------------------------------------------------------------------
# Time-Configuration
# ---------------------------------------------------------------------------

$startHour = 14


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
# Time window check (14:00 to 24:00)
# ---------------------------------------------------------------------------

$currentHour = (Get-Date).Hour

if ($currentHour -lt $startHour) {
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
# Check for available updates
# ---------------------------------------------------------------------------

# Update sources silently
& $wingetExe source update --accept-source-agreements | Out-Null

# Run upgrade check including unknown versions
$upgradeOutput = & $wingetExe upgrade --include-unknown --accept-source-agreements 2>&1

# Parse output: Find line dividers (--- or ───) and check if data rows exist after them
$hasUpdates = $false
$pastHeader = $false

foreach ($line in $upgradeOutput) {
    # Check for table header separator line
    if ($line -match '^(---|───|\-\-\-)') {
        $pastHeader = $true
        continue
    }

    # If passed the header and find non-empty content (excluding summary footers)
    if ($pastHeader -and $line.Trim().Length -gt 0) {
        # Exclude common footer messages
        if ($line -notmatch "upgrades available" -and 
            $line -notmatch "Aktualisierungen verfügbar" -and 
            $line -notmatch "selected source" -and
            $line -notmatch "gefundene") {
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
