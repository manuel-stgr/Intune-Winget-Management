<#
.SYNOPSIS
   Install/Uninstall Winget-APP
 
.DESCRIPTION
  The specified Winget-APP is installed or uninstalled system-wide (--scope machine, some installer bugs), provided an installer is available. It automatically accepts the license/EULA.

.EXAMPLE
  Install: 	powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Install -AppId "Notepad++.Notepad++" -InstallerType "wix"
  Uninstall: 	powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Uninstall -AppId "Notepad++.Notepad++"
  
.NOTES
  Version:        1.0
  Github-Author:  manuel-stgr        
  Creation Date:  2026-08-13
  Purpose/Change: Creation
#>




[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$AppId,

    [Parameter(Mandatory = $false)]
    [ValidateSet('wix', 'nullsoft', 'msi', 'exe', 'inno', 'burn', 'msix', 'portable', 'zip')]
    [string]$InstallerType
)

# ---------------------------------------------------------------------------
# Logging-Configuration
# ---------------------------------------------------------------------------
$LogDirectory = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogPath      = "$LogDirectory\Winget-Manage.log"

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
    
    # In Datei schreiben
    Add-Content -Path $LogPath -Value $LogEntry -ErrorAction SilentlyContinue
    
    # Auf der Konsole ausgeben
    Write-Host $LogEntry -ForegroundColor $Color
}

Write-Log "=== Start Script (Action: $Action | AppId: $AppId | InstallerType: $InstallerType) ===" "INFO" "Cyan"

# ---------------------------------------------------------------------------
# 0. Ensure that the script runs in the 64-bit host.
# ---------------------------------------------------------------------------
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Log "32-Bit PowerShell recognized. Restart in a 64-bit context..." "WARN" "Yellow"
    $sysnativePowerShell = "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe"
    
    if (Test-Path $sysnativePowerShell) {
        $relaunchArgs = @(
            "-ExecutionPolicy", "Bypass",
            "-File", $MyInvocation.MyCommand.Path,
            "-Action", $Action,
            "-AppId", $AppId
        )
        if ($PSBoundParameters.ContainsKey('InstallerType')) {
            $relaunchArgs += @("-InstallerType", $InstallerType)
        }

        & $sysnativePowerShell @relaunchArgs
        exit $LASTEXITCODE
    } else {
        Write-Log "SysNative PowerShell could not be found." "ERROR" "Red"
    }
}

# ---------------------------------------------------------------------------
# 1. Determine the path to winget.exe
# ---------------------------------------------------------------------------
function Get-WingetPath {
    $winget = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
              Sort-Object LastWriteTime -Descending | 
              Select-Object -ExpandProperty FullName -First 1

    if (-not $winget) {
        $winget = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
    }

    return $winget
}

$wingetExe = Get-WingetPath

if (-not $wingetExe -or -not (Test-Path $wingetExe)) {
    Write-Log "winget.exe was not found on this system." "ERROR" "Red"
    exit 1
}

Write-Log "Use winget at: $wingetExe" "INFO" "Cyan"

# ---------------------------------------------------------------------------
# 2. Define standardized arguments
# ---------------------------------------------------------------------------
$installArgs = @(
    "install",
    "--id", $AppId,
    "--exact",
    "--silent",
    "--disable-interactivity",
    "--scope", "machine",
    "--accept-source-agreements",
    "--accept-package-agreements",
    "--force"
)

if ($InstallerType) {
    $installArgs += @("--installer-type", $InstallerType)
}

$uninstallArgs = @(
    "uninstall",
    "--id", $AppId,
    "--silent",
    "--disable-interactivity",
    "--accept-source-agreements"
)

# Helper function for executing WinGet, including output logging.
function Invoke-WingetCommand {
    param ([array]$Arguments)
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $wingetExe
    $pinfo.Arguments = $Arguments -join " "
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($stdout) {
        $stdout -split "`r`n" | Where-Object { $_ } | ForEach-Object { Write-Log "[winget] $_" "INFO" "Gray" }
    }
    if ($stderr) {
        $stderr -split "`r`n" | Where-Object { $_ } | ForEach-Object { Write-Log "[winget-err] $_" "WARN" "Yellow" }
    }

    return $p.ExitCode
}

# ---------------------------------------------------------------------------
# 3. Execution
# ---------------------------------------------------------------------------
switch ($Action) {
    'Install' {
        Write-Log "Aktualisiere WinGet-Quellkatalog..." "INFO" "Yellow"
        Invoke-WingetCommand -Arguments @("source", "update") | Out-Null

        $installerMsg = if ($InstallerType) { " (Typ: $InstallerType)" } else { "" }
        Write-Log "Install App: '$AppId'$installerMsg..." "INFO" "Green"
        
        $exitCode = Invoke-WingetCommand -Arguments $installArgs

        # Validate the Exit-Codes (0, Already up to date; restart required)
        $validSuccessCodes = @(0, -1978335189, -1978335183, 3010)

        if ($validSuccessCodes -contains $exitCode) {
            Write-Log "App '$AppId' successfully installed or was already up to date (Exit-Code: $exitCode)." "INFO" "Green"
            exit 0
        } else {
            Write-Log "Error during installation of '$AppId'. Exit-Code: $exitCode" "ERROR" "Red"
            exit $exitCode
        }
    }

    'Uninstall' {
        Write-Log "Uninstall App: '$AppId'..." "INFO" "Yellow"
        $exitCode = Invoke-WingetCommand -Arguments $uninstallArgs

        if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
            Write-Log "App '$AppId' successfully uninstalled" "INFO" "Green"
            exit 0
        } else {
            Write-Log "Error during uninstallation of '$AppId'. Exit-Code: $exitCode" "ERROR" "Red"
            exit $exitCode
        }
    }
}