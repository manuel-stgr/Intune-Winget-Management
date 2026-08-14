<#
.SYNOPSIS
   Installs updates via Winget
 
.DESCRIPTION
  Installs updates for any detected Winget software.
  

.NOTES
  Version:        1.1
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
  Purpose/Change: Correction LogPath
#>


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
Write-Log "Starting remediation: Automatic Winget maintenance" "INFO" "Green"

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
# Execute Updates
# ---------------------------------------------------------------------------

$upgradeArgs = @(
    "upgrade",
    "--all",
    "--silent",
    "--accept-source-agreements",
    "--accept-package-agreements",
    "--include-unknown"
)

Write-Log "Run 'winget upgrade --all'..."
$process = Start-Process -FilePath $wingetExe -ArgumentList $upgradeArgs -Wait -NoNewWindow -PassThru

if ($process.ExitCode -eq 0) {
    Write-Log "All available updates have been successfully installed." "INFO" "Green"
    exit 0
} else {
    Write-Log "Maintenance completed with exit code: $($process.ExitCode)" "WARN" "Yellow"
    exit 0
}