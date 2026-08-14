<#
.SYNOPSIS
    Checks if Winget-APP updates are available for applications registered in the local JSON database.

.DESCRIPTION
    First, it verifies whether the current time is within the allowed execution window (14:00 - 24:00).
    If within the window, it reads the managed application list from the local JSON database file
    and checks if Winget has pending updates for any of those specific App IDs.

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
# Logging & Database Configuration
# ---------------------------------------------------------------------------

$LogDirectory = "$env:ProgramData\IntuneWingetManagement\Logs"
$LogPath      = "$LogDirectory\Winget-AutoUpdate.log"
$DatabasePath = "$env:ProgramData\IntuneWingetManagement\WingetInventory.json"

if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

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
Write-Log "Starting database-driven Winget update Check" "Info" "Green"

function Get-AppInventory {
    if (Test-Path $DatabasePath) {
        try {
            return (Get-Content -Path $DatabasePath -Raw -ErrorAction Stop | ConvertFrom-Json)
        } catch {
            Write-Log "Error reading database file." "ERROR" "Red"
            return @()
        }
    }
    return @()
}


# ---------------------------------------------------------------------------
# delete Log after 20MB
# ---------------------------------------------------------------------------

if ((Test-Path -Path $LogPath) -and ((Get-Item -Path $LogPath).Length -gt 20MB)) {
    
    Clear-Content -Path $LogPath -Force -ErrorAction SilentlyContinue

    Write-Log "Log reset, reached 20MB" "WARN" "Yellow"
}

# ---------------------------------------------------------------------------
# Time Window Check (14:00 to 24:00)
# ---------------------------------------------------------------------------
$currentHour = (Get-Date).Hour
$startHour   = 14

if ($currentHour -lt $startHour) {
    Write-Log "Time ($(Get-Date -Format 'HH:mm')) is before 2:00 PM. Maintenance skipped." "INFO" "Yellow"
    exit 0
}

# ---------------------------------------------------------------------------
# Read Applications from Database
# ---------------------------------------------------------------------------

$inventory = Get-AppInventory
$appsToUpdate = @($inventory.AppId | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($appsToUpdate.Count -eq 0) {
    Write-Log "No registered applications found in database. Nothing to check." "WARN" "Yellow"
    exit 0
}

Write-Log "Found $($appsToUpdate.Count) application(s) registered in database: $($appsToUpdate -join ', ')" "INFO" "Gray"

# ---------------------------------------------------------------------------
# Determine winget.exe Path
# ---------------------------------------------------------------------------

$wingetExe = Get-ChildItem -Path "$env:LocalAppData\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe -or -not (Test-Path $wingetExe)) {
    Write-Log "winget.exe not found on the system." "ERROR" "Red"
    exit 0
}

# ---------------------------------------------------------------------------
# Check for Available Updates (Database Apps Only)
# ---------------------------------------------------------------------------

# Silently update package sources
& $wingetExe source update --accept-source-agreements | Out-Null

# Capture overall upgrade output
$upgradeList = & $wingetExe upgrade --accept-source-agreements | Out-String

$pendingUpdates = @()

foreach ($appId in $appsToUpdate) {
    # Escape dot notation in Winget App IDs for regular expression matching
    $escapedId = [regex]::Escape($appId)
    
    if ($upgradeList -match $escapedId) {
        $pendingUpdates += $appId
    }
}

# ---------------------------------------------------------------------------
# Result & Exit Code Handling
# ---------------------------------------------------------------------------

if ($pendingUpdates.Count -gt 0) {
    Write-Log "Updates available for database apps: $($pendingUpdates -join ', ')" "WARN" "Yellow"
    # Exit code 1 signals Intune: Action required! (Triggers Remediation script)
    exit 1
} else {
    Write-Log "All database-managed apps are up to date." "INFO" "Green"
    # Exit code 0 signals Intune: Compliant / No action required
    exit 0
}