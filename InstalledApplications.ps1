<#
.SYNOPSIS
    Software Inventory - Lists all installed applications with full details.

.DESCRIPTION
    Queries multiple sources to compile a comprehensive application inventory:
      - 64-bit registry hive
      - 32-bit registry hive (WOW6432Node)
      - Per-user registry hive (HKCU)
      - Windows Store / AppX packages (optional)
      - Optional approved list check (flags unapproved)

    Exports results to:
      - CSV (timestamped)
      - TXT report (timestamped)
      - HTML report (OVERWRITTEN each run as SoftwareInventory.html)

    Logging:
      - OVERWRITES C:\AppLog\SoftwareInventory.log each run
      - Writes ONLY:
          Starting
          HTML created successfully: <path>
          OR
          HTML creation failed: <explicit error details>
#>

[CmdletBinding()]
param(
    [string]$OutputPath        = "c:\temp",
    [string]$ApprovedListPath  = "",
    [switch]$IncludeStoreApps
)

# ─── Minimal Logging (OVERWRITE each run) ─────────────────────────────────────
$logDir  = "C:\AppLog"
$logFile = Join-Path $logDir "SoftwareInventory.log"

function Init-Log {
    try {
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Set-Content -Path $logFile -Value "Starting" -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}

function Log-Line {
    param([Parameter(Mandatory)][string]$Line)
    try {
        Add-Content -Path $logFile -Value $Line -Encoding UTF8
    } catch {
        # swallow logging failures
    }
}

$logReady = Init-Log

# ─── Helpers ──────────────────────────────────────────────────────────────────
function Write-Section {
    param([string]$Title)
    Write-Host "`n$("=" * 60)" -ForegroundColor Cyan
    Write-Host "  $Title"      -ForegroundColor Yellow
    Write-Host "$("=" * 60)"   -ForegroundColor Cyan
}

$lines = [System.Collections.Generic.List[string]]::new()
function Add-Line { param([string]$T = ""); $lines.Add($T); Write-Host $T }

function HtmlEncode([string]$s) {
    if ($null -eq $s) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($s)
}

# ─── Output Setup ─────────────────────────────────────────────────────────────
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $OutputPath "SoftwareInventory_$timestamp.txt"
$csvFile    = Join-Path $OutputPath "SoftwareInventory_$timestamp.csv"
$htmlFile   = Join-Path $OutputPath "SoftwareInventory.html"   # OVERWRITE each run

# Load approved list if provided
$approvedApps = @()
if ($ApprovedListPath -and (Test-Path $ApprovedListPath)) {
    $approvedApps = Get-Content $ApprovedListPath | Where-Object { $_ -match '\S' }
}

# ─── Collect from Registry ─────────────────────────────────────────────────────
function Get-RegistrySoftware {
    $regPaths = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*";              Arch = "64-bit" },
        @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*";  Arch = "32-bit" },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*";              Arch = "User"   }
    )

    $apps = foreach ($source in $regPaths) {
        Get-ItemProperty -Path $source.Path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "^\s*$" } |
            ForEach-Object {
                [PSCustomObject]@{
                    Source          = "Registry ($($source.Arch))"
                    Name            = $_.DisplayName.Trim()
                    Version         = if ($_.DisplayVersion) { $_.DisplayVersion } else { "N/A" }
                    Publisher       = if ($_.Publisher)      { $_.Publisher.Trim() } else { "Unknown" }
                    InstallDate     = $_.InstallDate
                    InstallLocation = $_.InstallLocation
                    Size_MB         = if ($_.EstimatedSize) { [math]::Round($_.EstimatedSize / 1024, 1) } else { 0 }
                    UninstallCmd    = $_.UninstallString
                }
            }
    }

    # Deduplicate by Name (keep first after sorting)
    return $apps |
        Sort-Object Name, Version |
        Group-Object Name |
        ForEach-Object { $_.Group | Select-Object -First 1 }
}

