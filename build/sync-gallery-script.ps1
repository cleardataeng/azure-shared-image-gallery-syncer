[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    $regionName,
    [Parameter(Mandatory)]
    $buildResourceGroupName,
    [Parameter(Mandatory)]
    $buildVmUsername,
    [Parameter(Mandatory)]
    [SecureString] $buildVmPassword,
    [Parameter(Mandatory)]
    $imageDefinitionName ,
    [Parameter(Mandatory)]
    $os ,
    [Parameter(Mandatory)]
    $applicationId,
    [Parameter(Mandatory)]
    [SecureString] $secret ,
    [Parameter(Mandatory)]
    $destinationTenantId ,
    [Parameter(Mandatory)]
    $destinationSubscriptionId ,
    [Parameter(Mandatory)]
    $destinationGalleryResourceGroupName,
    [Parameter(Mandatory)]
    $destinationGalleryName,
    [Parameter(Mandatory)]
    $sourceResourceGroupName,
    [Parameter(Mandatory)]
    $sourceGalleryName,
    [Parameter(Mandatory)]
    $sourceTenantId,
    [Parameter(Mandatory)]
    $sourceSubscriptionId
)

# We take the windows image name to deploy and rebuild it so not to exceed 15 characters. $buildVmName can technically be anything that meets azure vm constraints
# https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftcompute
$buildVmName = $imageDefinitionName.Replace("_","-")
$arr = $imageDefinitionName.Replace("_","-").ToCharArray()
[array]::Reverse($arr) 
if($os -eq "windows")
{
    $buildVmName = [String]::new($arr).Substring(0,14)
}

# This step is required to authenticate the application with both tenants so we can find and deploy the shared image. The azure app registration needs to be configured
# according to the following Microsoft documentation.
# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/share-images-across-tenants
Write-HOST ("Authorize App Id $applicationId" )  -ForegroundColor Green
az account clear

az login --service-principal -u $applicationId -p $secret --tenant $sourceTenantId
az account get-access-token

az login --service-principal -u $applicationId -p $secret --tenant $destinationTenantId
az account get-access-token 

# Checks to see if the build resource group exists and attempts to create it if it does not. 
# For the create to succeed you need to ensure the account has rights to create resource groups in the destination subscription.
$buildRsgExists = az group exists -n $buildResourceGroupName
if ($buildRsgExists -eq 'false') {
    az group create -l $regionName -n $buildResourceGroupName
}


$destinationGalleryResourceGroupExists = az group exists -n $destinationGalleryResourceGroupName
if ($destinationGalleryResourceGroupExists -eq 'false') {
     Write-HOST ("Could not find local image gallery. Please verify that the account $destinationGalleryResourceGroupName exists and can be accessed")  -ForegroundColor Red
     exit
}else
{
    Write-HOST ("Woot! Found local image gallery $destinationGalleryResourceGroupName" )  -ForegroundColor Green
}

## Getting Image The Definition in the Source Shared Image Gallery
if($imageDefinitionName)
{
    Write-HOST ("Getting Latest Remote Version" )  -ForegroundColor Green
    $goldenImageDefinition = az sig image-definition show --subscription $sourceSubscriptionId  --resource-group $sourceResourceGroupName  --gallery-name $sourceGalleryName --gallery-image-definition $imageDefinitionName -o json |ConvertFrom-Json
    $goldenImageVersions = az sig image-version list --subscription $sourceSubscriptionId --resource-group $sourceResourceGroupName --gallery-name $sourceGalleryName --gallery-image-definition $imageDefinitionName -o json |ConvertFrom-Json
    $latest = $goldenImageVersions[-1]
    $Publisher= $goldenImageDefinition.identifier.publisher
    $Offer = $goldenImageDefinition.identifier.offer 
    $sku = $goldenImageDefinition.identifier.sku 
    $os = $goldenImageDefinition.osType
}

az account set --subscription "$sourceSubscriptionId"
az account show

if($os -eq "linux")
{
    Write-HOST ("Creating Linux VM $buildVmName in subscription $destinationSubscriptionId" )  -ForegroundColor Green
    az vm create `
        --subscription $destinationSubscriptionId `
        --resource-group $buildResourceGroupName `
        --name $buildVmName `
        --image $latest.id `
        --admin-username $buildVmUsername `
        --generate-ssh-keys
    Write-HOST ("Linux VM Created" )  -ForegroundColor Green
}
elseif($os -eq "windows")
{
    Write-HOST ("Creating Windows VM $buildVmName in subscription $destinationSubscriptionId" )  -ForegroundColor Green
     az vm create `
        --subscription $destinationSubscriptionId `
        --resource-group $buildResourceGroupName `
        --name $buildVmName `
        --image $latest.id `
        --admin-username $buildVmUsername `
        --admin-password $buildVmPassword 
}
else
{
    Write-HOST ("Unsupported OS Type $os")  -ForegroundColor Red
}


