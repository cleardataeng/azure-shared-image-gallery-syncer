[CmdletBinding()]
param ()
$regionName = Get-VstsInput -Name regionName -Require
$buildResourceGroupName  = Get-VstsInput -Name buildResourceGroupName -Require
$buildVmUsername = Get-VstsInput -Name buildVmUsername
$buildVmPassword = Get-VstsInput  secret -Name buildVmPassword
$imageDefinitionName = Get-VstsInput -Name imageDefinitionName -Require
$os = Get-VstsInput -Name os -Require
$applicationId = Get-VstsInput -Name applicationId -Require
$secret = Get-VstsInput -Name secret -Require
$destinationTenantId = Get-VstsInput -Name destinationTenantId -Require
$destinationSubscriptionId = Get-VstsInput -Name destinationSubscriptionId -Require
$destinationGalleryResourceGroupName = Get-VstsInput -Name destinationGalleryResourceGroupName -Require
$destinationGalleryName = Get-VstsInput -Name destinationGalleryName -Require
$sourceResourceGroupName = Get-VstsInput -Name  sourceResourceGroupName 
$sourceGalleryName = Get-VstsInput -Name  sourceGalleryName
$sourceSubscriptionId = Get-VstsInput -Name  sourceSubscriptionId
$sourceTenantId = Get-VstsInput -Name  sourceTenantId

.\sync-gallery-script.ps1 -regionName $regionName -buildResourceGroupName $buildResourceGroupName -buildVmUsername $buildVmUsername -buildVmPassword $buildVmPassword -imageDefinitionName $imageDefinitionName -os $os -applicationId $applicationId -secret $secret -destinationTenantId $destinationTenantId -destinationSubscriptionId $destinationSubscriptionId -destinationGalleryResourceGroupName $destinationGalleryResourceGroupName  -destinationGalleryName $destinationGalleryName  -sourceResourceGroupName $sourceResourceGroupName  -sourceGalleryName $sourceGalleryName -sourceTenantId $sourceTenantId -sourceSubscriptionId $sourceSubscriptionId  