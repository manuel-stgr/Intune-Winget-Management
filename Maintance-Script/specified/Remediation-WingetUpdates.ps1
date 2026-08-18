<#
.SYNOPSIS
    Installs targeted updates via Winget.
 
.DESCRIPTION
    Installs updates only for a specific list of defined Winget application IDs.

.NOTES
  Version:        1.0
  Github-Author:  manuel-stgr
  License-URL:    https://github.com/manuel-stgr/Intune-Winget-Management/blob/main/LICENSE        
  Creation Date:  2026-08-14
  Purpose/Change: add Announcement prior to the update
#>


# ---------------------------------------------------------------------------
# Configuration Winget-AppIDs
# ---------------------------------------------------------------------------
$appsToUpdate = @(
    "Mozilla.Firefox",
    "VideoLAN.VLC",
    "Notepad++.Notepad++"
    # Add additional Winget IDs here.
)

# ---------------------------------------------------------------------------
# Update Message Configuration
# ---------------------------------------------------------------------------

$UpdateMessageTitle = "Scheduled Software Maintenance"
$UpdateMessageText = "Automatic software updates via Winget will install in 2 minutes. Please save your work."
$UpdateToWaitAfterMessage = 120

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
# Logging Configuration
# ---------------------------------------------------------------------------

$LogDirectory = "$env:ProgramData\IntuneWingetManagement\Logs"
$LogPath      = "$LogDirectory\Winget-SepcifiedUpdate.log"

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
Write-Log "Starting targeted Winget update process" "INFO" "Green"


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
# Execute Updates for defined apps
# ---------------------------------------------------------------------------

# Send toast ... Update start Notification and wait x minutes
Write-Log "Sending Update wait x minutes notification to the user..." "INFO" "Cyan"
Show-ToastNotification -Title $UpdateMessageTitle -Message $UpdateMessageText

 $UpdateToWaitAfterMessageMinutes = $UpdateToWaitAfterMessage / 60
Write-Log "Waiting $UpdateToWaitAfterMessageMinutes minutes before starting updates..." "INFO" "Yellow"
Start-Sleep -Seconds $UpdateToWaitAfterMessage

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

    # Successfully updated, 0x8A15001C (-1978335204) = No update availablear
    if ($process.ExitCode -eq 0) {
        Write-Log "Successfully updated: $appId" "INFO" "Green"
    } elseif ($process.ExitCode -eq -1978335204) {
        Write-Log "No update available or app not installed: $appId" "INFO" "Green"
    } else {
        Write-Log "Failed to update $appId with exit code: $($process.ExitCode)" "WARN" "Yellow"
        $hasErrors = $true
    }
}


# Send toast ... Update Finished.
Write-Log "Sending Update finished notification to the user..." "INFO" "Cyan"
Show-ToastNotification -Title $UpdateFinishedTitle -Message $UpdateFinishedText

if ($hasErrors) {
    Write-Log "Maintenance completed with some errors." "WARN" "Yellow"
} else {
    Write-Log "All defined applications processed successfully." "INFO" "Green"
}

exit 0
