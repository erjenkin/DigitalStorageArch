#Requires -Modules Az.DesktopVirtualization
#Requires -Modules Az.Resources

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

#manually added nsg with rules for home access ip

#connect FileShare to win10clients with sync service

#join win10 servers to domain during deploy and change desktop background

# clean up resources
# Get-AzResourceGroup -name $rgName | Remove-AzResourceGroup -Force -AsJob
