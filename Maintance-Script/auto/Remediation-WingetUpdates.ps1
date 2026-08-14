<#
.SYNOPSIS
    Installs targeted updates via Winget based on the local JSON database inventory.

.DESCRIPTION
    Reads the registered application IDs from the JSON database (WingetInventory.json)
    and executes silent Winget upgrades for each found application.

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

$wingetExe = Get-ChildItem -Path "$env:LocalAppData\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe -or -not (Test-Path $wingetExe)) {
    Write-Log "winget.exe not found on the system!" "ERROR" "Red"
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
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--include-unknown"
    )

    $process = Start-Process -FilePath $wingetExe -ArgumentList $upgradeArgs -Wait -NoNewWindow -PassThru

    # 0 = Success, 0x8A15001C (-1978335204) = No update available / up to date
    if ($process.ExitCode -eq 0) {
        Write-Log "Successfully updated: $appId" "SUCCESS"
    } elseif ($process.ExitCode -eq -1978335204) {
        Write-Log "No update available or app not installed: $appId" "INFO" "Green"
    } else {
        Write-Log "Failed to update $appId with exit code: $($process.ExitCode)" "WARN"
        $hasErrors = $true
    }
}

if ($hasErrors) {
    Write-Log "Remediation completed with some errors." "ERROR" "Red"
} else {
    Write-Log "All database-managed applications processed successfully." "INFO" "Green"
}

exit 0