#   Goes through present directory/sub-directories and installs .CAB files
#

$CabFileDirectory = ".\"

# Change to folder you want the LOG files to go to
$LogFolder = "C:\temp"
$LogFile = "$LogFolder\appInstall.log"


# Function to get timestamp
function Get-TimeStamp {
    return "[{0:yyyy-MM-dd HH:mm:ss}]" -f (Get-Date)
}

# Ensure log folder exists, if not, create it
if (!(Test-Path -Path $LogFolder)) {
    try {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
        Write-Output "$(Get-TimeStamp) Log folder created: $LogFolder" | Out-File -Append -FilePath $LogFile
    } catch {
        Write-Output "$(Get-TimeStamp) Failed to create log folder. Proceeding without logging." | Out-File -Append -FilePath $LogFile
    }
}

# Get all .CAB files in the directory 
$CabFiles = Get-ChildItem -Path $CabFileDirectory -Filter *.cab -Recurse

foreach ($CabFile in $CabFiles) {
    try {
        Write-Output "Installing $($CabFile.FullName)..." | Out-File -Append -FilePath $LogFile
        Add-WindowsPackage -Online -PackagePath $CabFile.FullName
        Write-Output "Successfully installed $($CabFile.Name)" | Out-File -Append -FilePath $LogFile
    } catch {
        Write-Output "Failed to install $($CabFile.Name): $_" | Out-File -Append -FilePath $LogFile
    }
}

Write-Output "All CAB file installations completed." | Out-File -Append -FilePath $LogFile
