
# http://woshub.com/write-output-log-files-powershell/
# System Information Output
# 12.24.25
#

$LogFile = "C:\Temp\$env:computername.log"
# $LogFile = ".\$env:computername.log"


Write-Host "$LogMessage`n`r" -foregroundcolor green


function Writelog
{

Param ([string]$LogString)
$Stamp = (Get-Date).toString("MM/dd/yyyy")
$LogMessage = "$Stamp.$LogString"
Add-content $LogFile -value $LogMessage
Write-Host "$LogMessage`n`r" -foregroundcolor green


}

If(Test-Path -Path $Logfile) {Remove-Item -Path $Logfile}




WriteLog "The script is run"
WRiteLog "Processing...."
# Start-Sleep 20
WriteLog "The Script has successfully executed"



#  Use `n to Add a New Line to Command Output in PowerShell
#  "." local computer 

$ArrComputers =  "."

#Specify the list of PC names in the line above. "." means local system


Clear-Host

foreach ($Computer in $ArrComputers) 
    {
    Try {
    $computerSystem = get-wmiobject Win32_ComputerSystem -Computer $Computer
    $computerBIOS = get-wmiobject Win32_BIOS -Computer $Computer
    $computerOS = get-wmiobject Win32_OperatingSystem -Computer $Computer
    $computerCPU = get-wmiobject Win32_Processor -Computer $Computer
    $computerHDD = Get-WmiObject Win32_LogicalDisk -ComputerName $Computer -Filter drivetype=3
    }
    catch {}

    write-host "System Information for: " $computerSystem.Name -BackgroundColor DarkCyan
        "--------------------------------------------------------------------------------------------"
        "Manufacturer:      " + $computerSystem.Manufacturer
        "Model:             " + $computerSystem.Model
        "Serial Number:     " + $computerBIOS.SerialNumber
        "CPU:               " + $computerCPU.Name + "`n"

     $drives = ""
   

        ForEach ($hdd in $computerHDD)

            {
          $drives += "Drive Letter:" + $hdd.DeviceID + `
            " HDD Capacity:       " + "{0:N2}" -f ($HDD.Size/1GB) + "GB" + `
            " HDD Space:          " + "{0:P2}" -f ($HDD.FreeSpace/$hDD.Size) + " Free (" + "{0:N2}" -f ($hdd.FreeSpace/1GB) + "GB)" + "`n"
            }

         $drives

        "BIOS:              " + $computerBIOS.SMBIOSBIOSVersion + ", Manufacture: " + $computerBIOS.Manufacturer + ", Version: " + $computerBIOS.Version                   
        "RAM:               " + "{0:N2}" -f ($computerSystem.TotalPhysicalMemory/1GB) + "GB"
        "Operating System:  " + $computerOS.caption + ", Service Pack: " + $computerOS.ServicePackMajorVersion
        "User logged In:    " + $computerSystem.UserName
        "Last Reboot:       " + $computerOS.ConvertToDateTime($computerOS.LastBootUpTime)
        ""
        "--------------------------------------------------------------------------------------------"

        $myObject = [PSCustomObject]@{
    ComputerUserName   = $computerSystem.UserName
    BIOSVerson         = $computerBIOS.SMBIOSBIOSVersion
    Manufacturer       = $computerBIOS.Manufacturer
    Version            = $computerBIOS.Version
}

# $myObject | ConvertTo-Html | Out-File c:\temp\SysOS.html
# $myObject | Out-GridView 
}
