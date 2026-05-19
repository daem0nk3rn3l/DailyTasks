#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Windows 11 Pro - Disk Cleanup automation ("Clean up system files" style), best-effort UI suppression.

.DESCRIPTION
  - Enumerates HKLM:\...\VolumeCaches handlers present on THIS system and enables them for a profile (StateFlags#### = 2).
  - Runs cleanmgr.exe /sagerun:n using that profile. /sagerun is the supported automation switch. 
  - Starts cleanmgr hidden to suppress UI (best-effort; cleanmgr can still spawn child UI in some cases).
  - Logs to C:\Temp\DiskCleanup.log and overwrites each run (no append).
#>

$ErrorActionPreference = 'Stop'

# ---------- Logging (overwrite, do not append) ----------
$LogDir  = 'C:\Temp'
$LogFile = Join-Path $LogDir 'DiskCleanup.log'

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

# Overwrite transcript each run
Start-Transcript -Path $LogFile -Force | Out-Null
$RunStart = Get-Date

try {
    Write-Host "=== Disk Cleanup started: $(Get-Date -Format o) ==="
    Write-Host "Log file (overwritten each run): $LogFile"

    # ---------- Profile selection ----------
    # This number is your "profile id" used by /sagerun:n and StateFlagsNNNN.
    $ProfileId = 1
    $StateFlagsName = ('StateFlags{0:D4}' -f $ProfileId)  # e.g., StateFlags0001

    # ---------- Registry root for Disk Cleanup handlers ----------
    $VolCacheRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'

    if (-not (Test-Path $VolCacheRoot)) {
        throw "VolumeCaches registry path not found: $VolCacheRoot"
    }

    # ---------- Exclusions (recommended) ----------
    # Downloads auto-cleanup is often not desired; SS64 calls it out as risky. [2](https://automatemyjob.co.uk/blog/powershell-script-cleanup-old-files-free-disk-space)
    $Exclude = @(
        'Downloads Folder'
    )

    # ---------- Clear existing StateFlags for this profile ----------
    Write-Host "Clearing existing $StateFlagsName values (if any)..."
    Get-ChildItem -Path $VolCacheRoot | ForEach-Object {
        Remove-ItemProperty -Path $_.PSPath -Name $StateFlagsName -ErrorAction SilentlyContinue
    }

    # ---------- Enable all handlers present on this machine ----------
    # Handler availability varies by system. [2](https://automatemyjob.co.uk/blog/powershell-script-cleanup-old-files-free-disk-space)
    Write-Host "Enabling Disk Cleanup handlers found on this system..."
    $enabled = 0
    $skipped = 0

    Get-ChildItem -Path $VolCacheRoot | ForEach-Object {
        $name = $_.PSChildName

        if ($Exclude -contains $name) {
            Write-Host "  Excluded: $name"
            $skipped++
            return
        }

        # Set StateFlags#### = 2 (include this handler for this profile)
        New-ItemProperty -Path $_.PSPath -Name $StateFlagsName -PropertyType DWord -Value 2 -Force | Out-Null
        Write-Host "  Enabled : $name"
        $enabled++
    }

    Write-Host "Handlers enabled: $enabled"
    Write-Host "Handlers skipped : $skipped"

    # ---------- Run Disk Cleanup using the saved profile ----------
    # /sagerun:n runs the tasks assigned to that profile id. 
    $CleanMgr = Join-Path $env:SystemRoot 'System32\cleanmgr.exe'
    if (-not (Test-Path $CleanMgr)) {
        throw "cleanmgr.exe not found: $CleanMgr"
    }

        $systemDrive = $env:SystemDrive.TrimEnd(':')
        $diskBefore = Get-PSDrive -Name $systemDrive

        Write-Host "Disk Cleanup start."
        Write-Host ("Disk space start: {0:N2} GB free of {1:N2} GB on {2}:" -f ($diskBefore.Free / 1GB), (($diskBefore.Used + $diskBefore.Free) / 1GB), $env:SystemDrive)
    Write-Host "Running Disk Cleanup in silent mode..."
    $taskName = "DiskCleanupSilent_$PID"
    $usedTask = $false

    try {
        # Running as SYSTEM in a hidden scheduled task prevents UI popups in user session.
        $action = New-ScheduledTaskAction -Execute $CleanMgr -Argument "/sagerun:$ProfileId"
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest -LogonType ServiceAccount
        $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $task = New-ScheduledTask -Action $action -Principal $principal -Settings $settings

        Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName
        $usedTask = $true

        do {
            Start-Sleep -Seconds 2
            $state = (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State
        } while ($state -eq 'Running')
    }
    catch {
        Write-Host "Scheduled task silent mode unavailable; falling back to hidden process start."
        $p = Start-Process -FilePath $CleanMgr `
                           -ArgumentList "/sagerun:$ProfileId" `
                           -PassThru `
                           -WindowStyle Hidden
        $p.WaitForExit()
        Start-Sleep -Seconds 2
    }
    finally {
        if ($usedTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        # cleanmgr can spawn additional cleanmgr processes; wait for any stragglers
        Get-Process cleanmgr -ErrorAction SilentlyContinue | Wait-Process -ErrorAction SilentlyContinue
    }

    $diskAfter = Get-PSDrive -Name $systemDrive
    Write-Host ("Disk space finish: {0:N2} GB free of {1:N2} GB on {2}:" -f ($diskAfter.Free / 1GB), (($diskAfter.Used + $diskAfter.Free) / 1GB), $env:SystemDrive)
    Write-Host "Disk Cleanup finished."

    $RunEnd = Get-Date
    Write-Host ("End Time: {0}" -f $RunEnd.ToString('dddd, MMM dd yyyy hh:mm:ss tt'))
    $duration = $RunEnd - $RunStart
    $durationText = "{0:00}:{1:00}:{2:00}" -f [int]$duration.TotalHours, $duration.Minutes, $duration.Seconds
    Write-Host ("Duration: {0}" -f $durationText)
    Write-Host "=== Completed ==="
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    throw
}
finally {
    Stop-Transcript | Out-Null
}