az account set --subscription "$destinationSubscriptionId"

Write-HOST ("VM Checkup" )  -ForegroundColor Green

$buildVm = az vm show `
   --subscription $destinationSubscriptionId `
   --resource-group $buildResourceGroupName `
   --name $buildVmName -o json |ConvertFrom-Json

Write-HOST ("$buildVm" )  -ForegroundColor Magenta

Write-HOST ("Running customizations" )  -ForegroundColor Green
# Add any calls needed to apply customizations

# Run sysprep
if($os -eq "windows")
{
    az vm run-command invoke --command-id RunPowerShellScript -g $buildResourceGroupName -n $buildVmName --scripts '& \"C:\Windows\System32\Sysprep\Sysprep.exe\" /generalize /oobe /shutdown /quiet'
}

# Deallocating the Azure Virtual Machine
Write-HOST ("Deallocating Virtual Machine $buildVmName")  -ForegroundColor Green
az vm deallocate `
   --subscription $destinationSubscriptionId `
   --resource-group $buildResourceGroupName `
   --name $buildVmName


Write-HOST ("Marking Virtual Machine Generalized" )  -ForegroundColor Green
az vm generalize `
    --subscription $destinationSubscriptionId `
    --resource-group $buildResourceGroupName `
    --name $buildVmName


Write-HOST ("Create Image of VM for Gallery" )  -ForegroundColor Green
az image create `
   --subscription $destinationSubscriptionId `
   --resource-group $buildResourceGroupName `
   --name $sku --source $buildVmName 

Write-HOST ("Image created" )  -ForegroundColor Green
$imageId = az vm get-instance-view -g $buildResourceGroupName -n $buildVmName --query id

az account set --subscription $destinationSubscriptionId

#Check to see if the latest exists in the destination gallery 
Write-HOST ("Getting Latest Destination Shared Image Definition" )  -ForegroundColor Green

$ErrorActionPreference = "SilentlyContinue";
$localGoldenImageDefinition = az sig image-definition show --subscription $destinationSubscriptionId  --resource-group $destinationGalleryResourceGroupName  --gallery-name $destinationGalleryName --gallery-image-definition $imageDefinitionName -o json |ConvertFrom-Json
$ErrorActionPreference = "Continue";

if(!$localGoldenImageDefinition)
{
    Write-HOST ("Create Shared Image Definition" )  -ForegroundColor Green
    az sig image-definition create `
        --subscription $destinationSubscriptionId `
       --resource-group $destinationGalleryResourceGroupName `
       --gallery-name $destinationGalleryName `
       --gallery-image-definition $imageDefinitionName `
       --publisher $Publisher `
       --offer $Offer `
       --sku $SKU `
       --os-type $os  
    Write-HOST ("Shared Image Definition Added" )  -ForegroundColor Green
}
else {
    Write-HOST ("Shared Image Definition Exists" )  -ForegroundColor Green
}


$destinationGoldenImageVersions = az sig image-version list --subscription $destinationSubscriptionId --resource-group $destinationGalleryResourceGroupName --gallery-name $destinationGalleryName --gallery-image-definition $imageDefinitionName -o json |ConvertFrom-Json
$destinationGoldenImageVersion = $destinationGoldenImageVersions[-1]

if(!$destinationGoldenImageVersion)
{ 
    Write-HOST ("Create First Shared Image Version for Definition" )  -ForegroundColor Green
    az sig image-version create `
        --subscription $destinationSubscriptionId `
        --resource-group $destinationGalleryResourceGroupName `
        --gallery-name $destinationGalleryName `
        --gallery-image-definition $imageDefinitionName `
        --gallery-image-version $latest.name `
        --target-regions $regionName "southcentralus=1" "eastus=1=standard_zrs" `
        --replica-count 2 `
        --managed-image $imageId `
        --no-wait 
    Write-HOST ("Shared Image Version Added" )  -ForegroundColor Green
}
else
{
    if($latestLocal.Name -ne $latest.name)
    {
       Write-HOST ("Adding Shared Image Version" )  -ForegroundColor Green
       az sig image-version create `
           --subscription $destinationSubscriptionId `
           --resource-group $destinationGalleryResourceGroupName `
           --gallery-name $destinationGalleryName `
           --gallery-image-definition $imageDefinitionName `
           --gallery-image-version $latest.name `
           --target-regions $regionName "southcentralus=1" "eastus=1=standard_zrs" `
           --replica-count 2 `
           --managed-image $imageId `
           --no-wait 
        Write-HOST ("Shared Image Version Added" )  -ForegroundColor Green
    }
}
    
## CLEANUP
Write-HOST ("Tidying up build resource group" )  -ForegroundColor Yellow
## az group delete --name $buildResourceGroupName --subscription --yes
Write-Output ("Build resource group deleted") -ForegroundColor Green