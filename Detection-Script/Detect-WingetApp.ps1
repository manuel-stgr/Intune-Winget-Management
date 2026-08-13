<#
.SYNOPSIS
   Checks if Notepad++ is installed using Winget.
 
.DESCRIPTION
   Adjust the AppId!

.EXAMPLE
   $AppId = "Notepad++.Notepad++"
  
.NOTES
  Version:        1.0
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-13
  Purpose/Change: Creation
#>


# ---------------------------------------------------------------------------
# Configuration: Enter the exact Winget ID here.
# ---------------------------------------------------------------------------
$AppId = "Notepad++.Notepad++"

# ---------------------------------------------------------------------------
# 1. 64-bit PowerShell Redirection
# ---------------------------------------------------------------------------
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    & "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "$PSCommandPath"
    exit $LASTEXITCODE
}

# ---------------------------------------------------------------------------
# 2. winget.exe Determine path
# ---------------------------------------------------------------------------
$wingetExe = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -ExpandProperty FullName -First 1

if (-not $wingetExe) {
    $wingetExe = (Get-Command "winget.exe" -ErrorAction SilentlyContinue).Source
}

if (-not $wingetExe -or -not (Test-Path $wingetExe)) {
    # WinGet not Found -> App is considered non-existent.
    exit 1
}

# ---------------------------------------------------------------------------
# 3. Conduct an inspection
# ---------------------------------------------------------------------------
$isInstalled = & $wingetExe list --id $AppId --accept-source-agreements 2>$null

if ($isInstalled -match [regex]::Escape($AppId)) {
    Write-Output "App '$AppId' ist installed."
    exit 0
} else {
    Write-Output "App '$AppId' not installed."
    exit 1
}