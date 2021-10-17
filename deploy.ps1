#Requires -Modules Az.DesktopVirtualization
#Requires -Modules Az.Resources
#Requires -Modules Az.StorageSync

$rgName = "wvdDemoEric"
$location = "eastus"
$adminUserName = "eric"
$adminPassword = (Get-Credential -UserName $adminUserName -Message "Enter your password").Password
$domainName = "wvdDemoEric.local"
$vnetName = "adVNET"
$bastionHostName = "ejwvdBastion"
$vnetIpPrefix = "10.0.0.0/16"
$bastionSubnetIpPrefix = "10.0.1.0/24"


$context = Get-AzContext
# Connect Azure Account
if($null -eq $context)
{
    $subscription = Read-Host "Please enter the subscription to target"
    Connect-AzAccount -Subscription $subscription
}
else
{
    Write-Host "Connecting to "$context.Subscription " in " $context.Environment
}


#Create a resource group for all resources deployed
if((Get-AzResourceGroup).ResourceGroupName -notmatch $rgName )
{
    New-AzResourceGroup -Name $rgName -Location $location -Force
}

$test = Get-AzResourceGroup -Name $rgname
while($null -eq $test)
{
    Start-Sleep 10
    $test = Get-AzResourceGroup -Name $rgname
}

#Deploy 2 Domain Controller load balanced with High Availability
Write-host "Deploying Domain Controllers this will take 5-10 minutes"
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateUri https://raw.githubusercontent.com/erjenkin/DigitalStorageArch/main/DeployDCs.json `
 -adminUsername $adminUserName -adminPassword $adminPassword -location $location -domainName $domainName -Verbose

#Create subnet for Azure Bastion
Write-host "Deploying Azure Bastion Service Subnet"
New-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -AddressPrefix $bastionSubnetIpPrefix
$virtualNetwork = Get-AzVirtualNetwork -Name $vnetName
Add-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -VirtualNetwork $virtualNetwork -AddressPrefix $bastionSubnetIpPrefix
$virtualNetwork | Set-AzVirtualNetwork

#Deploy Bastion Host for Secure connection
Write-host "Deploying Azure Bastion Service"
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateUri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.network/azure-bastion/azuredeploy.json `
-vnetName $vnetName -vnetIpPrefix $vnetIpPrefix -vnetNewOrExisting "existing" -bastionHostName $bastionHostName -location $location -bastionSubnetIpPrefix $bastionSubnetIpPrefix -Verbose

#Deploy on premises file server
Write-host "Deploying On Prem File Server"
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateUri https://raw.githubusercontent.com/erjenkin/DigitalStorageArch/main/OnPremFileServer.json `
-adminUsername $adminUserName -adminPassword $adminPassword -Verbose

#Deploy Windows 10 Client for domain connected fireshare and resources
Write-host "Deploying On Windows 10 Scale Sets"
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateUri https://raw.githubusercontent.com/erjenkin/DigitalStorageArch/main/windows10_scale.json `
-adminPassword $adminPassword -Verbose

#Create Sync Service
New-AzStorageSyncService -ResourceGroupName $rgName -Location $location -StorageSyncServiceName "myStorageSyncServiceName" -IncomingTrafficPolicy "AllowAllTraffic"

# Manually arun script to set on prem file server for connectivity

#Setup Sync services
$syncGroupName = "onPremSync"
$syncService = Get-AzStorageSyncService -Name "myStorageSyncServiceName" -ResourceGroupName $rgName
$syncGroup = New-AzStorageSyncGroup -ParentObject $syncService -Name $syncGroupName

# Get or create a storage account with desired name
$storageAccountName = "wvdemosa"
$storageAccount = Get-AzStorageAccount -ResourceGroupName $rgName  | Where-Object {
    $_.StorageAccountName -eq $storageAccountName
}

if ($null -eq $storageAccount) {
    $storageAccount = New-AzStorageAccount `
        -Name $storageAccountName `
        -ResourceGroupName $rgName  `
        -Location $location `
        -SkuName Standard_LRS `
        -Kind StorageV2 `
        -EnableHttpsTrafficOnly:$true
}

# Get or create an Azure file share within the desired storage account
$fileShareName = "wvdemosa"
$fileShare = Get-AzStorageShare -Context $storageAccount.Context | Where-Object {
    $_.Name -eq $fileShareName -and $_.IsSnapshot -eq $false
}

if ($null -eq $fileShare) {
    $fileShare = New-AzStorageShare -Context $storageAccount.Context -Name $fileShareName
}

# Create the cloud endpoint
New-AzStorageSyncCloudEndpoint `
    -Name $fileShare.Name `
    -ParentObject $syncGroup `
    -StorageAccountResourceId $storageAccount.Id `
    -AzureFileShareName $fileShare.Name


############################
#manually setup sync on prem server 
#C:\Program Files\Azure\StorageSyncAgent\ServerRegistration.exe
#THIS will generate your serverendpointpath

################
# manually added ServerEndpoint in Azure Portal

################
#manually setup storage account

#connect FileShare to win10clients with sync service

#join win10 servers to domain during deploy and change desktop background

# clean up resources
# Get-AzResourceGroup -name $rgName | Remove-AzResourceGroup -Force -AsJob


#Deploy Azure Backup and connect FileShare and Servers/Blob backup