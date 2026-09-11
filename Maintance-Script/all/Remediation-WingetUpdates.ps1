<#
.SYNOPSIS
   Installs updates via Winget
 
.DESCRIPTION
  Installs updates for any detected Winget software.
  

.NOTES
  Version:        2.3
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
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
# Execute Updates
# ---------------------------------------------------------------------------


$upgradeArgs = @(
    "upgrade",
    "--all",
    "--silent",
    "--disable-interactivity",
    "--force",
    "--accept-source-agreements",
    "--accept-package-agreements",
    "--include-unknown"
)

Write-Log "Run 'winget upgrade --all'..."
$process = Start-Process -FilePath $wingetExe -ArgumentList $upgradeArgs -Wait -NoNewWindow -PassThru


switch ($process.ExitCode) {
    0 {
        Write-Log "All available updates have been successfully installed." "INFO" "Green"
        exit 0
    }
    -1978335204 {
        Write-Log "No updates available or applications are already up to date." "INFO" "Green"
        exit 0
    }
    -1978335189 {
        Write-Log "Maintenance completed with warnings: One or more applications are currently running." "WARN" "Yellow"
        exit 0
    }
    -2147012894 {
        Write-Log "Maintenance completed with errors: Network timeout occurred during download." "WARN" "Yellow"
        exit 0
    }
    default {
        Write-Log "Maintenance completed with exit code: $($process.ExitCode)" "WARN" "Yellow"
        exit 0
    }
}
