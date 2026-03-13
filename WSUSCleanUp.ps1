# WSUS Clean Up Wizard
# 12.24.25
#

# Declined updates from the WSUS database : 
# declined updates still reside inside the WSUS database and taking up disk space
# clean up wizard



$file = "c:\applog\WSUS_CleanUp_Wiz_{0:MMddyyyy_HHmm}.log" -f (Get-Date)
Start-Transcript -Path $file
$wsusserver = "NYCXXX"
[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")` | out-null
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($wsusserver, $False,8530);
$cleanupScope = new-object Microsoft.UpdateServices.Administration.CleanupScope;
$cleanupScope.DeclineSupersededUpdates    = $true
$cleanupScope.DeclineExpiredUpdates       = $true
$cleanupScope.CleanupObsoleteUpdates      = $true
$cleanupScope.CompressUpdates             = $false
$cleanupScope.CleanupObsoleteComputers    = $true
$cleanupScope.CleanupUnneededContentFiles = $true
$cleanupManager = $wsus.GetCleanupManager();
$cleanupManager.PerformCleanup($cleanupScope);
Stop-Transcript
