# How to use this extension
The purpose of this extension and script is to allow the replication of a Shared Image Gallery image across tenants with the idea of applying additional scripts during the build process. This allows for better integration with a managed image provider that is providing specialized images from a Microsoft Azure Shared Image Gallery. This can be used from script or from Azure DevOps using the Sync Task

## Script Instructions
This is a two-step process:

1) From your subscription, authenticate in both the tenants using the Multi-Tenant App Registration.
2) Run the sync script from your providing variables for your source and destination subscriptions.

```powershell
$regionName = "" 
$buildResourceGroupName = ""
$buildVmUsername = ""
$buildVmPassword = ""
$imageDefinitionName   = ""
$os = ""
$applicationId  = ""
$secret   = ""
$destinationTenantId   = ""
$destinationSubscriptionId   = ""
$destinationGalleryResourceGroupName = "" 
$destinationGalleryName = ""
$sourceResourceGroupName = ""
$sourceGalleryName =""
$sourceTenantId = ""
$sourceSubscriptionId = ""

.\sync-gallery-script.ps1 -regionName $regionName -buildResourceGroupName $buildResourceGroupName -buildVmUsername $buildVmUsername -buildVmPassword $buildVmPassword -imageDefinitionName $imageDefinitionName -os $os -applicationId $applicationId -secret $secret -destinationTenantId $destinationTenantId -destinationSubscriptionId $destinationSubscriptionId -destinationGalleryResourceGroupName $destinationGalleryResourceGroupName  -destinationGalleryName $destinationGalleryName  -sourceResourceGroupName $sourceResourceGroupName  -sourceGalleryName $sourceGalleryName -sourceTenantId $sourceTenantId -sourceSubscriptionId $sourceSubscriptionId  

`

Azure Virtual Machine contstraints
https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftcompute

Sharing images across Tenants
https://docs.microsoft.com/en-us/azure/virtual-machines/windows/share-images-across-tenants


## Starter pipeline

```yaml
trigger:
- none

pool:
  vmImage: 'windows-latest'

steps:
- task: ClearDataGallerySync@0
  inputs:
    regionName: ''
    buildResourceGroupName: ''
    buildVmUsername: ''
    buildVmPassword: ''
    imageDefinitionName: ''
    os: ''
    applicationId: ''
    secret: '<windows or linux>'
    destinationTenantId: ''
    destinationSubscriptionId: ''
    destinationGalleryResourceGroupName: ''
    destinationGalleryName: ''
    sourceTenantId: ''
    sourceResourceGroupName: ''
    sourceGalleryName: ''
    outputFolder: '/output'

```



## Roadmap Features:
* Allow Powershell scripts for windows pipeline builds pulling from artifact in Azure Storage
* Allow Bash scripts for Linux pipeline builds pulling from artifact in Azure Storage
