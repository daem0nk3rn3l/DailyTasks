# Pick files want to get information on
# HTML output to c:\temp, you would need to change if you want another location.
# =======================================================================================================================

Add-Type -AssemblyName System.Windows.Forms

# ---------------------------------------------------------------------------------------
# Folder Picker

$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Select a folder to scan"

$result = $folderBrowser.ShowDialog()

if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "No folder selected. Exiting..."
    exit
}

$selectedFolder = $folderBrowser.SelectedPath
$folderBrowser.Dispose()

Write-Host "Selected Folder: $selectedFolder"

# ---------------------------------------------------------------------------------------
# Get File Details

Write-Host "Scanning files..."

$fileDetails = Get-ChildItem -Path $selectedFolder -File | ForEach-Object {

    $versionInfo = $_.VersionInfo

    [PSCustomObject]@{
        FileName       = $_.Name
        FilePath       = $_.FullName
        ProductName    = $versionInfo.ProductName
        FileVersion    = $versionInfo.FileVersion
        ProductVersion = $versionInfo.ProductVersion
        CreationDate   = $_.CreationTime
    }
}

# ---------------------------------------------------------------------------------------
# CSS

$css = @"
<style>
body {
    font-family: Arial;
    margin: 20px;
    background-color: #f5f5f5;
}

h1 {
    color: #333;
}

table {
    border-collapse: collapse;
    width: 100%;
    background-color: white;
}

th {
    background-color: #4CAF50;
    color: white;
    padding: 8px;
    text-align: left;
}

td {
    border: 1px solid #ddd;
    padding: 8px;
}

tr:nth-child(even) {
    background-color: #f2f2f2;
}
</style>
"@

# ---------------------------------------------------------------------------------------
# Output File

$outputFile = "C:\Temp\ExecutableDetails.html"

Write-Host "Generating HTML report..."

$html = $fileDetails | ConvertTo-Html `
    -Head $css `
    -Title "Executable Details Report" `
    -PreContent "<h1>Executable Details Report</h1><p><b>Folder:</b> $selectedFolder</p>"

$html | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Report saved to: $outputFile"

# ---------------------------------------------------------------------------------------
# Open Report

Write-Host "Opening report..."

Invoke-Item $outputFile

Write-Host "Done."
