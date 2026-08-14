<#
.SYNOPSIS
   Checks if Notepad++ is installed using Winget.
 
.DESCRIPTION
   Adjust the AppId!

.EXAMPLE
   $AppId = "Notepad++.Notepad++"
  
.NOTES
  Version:        2.0
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
  Purpose/Change: Adding Log and Json-Database & Correct Winget-Path
#>


# ---------------------------------------------------------------------------
# Configuration: Enter the exact Winget ID here.
# ---------------------------------------------------------------------------

$AppId = "Notepad++.Notepad++"

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
$LogPath      = "$LogDirectory\Winget-Detect-Installation.log"
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
# winget.exe Determine path
# ---------------------------------------------------------------------------

$wingetExe = Get-ChildItem -Path "$env:LocalAppData\Microsoft\WindowsApps\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe -or -not (Test-Path $wingetExe)) {
    # WinGet not Found -> App is considered non-existent.
    Write-Log "Couldn't find Winget on the host."
    exit 1
}

# ---------------------------------------------------------------------------
# Read Applications from Database and Check AppIDs
# ---------------------------------------------------------------------------

$inventory = Get-AppInventory
$appsToUpdate = @($inventory.AppId | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($appsToUpdate.Count -eq 0) {
    Write-Log "No registered applications found in database. Nothing to check." "WARN" "Yellow"
    exit 1
}

$isDatabase = $appsToUpdate -contains $AppId

if ($isDatabase) {
    Write-Log "Entry '$AppId' was found in Database" "INFO" "Green"
} else {
    Write-Log "Entry '$AppId' was not found in Database" "WARN" "Yellow"
}

# ---------------------------------------------------------------------------
# Conduct an inspection
# ---------------------------------------------------------------------------

$isInstalled = & $wingetExe list --id $AppId --accept-source-agreements 2>$null

if ($isInstalled -match [regex]::Escape($AppId) -And $isDatabase) {
    Write-Log "App '$AppId' ist installed." "INFO" "Green"
    exit 0
} else {
    Write-Log "App '$AppId' not installed." "WARN" "Yellow"
    exit 1
}

