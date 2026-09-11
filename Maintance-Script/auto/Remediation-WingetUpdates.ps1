<#
.SYNOPSIS
    Installs targeted updates via Winget based on the local JSON database inventory.

.DESCRIPTION
    Reads the registered application IDs from the JSON database (WingetInventory.json)
    and executes silent Winget upgrades for each found application.

.NOTES
    Version:        2.3
    Github-Author:  manuel-stgr
    License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE
    Creation Date:  2026-08-14
    Purpose/Change: remove Toast Message
#>



# ---------------------------------------------------------------------------
# 64-bit PowerShell Redirection
# ---------------------------------------------------------------------------

if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    & "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit $LASTEXITCODE
}

# ---------------------------------------------------------------------------
# Logging & Database Functions
# ---------------------------------------------------------------------------

$LogDirectory = "$env:ProgramData\IntuneWingetManagement\Logs"
$LogPath      = "$LogDirectory\Winget-AutoUpdate.log"
$DatabasePath = "$env:ProgramData\IntuneWingetManagement\WingetInventory.json"

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

function Get-AppInventory {
    if (Test-Path $DatabasePath) {
        try {
            return (Get-Content -Path $DatabasePath -Raw -ErrorAction Stop | ConvertFrom-Json)
        } catch {
            Write-Log "Error reading database file: $_" "ERROR" "Red"
            return @()
        }
    }
    return @()
}

Write-Log "==========================================" "Info" "Gray"
Write-Log "Starting database-driven Winget update process" "Info" "Green"

# ---------------------------------------------------------------------------
# Read target applications from Database
# ---------------------------------------------------------------------------

$inventory = Get-AppInventory
$appsToUpdate = @($inventory.AppId | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($appsToUpdate.Count -eq 0) {
    Write-Log "No registered applications found in database. Exiting." "Warn" "Yellow" 
    exit 0
}

Write-Log "Found $($appsToUpdate.Count) application(s) to process: $($appsToUpdate -join ', ')"

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
# Execute Updates for Database Apps
# ---------------------------------------------------------------------------


# Refresh Winget sources before running upgrades
& $wingetExe source update --accept-source-agreements | Out-Null

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
    Write-Log "Remediation completed with some errors." "ERROR" "Red"
} else {
    Write-Log "All database-managed applications processed successfully." "INFO" "Green"
}

exit 0
