#Requires -Modules Az.DesktopVirtualization, Az.Resources

$rgName = "wvdDemoEric"
$location = "eastus"
$subscription = ""
$adminUserName = "eric"
$adminPassword = (Get-Credential -UserName $adminUserName -Message "Enter your password").Password
$domainName = "wvdDemoEric.local"
$dnsPrefix = "ejwvd"
$vnetName = "adVNET"
$bastionHostName = "ejwvdBastion"
$vnetIpPrefix = "10.0.0.0/16"
$bastionSubnetIpPrefix = "10.0.1.0/24"


# Connect Azure Account
Connect-AzAccount -Subscription $subscription

#Create a resource group for all resources deployed
if($null -eq (Get-AzResourceGroup -Name $rgName))
{
    New-AzResourceGroup -Name $rgName -Location $location -for
}

#Deploy 2 Domain Controller load balanced with High Availability
New-AzResourceGroupDeployment -ResourceGroupName $rgName `
-TemplateUri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/application-workloads/active-directory/active-directory-new-domain-ha-2-dc-zones/azuredeploy.json `
 -adminUsername $adminUserName -adminPassword $adminPassword -location $location -domainName $domainName -dnsPrefix $dnsPrefix 

#Create subnet for Azure Bastion
$bastionSubnet = New-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -AddressPrefix $bastionSubnetIpPrefix
$virtualNetwork = Get-AzVirtualNetwork -Name $vnetName
Add-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -VirtualNetwork $virtualNetwork -AddressPrefix $bastionSubnetIpPrefix
$virtualNetwork | Set-AzVirtualNetwork

#Deploy Bastion Host for Secure connection
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateUri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.network/azure-bastion/azuredeploy.json `
-vnetName $vnetName -vnetIpPrefix $vnetIpPrefix -vnetNewOrExisting "existing" -bastionHostName $bastionHostName -location $location -bastionSubnetIpPrefix $bastionSubnetIpPrefix

#Deploy Windows 10 Client for domain connected fireshare and resources
$windows10EVD = Get-AzVMImageSku -Location "EastUS" -PublisherName "MicrosoftWindowsDesktop" -Offer "windows-evd"