# ─── Main ─────────────────────────────────────────────────────────────────────
try {
    Write-Host "`nSoftware Inventory Tool" -ForegroundColor Green
    Write-Host "Collecting installed applications..." -ForegroundColor Gray

    Add-Line "============================================================"
    Add-Line "  SOFTWARE INVENTORY REPORT"
    Add-Line "  Generated : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-Line "  Computer  : $env:COMPUTERNAME"
    Add-Line "  User      : $env:USERNAME"
    Add-Line "============================================================"

    # ── Installed Applications ────────────────────────────────────────────────
    Write-Section "INSTALLED APPLICATIONS (Registry)"
    $software = Get-RegistrySoftware

    Add-Line "`n  Found $($software.Count) applications.`n"
    Add-Line ("  {0,-50} {1,-20} {2,-30} {3,-10}" -f "Application", "Version", "Publisher", "Size(MB)")
    Add-Line ("  {0,-50} {1,-20} {2,-30} {3,-10}" -f "-----------", "-------", "---------", "--------")

    $unapproved = [System.Collections.Generic.List[object]]::new()
    $htmlAppRows  = New-Object System.Collections.Generic.List[string]
    $htmlAppxRows = New-Object System.Collections.Generic.List[string]
    $appxApps = @()

    foreach ($app in $software | Sort-Object Name) {
        $isApproved = $true
        if ($approvedApps.Count -gt 0) {
            $isApproved = $approvedApps | Where-Object { $app.Name -like "*$_*" } | Select-Object -First 1
            if (-not $isApproved) { $isApproved = $false } else { $isApproved = $true }
        }

        $row = "  {0,-50} {1,-20} {2,-30} {3,-10}" -f `
            ($app.Name.Substring(0, [math]::Min(49, $app.Name.Length))), `
            ($app.Version.Substring(0, [math]::Min(19, $app.Version.Length))), `
            ($app.Publisher.Substring(0, [math]::Min(29, $app.Publisher.Length))), `
            $app.Size_MB

        if (-not $isApproved) {
            Write-Host $row -ForegroundColor Yellow
            $unapproved.Add($app)
        } else {
            Write-Host $row
        }
        $lines.Add($row)

        $cls = if (-not $isApproved) { " class='unapproved'" } else { "" }
        $htmlAppRows.Add((
            "<tr$cls>" +
            "<td>$(HtmlEncode $app.Source)</td>" +
            "<td>$(HtmlEncode $app.Name)</td>" +
            "<td>$(HtmlEncode $app.Version)</td>" +
            "<td>$(HtmlEncode $app.Publisher)</td>" +
            "<td>$(HtmlEncode $app.InstallDate)</td>" +
            "<td>$(HtmlEncode $app.InstallLocation)</td>" +
            "<td style='text-align:right'>$(HtmlEncode ($app.Size_MB.ToString()))</td>" +
            "<td>$(HtmlEncode $app.UninstallCmd)</td>" +
            "</tr>"
        ))
    }

    # ── Store Apps ────────────────────────────────────────────────────────────
    if ($IncludeStoreApps) {
        Write-Section "WINDOWS STORE / APPX APPLICATIONS"
        Add-Line "`n[AppX Packages]"

        try {
            $appxApps = Get-AppxPackage -AllUsers -ErrorAction Stop |
                        Where-Object { $_.IsFramework -eq $false } |
                        Select-Object Name, Version, Publisher |
                        Sort-Object Name

            Add-Line "  Found $($appxApps.Count) Store applications.`n"
            Add-Line ("  {0,-50} {1,-20} {2}" -f "Package Name", "Version", "Publisher")
            Add-Line ("  {0,-50} {1,-20} {2}" -f "------------", "-------", "---------")

            foreach ($a in $appxApps) {
                $v = $a.Version.ToString()
                $row = "  {0,-50} {1,-20} {2}" -f `
                    ($a.Name.Substring(0, [math]::Min(49, $a.Name.Length))), `
                    ($v.Substring(0, [math]::Min(19, $v.Length))), `
                    ($a.Publisher.Substring(0, [math]::Min(40, $a.Publisher.Length)))
                Add-Line $row

                $htmlAppxRows.Add(
                    "<tr>" +
                    "<td>$(HtmlEncode $a.Name)</td>" +
                    "<td>$(HtmlEncode $v)</td>" +
                    "<td>$(HtmlEncode $a.Publisher)</td>" +
                    "</tr>"
                )
            }

            # Add AppX to master list for CSV export
            $appxForCsv = $appxApps | ForEach-Object {
                [PSCustomObject]@{
                    Source          = "Windows Store"
                    Name            = $_.Name
                    Version         = $_.Version.ToString()
                    Publisher       = $_.Publisher
                    InstallDate     = "N/A"
                    InstallLocation = "N/A"
                    Size_MB         = 0
                    UninstallCmd    = "N/A"
                }
            }
            $software = @($software) + @($appxForCsv)

        } catch {
            Add-Line "  [ERROR] Could not retrieve Store apps: $($_.Exception.Message)"
        }
    }

    # ── Stats ─────────────────────────────────────────────────────────────────
    Write-Section "STATISTICS"
    $totalSizeMB = ($software | Measure-Object -Property Size_MB -Sum).Sum
    $sizeGB = [math]::Round(($totalSizeMB / 1024), 2)

    Add-Line "`n  Total applications   : $($software.Count)"
    Add-Line "  Total install size   : $sizeGB GB (estimated)"
    if ($approvedApps.Count -gt 0) {
        Add-Line "  Unapproved apps      : $($unapproved.Count)"
    }

    # ── CSV + TXT ─────────────────────────────────────────────────────────────
    $software | Export-Csv -Path $csvFile -NoTypeInformation
    $lines | Out-File -FilePath $reportFile -Encoding UTF8

    # ── HTML Creation (OVERWRITE) with explicit error logging ─────────────────
    try {
        $generated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Software Inventory - $($env:COMPUTERNAME)</title>
<style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; color: #1a1a1a; }

    /* Title bar only */
    .titlebar {
        background: #0b5cad;
        color: #ffffff;
        padding: 14px 16px;
        border-radius: 10px;
        margin-bottom: 14px;
    }
    .titlebar h1 { margin: 0; font-size: 22px; font-weight: 700; }
    .titlebar .sub { margin-top: 6px; font-size: 12px; opacity: 0.92; }

    .meta { color: #555; margin-bottom: 18px; }
    .warn { background:#fff3cd; border:1px solid #ffeeba; padding:10px; border-radius:8px; margin: 12px 0 18px 0;}
    table { border-collapse: collapse; width: 100%; margin: 10px 0 22px 0; table-layout: fixed; }
    th, td { border: 1px solid #ddd; padding: 8px; vertical-align: top; word-wrap: break-word; }
    th { background: #f4f6f8; text-align: left; }
    tr:nth-child(even) { background: #fafafa; }
    tr.unapproved { background: #fff3cd !important; }
    .small { font-size: 12px; color: #666; }
    .section { margin-top: 18px; }
</style>
</head>
<body>

<div class="titlebar">
  <h1>Software Inventory Report</h1>
  <div class="sub">Computer: $(HtmlEncode $env:COMPUTERNAME) | User: $(HtmlEncode $env:USERNAME) | Generated: $(HtmlEncode $generated)</div>
</div>

<div class="meta">
    <div><b>Total apps (incl. Store if selected):</b> $(HtmlEncode $software.Count)</div>
    <div><b>Estimated install size:</b> $(HtmlEncode $sizeGB) GB</div>
</div>

$(if ($approvedApps.Count -gt 0) {
    "<div class='warn'><b>Approved list check enabled.</b> Unapproved apps detected: <b>$($unapproved.Count)</b></div>"
} else { "" })

<div class="section">
<h2>Installed Applications (Registry)</h2>
<div class="small">Rows highlighted in yellow are not on the approved list (when provided).</div>
<table>
<thead>
<tr>
<th style="width:12%">Source</th>
<th style="width:18%">Name</th>
<th style="width:8%">Version</th>
<th style="width:12%">Publisher</th>
<th style="width:8%">InstallDate</th>
<th style="width:16%">InstallLocation</th>
<th style="width:6%; text-align:right">Size (MB)</th>
<th style="width:20%">UninstallCmd</th>
</tr>
</thead>
<tbody>
$($htmlAppRows -join "`n")
</tbody>
</table>
</div>

$(if ($IncludeStoreApps) {
@"
<div class="section">
<h2>Windows Store / AppX Applications</h2>
<table>
<thead>
<tr>
<th style="width:50%">Package Name</th>
<th style="width:20%">Version</th>
<th style="width:30%">Publisher</th>
</tr>
</thead>
<tbody>
$($htmlAppxRows -join "`n")
</tbody>
</table>
</div>
"@
} else { "" })

</body>
</html>
"@

        # Overwrite HTML each run
        Set-Content -Path $htmlFile -Value $html -Encoding UTF8 -ErrorAction Stop

        # Validate it exists and is non-empty
        if (-not (Test-Path $htmlFile)) {
            throw "HTML file does not exist after writing."
        }
        $len = (Get-Item $htmlFile -ErrorAction Stop).Length
        if ($len -le 0) {
            throw "HTML file was written but is empty."
        }

        if ($logReady) { Log-Line "HTML created successfully: $htmlFile" }

    } catch {
        # Be explicit in the log about what went wrong
        $msg = $_.Exception.Message
        $type = $_.Exception.GetType().FullName
        $category = $_.CategoryInfo.Category
        $target = $_.TargetObject

        $detail = "HTML creation failed: $msg | ExceptionType=$type | Category=$category"
        if ($target) { $detail += " | Target=$target" }
        $detail += " | HtmlPath=$htmlFile"

        if ($logReady) { Log-Line $detail }
        # Keep failure visible to caller
        throw
    }

} catch {
    # If you want *only* HTML status in the log, we do nothing else here.
    exit 1
}
