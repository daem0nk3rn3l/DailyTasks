# Define log folder and file
# By default Windows Office updates are turned off users cannot manually update Office
# ==========================================================================================
$LogFolder = "C:\applogs"
$LogFile = Join-Path $LogFolder "OfficeMgmtCOM_Check.log"

# Create log folder if missing
if (!(Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

# Function to write to log
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp - $Message"
}

Write-Log "Script started."

# Registry path and value
$RegPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$ValueName = "OfficeMgmtCOM"

try {
    # Read current value
    $currentValue = (Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop).$ValueName
    Write-Log "Current OfficeMgmtCOM value: $currentValue"
}
catch {
    Write-Log "OfficeMgmtCOM not found. Creating it."
    $currentValue = $null
}

# If value is not 0/False, set it
if ($currentValue -ne 0 -and $currentValue -ne $false) {
    try {
        Set-ItemProperty -Path $RegPath -Name $ValueName -Value 0 -Force
        Write-Log "OfficeMgmtCOM was updated to FALSE (0)."
    }
    catch {
        Write-Log "ERROR: Failed to set OfficeMgmtCOM. $_"
    }
}
else {
    Write-Log "OfficeMgmtCOM already set to FALSE (0). No change needed."
}

Write-Log "Script finished."
