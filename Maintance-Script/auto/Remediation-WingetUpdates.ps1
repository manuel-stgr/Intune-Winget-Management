<#
.SYNOPSIS
    Installs targeted updates via Winget based on the local JSON database inventory.

.DESCRIPTION
    Reads the registered application IDs from the JSON database (WingetInventory.json)
    and executes silent Winget upgrades for each found application.

.NOTES
    Version:        2.1
    Github-Author:  manuel-stgr
    License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE
    Creation Date:  2026-08-14
    Purpose/Change: Improvement of Update Message Configuration
#>


# ---------------------------------------------------------------------------
# Update Message Configuration
# ---------------------------------------------------------------------------

$UpdateToWaitAfterMessageMinutes = 2 #minutes

$UpdateMessageTitle = "Scheduled Software Maintenance"
$UpdateMessageText = "Automatic software updates via Winget will install in $UpdateToWaitAfterMessageMinutes minutes. Please save your work."


$UpdateFinishedTitle = "Software Update Completed"
$UpdateFinishedText = "All pending software updates have been successfully installed. You can resume your work."

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
# Toast Notification & Delay Configuration
# ---------------------------------------------------------------------------

function Show-ToastNotification {
    param(
        [string]$Title = "Example Title",
        [string]$Message = "Example Message",
        [string]$AppIdf = "Intune-Winget-Management",
        [string]$AppDisplayName = "Intune Winget Management"
    )

    try {
        # 1) Register AppIDf with display name
        $classesPath = "HKCU:\Software\Classes\AppUserModelId\$AppIdf"
        if (-not (Test-Path $classesPath)) {
            New-Item -Path $classesPath -Force | Out-Null
        }
        New-ItemProperty -Path $classesPath -Name "DisplayName" -Value $AppDisplayName -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $classesPath -Name "IconUri" -Value "%SystemRoot%\System32\SecurityAndMaintenance.ico" -PropertyType ExpandString -Force | Out-Null

        # 2) Automatically enable notification permissions for this AppIDf
        $settingsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppIdf"
        if (-not (Test-Path $settingsPath)) {
            New-Item -Path $settingsPath -Force | Out-Null
        }
        New-ItemProperty -Path $settingsPath -Name "Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $settingsPath -Name "ShowInActionCenter" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $settingsPath -Name "ShowBanner" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $settingsPath -Name "Sound" -Value 1 -PropertyType DWord -Force | Out-Null

        # 3) Display Toast notification
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        [xml]$ToastXml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default" />
</toast>
"@

        $xmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xmlDoc.LoadXml($ToastXml.OuterXml)

        $toast = [Windows.UI.Notifications.ToastNotification]::new($xmlDoc)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppIdf)
        $notifier.Show($toast)

        Write-Log "Toast notification sent successfully." "INFO" "Cyan"
    }
    catch {
        Write-Log "Error sending toast notification: $_" "WARN" "Yellow"
    }
}

# ---------------------------------------------------------------------------
# Execute Updates for Database Apps
# ---------------------------------------------------------------------------


# Send toast ... Update start Notification and wait x minutes
Write-Log "Sending Update wait $UpdateToWaitAfterMessageMinutes minutes notification to the user..." "INFO" "Cyan"
Show-ToastNotification -Title $UpdateMessageTitle -Message $UpdateMessageText

$UpdateToWaitAfterMessage = $UpdateToWaitAfterMessageMinutes * 60
Write-Log "Waiting $UpdateToWaitAfterMessageMinutes minutes before starting updates..." "INFO" "Yellow"
Start-Sleep -Seconds $UpdateToWaitAfterMessage

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

# Send toast ... Update Finished.
Write-Log "Sending Update finished notification to the user..." "INFO" "Cyan"
Show-ToastNotification -Title $UpdateFinishedTitle -Message $UpdateFinishedText

if ($hasErrors) {
    Write-Log "Remediation completed with some errors." "ERROR" "Red"
} else {
    Write-Log "All database-managed applications processed successfully." "INFO" "Green"
}

exit 0
