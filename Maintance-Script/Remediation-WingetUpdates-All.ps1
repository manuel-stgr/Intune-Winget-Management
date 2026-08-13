<#
.SYNOPSIS
   Installs updates via Winget
 
.DESCRIPTION
  Installs updates for any detected Winget software.
  

.NOTES
  Version:        1.0
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
  Purpose/Change: Creation
#>



[CmdletBinding()]
param (
    [string]$LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Winget-AutoUpdate.log"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    
    $logDir = Split-Path $LogPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -Path $LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

Write-Log "=========================================="
Write-Log "Starting remediation: Automatic Winget maintenance"

# ---------------------------------------------------------------------------
# 0. 64-bit PowerShell Redirection
# ---------------------------------------------------------------------------
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    & "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit $LASTEXITCODE
}

# ---------------------------------------------------------------------------
# 1. Determine the path to winget.exe
# ---------------------------------------------------------------------------

$wingetExe = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe) {
    Write-Log "winget.exe not Found!" "ERROR"
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Execute Updates
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
    Write-Log "All available updates have been successfully installed." "SUCCESS"
    exit 0
} else {
    Write-Log "Maintenance completed with exit code: $($process.ExitCode)" "WARN"
    exit 0
}
