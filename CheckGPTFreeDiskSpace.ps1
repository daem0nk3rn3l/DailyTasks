# Check disk space
# Check if disk is GPT
# ======================================================================================
# Define logging setup
# ======================================================================================
$logFolder = "C:\applog"
$logFile = "$logFolder\VerboseFreeSpaceCheck.log"

# Ensure log folder exists
if (!(Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timeStamp - $Message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry -ForegroundColor $Color
}

# Start session
Write-Log "========== SCRIPT START ==========" Yellow
Write-Log "Script STARTED" Yellow

# Step 1: Check free space
Write-Log "Checking free space on C:\" Yellow
$drive = Get-PSDrive C
$freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
Write-Log "Free space on C:\ is $freeSpaceGB GB" Cyan

# Step 2: Evaluate first condition (free space > 65GB)
$condition1 = $freeSpaceGB -gt 65
Write-Log "Condition 1 (Free space > 65 GB): $condition1" Cyan

# Step 3: Check if disk containing C: is GPT
Write-Log "Checking if system disk is GPT..." Yellow
$partition = Get-Partition -DriveLetter C
$disk = Get-Disk -Number $partition.DiskNumber
$partitionStyle = $disk.PartitionStyle
$condition2 = $partitionStyle -eq "GPT"
Write-Log "Condition 2 (Partition style = GPT): $condition2" Cyan

# Step 4: Decision
if ($condition1 -and $condition2) {
    Write-Log "Both conditions met (Free space > 65GB AND GPT). Script will STOP." Red
    Write-Log "========== SCRIPT STOPPED ==========" Red
    exit 1
} else {
    Write-Log "Conditions not fully met. Script will CONTINUE." Green
}

# Step 5: Run main script tasks (verbose)
Write-Log "Starting main script tasks..." Cyan
try {
    # Example tasks (replace with actual commands)
    Write-Log "Task 1: Placeholder command executed." Cyan
    Start-Sleep -Seconds 1
    Write-Log "Task 2: Another placeholder command executed." Cyan
    Start-Sleep -Seconds 1

    # Step 6: Finish
    Write-Log "Script FINISHED successfully." Blue
    Write-Log "========== SCRIPT FINISH ==========" Blue
    exit 0
} catch {
    Write-Log "Script encountered an error: $($_.Exception.Message)" Red
    Write-Log "========== SCRIPT STOPPED ==========" Red
    exit 1
}
