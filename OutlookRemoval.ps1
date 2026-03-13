# this checks for old/new Outlook & removes 
# Also disables updates to Outlook, during Windows Updates, it looks to see if Outlook is installed, if not will install Outlook.  Disable this option
# ============================================================================================================================================================
#
$LogFolder = "C:\applogs\OutlookRemoval"
$LogFile = Join-Path $LogFolder "OutlookRemoval_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$LayoutXmlPath = "C:\Windows\Temp\LayoutModification.xml"

if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param ([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "$ts - $Message"
    Write-Output $msg
    Add-Content -Path $LogFile -Value $msg
}

Write-Log "==== Starting Outlook total removal ===="

# ========== REMOVE APPX PACKAGES ==========
$apps = @(
    "Microsoft.OutlookForWindows",
    "Microsoft.WindowsCommunicationsApps",
    "Microsoft.Office.OneOutlook",
    "Microsoft.MicrosoftOfficeHub"
)

foreach ($app in $apps) {
    Write-Log "Searching for: $app"
    $installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $app }
    foreach ($pkg in $installed) {
        Write-Log "Removing installed Appx: $($pkg.PackageFullName)"
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            Write-Log "Removed: $($pkg.Name)"
        } catch {
            Write-Log "Failed to remove $($pkg.Name): $_"
        }
    }

    $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app }
    foreach ($p in $prov) {
        Write-Log "Removing provisioned Appx: $($p.DisplayName)"
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop
            Write-Log "Removed provisioned: $($p.DisplayName)"
        } catch {
            Write-Log "Failed to remove provisioned: $_"
        }
    }
}

# ========== CLEAN START MENU SHORTCUTS ==========
Write-Log "Cleaning up Start Menu shortcuts"
$paths = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Recurse -Filter "*.lnk" | Where-Object {
            $_.Name -match "Outlook|Mail|Calendar|Office"
        } | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force
                Write-Log "Deleted Start shortcut: $($_.FullName)"
            } catch {
                Write-Log "Failed to delete shortcut: $_"
            }
        }
    }
}

# ========== UNPIN TASKBAR ==========
function Unpin-Taskbar {
    $TaskPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    if (Test-Path $TaskPath) {
        Get-ChildItem -Path $TaskPath -Filter "*.lnk" | Where-Object {
            $_.Name -match "Outlook|Mail|Calendar|Office"
        } | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force
                Write-Log "Unpinned from taskbar: $($_.Name)"
            } catch {
                Write-Log "Failed to unpin: $_"
            }
        }
    }
}
Unpin-Taskbar

# ========== TASKBAR LAYOUT FOR NEW USERS ==========
$xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" Version="1" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <taskbar:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\File Explorer.lnk"/>
      </taskbar:TaskbarPinList>
    </taskbar:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

$xmlContent | Out-File -Encoding UTF8 -FilePath $LayoutXmlPath -Force
Write-Log "Created LayoutModification.xml"

# Apply layout for all new users
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\LayoutSettings"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "LayoutModificationXML" -Value $LayoutXmlPath
Write-Log "Set registry to use custom Taskbar layout for new profiles."

# ========== BLOCK APP REINSTALLATION ==========
Write-Log "Blocking Windows from reinstalling Outlook and inbox apps"

# Block Microsoft Consumer Features (including Outlook re-push)
try {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "DisableConsumerFeatures" -Value 1 -Type DWord
    Write-Log "Disabled Consumer Features (CloudContent)"
} catch {
    Write-Log "Failed to set DisableConsumerFeatures: $_"
}

# Block automatic reinstall of provisioned apps
try {
    $regPath2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (-not (Test-Path $regPath2)) {
        New-Item -Path $regPath2 -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath2 -Name "NoAutoApplicationPackageUpdates" -Value 1 -Type DWord
    Write-Log "Disabled Auto AppX reinstalls (Explorer)"
} catch {
    Write-Log "Failed to disable AppX auto reinstalls: $_"
}

# Optional: Disable Windows Spotlight which sometimes adds app suggestions
try {
    $regPath3 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    Set-ItemProperty -Path $regPath3 -Name "DisableWindowsSpotlightFeatures" -Value 1 -Type DWord
    Write-Log "Disabled Windows Spotlight Features"
} catch {
    Write-Log "Failed to disable Windows Spotlight Features: $_"
}

Write-Log "==== Outlook cleanup COMPLETE ===="
