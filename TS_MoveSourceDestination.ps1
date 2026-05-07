# Transfer of task sequence from source to desstination


# ================================
# MDT Task Sequence Move Script
# ================================

# --- CONFIGURATION ---
$SourceTSPath = "\\MDTSourceServer\DeploymentShare$\Control\TS001"   # Source Task Sequence folder
$DestTSPath   = "\\MDTDestServer\DeploymentShare$\Control\TS001"     # Destination Task Sequence folder
$LogFolder    = "C:\AppLog"
$LogFile      = "$LogFolder\MDT_TS_Move_$(Get-Date -Format yyyyMMdd_HHmmss).log"

# --- CREATE LOG FOLDER IF MISSING ---
if (!(Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

# --- LOGGING FUNCTION ---
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp  $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Output $entry
}

# --- START LOG ---
Write-Log "========== MDT Task Sequence Move Started =========="
Write-Log "Source: $SourceTSPath"
Write-Log "Destination: $DestTSPath"

try {
    # --- VALIDATE SOURCE ---
    if (!(Test-Path $SourceTSPath)) {
        throw "Source Task Sequence path does not exist: $SourceTSPath"
    }

    # --- CREATE DESTINATION FOLDER IF NEEDED ---
    if (!(Test-Path $DestTSPath)) {
        Write-Log "Destination folder does not exist. Creating..."
        New-Item -ItemType Directory -Path $DestTSPath -Force | Out-Null
    }

    # --- COPY TASK SEQUENCE ---
    Write-Log "Copying Task Sequence files..."
    Copy-Item -Path $SourceTSPath\* -Destination $DestTSPath -Recurse -Force -ErrorAction Stop

    Write-Log "Task Sequence copy completed successfully."

    # --- SUCCESS ---
    Write-Log "========== SUCCESS: MDT Task Sequence Move Completed =========="
}
catch {
    # --- FAILURE ---
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "========== FAILED: MDT Task Sequence Move Did NOT Complete =========="
}
finally {
    Write-Log "Script finished at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}
