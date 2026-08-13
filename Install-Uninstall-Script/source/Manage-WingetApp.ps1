<#
.SYNOPSIS
   Install/Uninstall Winget-APP
 
.DESCRIPTION
  The specified Winget-APP is installed or uninstalled system-wide (--scope machine, some installer bugs), provided an installer is available. It automatically accepts the license/EULA.

.EXAMPLE
  Install: 	powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Install -AppId "Notepad++.Notepad++" -InstallerType "wix"
  Uninstall: 	powershell.exe -ExecutionPolicy Bypass -File ".\Manage-WingetApp.ps1" -Action Uninstall -AppId "Notepad++.Notepad++"
  
.NOTES
  Version:        2.0
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE  
  Creation Date:  2026-08-13
  Purpose/Change: Added JSON-based local tracking database to maintain an inventory of installed packages.
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
    [string]$InstallerType,

    [Parameter(Mandatory = $false)]
    [string]$CustomUninstallString
)

# ---------------------------------------------------------------------------
# Logging & Database Configuration
# ---------------------------------------------------------------------------
$LogDirectory = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogPath      = "$LogDirectory\Winget-Manage.log"
$DatabasePath = "$env:ProgramData\Microsoft\IntuneManagementExtension\WingetInventory.json"

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

# ---------------------------------------------------------------------------
# Database Management Functions (JSON-based Inventory)
# ---------------------------------------------------------------------------
function Get-AppInventory {
    if (Test-Path $DatabasePath) {
        try {
            return (Get-Content -Path $DatabasePath -Raw -ErrorAction Stop | ConvertFrom-Json)
        } catch {
            Write-Log "Error reading database. Creating a new inventory." "WARN" "Yellow"
            return @()
        }
    }
    return @()
}

function Save-AppInventory {
    param ($Inventory)
    try {
        # Falls das Inventory leer ist, explizit ein leeres JSON-Array "[]" schreiben
        if ($null -eq $Inventory -or @($Inventory).Count -eq 0) {
            "[]" | Set-Content -Path $DatabasePath -Force -ErrorAction Stop
        } else {
            # -AsArray prevents a single remaining element from losing the array structure (PowerShell 7+)
            # For PowerShell 5.1, @() forces the array
            @($Inventory) | ConvertTo-Json -Depth 5 | Set-Content -Path $DatabasePath -Force -ErrorAction Stop
        }
    } catch {
        Write-Log "Error saving database: $_" "ERROR" "Red"
    }
}

function Add-AppToDatabase {
    param ([string]$Id, [string]$Type)
    $inventory = @(Get-AppInventory)
    $inventory = @($inventory | Where-Object { $_.AppId -ne $Id })
    
    $newItem = [PSCustomObject]@{
        AppId         = $Id
        InstallerType = $Type
        InstallDate   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    
    $inventory += $newItem
    Save-AppInventory -Inventory $inventory
    Write-Log "App '$Id' successfully registered in the database." "INFO" "Green"
}

function Remove-AppFromDatabase {
    param ([string]$Id)
    $inventory = Get-AppInventory
    
    if ($inventory) {
        $inventory = @($inventory | Where-Object { $_.AppId -ne $Id })
    } else {
        $inventory = @()
    }

    Save-AppInventory -Inventory $inventory
    Write-Log "App '$Id' removed from the database." "INFO" "Green"
}

Write-Log "=== Start Script (Action: $Action | AppId: $AppId | InstallerType: $InstallerType) ===" "INFO" "Cyan"

# ---------------------------------------------------------------------------
# 0. Ensure that the script runs in the 64-bit host
# ---------------------------------------------------------------------------
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Log "32-Bit PowerShell detected. Relaunching in 64-bit context..." "WARN" "Yellow"
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
        if ($PSBoundParameters.ContainsKey('CustomUninstallString')) {
            $relaunchArgs += @("-CustomUninstallString", $CustomUninstallString)
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

# Helper function for executing WinGet commands
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
# Native Uninstaller Execution (Explicit Path or Registry Search)
# ---------------------------------------------------------------------------
function Invoke-NativeUninstall {
    param (
        [string]$AppId,
        [string]$UninstallCmd
    )

    # 1. Direct command passed (e.g., VLC uninstallation path)
    if ($UninstallCmd) {
        $expandedCmd = [System.Environment]::ExpandEnvironmentVariables($UninstallCmd).Trim()
        Write-Log "Executing custom uninstaller: $expandedCmd" "INFO" "Yellow"
        
        try {
            $exePath  = ""
            $argsList = ""

            # Case A: Path is already in quotation marks "C:\Path\app.exe" /S
            if ($expandedCmd -match '^"(?<exe>[^"]+)"\s*(?<args>.*)$') {
                $exePath  = $Matches['exe']
                $argsList = $Matches['args']
            } 
            # Case B: Path has no quotation marks C:\Program Files\...\app.exe /S
            elseif ($expandedCmd -match '^(?<exe>.*?\.(?:exe|bat|cmd))\s*(?<args>.*)$') {
                $exePath  = $Matches['exe'].Trim('"')
                $argsList = $Matches['args']
            } 
            # Fallback
            else {
                $exePath  = $expandedCmd
                $argsList = ""
            }

            Write-Log "Extracted path: '$exePath' | Argument: '$argsList'" "INFO" "Gray"

            $proc = Start-Process -FilePath $exePath -ArgumentList $argsList -Wait -PassThru -NoNewWindow
            return ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)
        } catch {
            Write-Log "Error executing custom uninstaller: $_" "ERROR" "Red"
            return $false
        }
    }

    # 2. Fallback: Search Registry
    Write-Log "Searching Registry for uninstaller matching '$AppId'..." "WARN" "Yellow"
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $searchPattern = $AppId.Split('.')[-1]
    $appKeys = Get-ItemProperty -Path $regPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$searchPattern*" -or $_.PSChildName -like "*$AppId*" }

    if (-not $appKeys) {
        Write-Log "No uninstaller entry found in Registry." "ERROR" "Red"
        return $false
    }

    foreach ($app in $appKeys) {
        $stringToRun = if ($app.QuietUninstallString) { $app.QuietUninstallString } else { $app.UninstallString }

        if ($stringToRun) {
            Write-Log "Registry uninstaller found: $stringToRun" "INFO" "Cyan"

            if ($stringToRun -match "msiexec") {
                if ($stringToRun -match "\{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\}") {
                    $guid = $Matches[0]
                    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait -PassThru -NoNewWindow
                    return ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)
                }
            } else {
                if ($stringToRun -notmatch "/S|/silent|/quiet|/qn") {
                    $stringToRun += " /S"
                }
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$stringToRun`"" -Wait -PassThru -NoNewWindow
                return ($proc.ExitCode -eq 0)
            }
        }
    }
    return $false
}

# ---------------------------------------------------------------------------
# 2. Execution Logic
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
if ($InstallerType) { $installArgs += @("--installer-type", $InstallerType) }

$uninstallArgs = @(
    "uninstall",
    "--id", $AppId,
    "--silent",
    "--disable-interactivity",
    "--accept-source-agreements"
)

switch ($Action) {
    'Install' {
        Write-Log "Updating WinGet source catalog..." "INFO" "Yellow"
        Invoke-WingetCommand -Arguments @("source", "update") | Out-Null

        $installerMsg = if ($InstallerType) { " (Type: $InstallerType)" } else { "" }
        Write-Log "Installing App: '$AppId'$installerMsg..." "INFO" "Green"
        
        $exitCode = Invoke-WingetCommand -Arguments $installArgs
        $validSuccessCodes = @(0, -1978335189, -1978335183, 3010)

        if ($validSuccessCodes -contains $exitCode) {
            Write-Log "App '$AppId' installed successfully or already up to date." "INFO" "Green"
            Add-AppToDatabase -Id $AppId -Type $InstallerType
            exit 0
        } else {
            Write-Log "Error installing '$AppId'. Exit-Code: $exitCode" "ERROR" "Red"
            exit $exitCode
        }
    }

    'Uninstall' {
        # If a custom uninstall string was provided (e.g. VLC), run it directly
        if ($CustomUninstallString) {
            Write-Log "Using custom uninstall command..." "INFO" "Yellow"
            $success = Invoke-NativeUninstall -AppId $AppId -UninstallCmd $CustomUninstallString
            if ($success) {
                Remove-AppFromDatabase -Id $AppId
                exit 0
            } else {
                Write-Log "Custom uninstallation failed." "ERROR" "Red"
                exit 1
            }
        }

        # Standard path: Try via WinGet first
        Write-Log "Uninstalling App: '$AppId' via WinGet..." "INFO" "Yellow"
        $exitCode = Invoke-WingetCommand -Arguments $uninstallArgs

        if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
            Write-Log "App '$AppId' uninstalled successfully via WinGet." "INFO" "Green"
            Remove-AppFromDatabase -Id $AppId
            exit 0
        } else {
            Write-Log "WinGet uninstallation failed (Code: $exitCode). Starting Registry fallback..." "WARN" "Yellow"
            $nativeSuccess = Invoke-NativeUninstall -AppId $AppId
            if ($nativeSuccess) {
                Write-Log "App '$AppId' removed successfully via Registry uninstaller." "INFO" "Green"
                Remove-AppFromDatabase -Id $AppId
                exit 0
            } else {
                Write-Log "Error: Failed to uninstall '$AppId'." "ERROR" "Red"
                exit 1
            }
        }
    }
}
