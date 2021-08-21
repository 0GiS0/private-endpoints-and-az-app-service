#Common
LOCATION="northeurope"

###### Scenario 0: Create a new web app with a private endpoint ######

# 1. Create the resource group for the web app
WEB_APP_RESOURCE_GROUP="WebApp-With-Private-Endpoint"
az group create -n $WEB_APP_RESOURCE_GROUP --location $LOCATION

# 2. Create App Service Plan
APP_SERVICE_PLAN="PremiumPlan"

az appservice plan create \
--name $APP_SERVICE_PLAN \
--resource-group $WEB_APP_RESOURCE_GROUP \
--location $LOCATION \
--sku P1V2

# 3. Create Web App
WEBAPP_NAME="internalweb"

az webapp create \
--name $WEBAPP_NAME \
--resource-group $WEB_APP_RESOURCE_GROUP \
--plan $APP_SERVICE_PLAN

# 4. Create a VNET

WEB_APP_VNET_NAME="webapp-vnet"
WEB_APP_VNET_CIDR=10.10.0.0/16
WEB_APP_SUBNET_NAME="webapps"
WEB_APP_SUBNET_CIDR=10.10.1.0/24

az network vnet create \
--name $WEB_APP_VNET_NAME \
--resource-group $WEB_APP_RESOURCE_GROUP \
--location $LOCATION \
--address-prefixes $WEB_APP_VNET_CIDR \
--subnet-name $WEB_APP_SUBNET_NAME \
--subnet-prefixes $WEB_APP_SUBNET_CIDR

# 5. You need to update the subnet to disable private endpoint network policies. 
az network vnet subnet update \
--name $WEB_APP_SUBNET_NAME \
--resource-group $WEB_APP_RESOURCE_GROUP \
--vnet-name $WEB_APP_VNET_NAME \
--disable-private-endpoint-network-policies true

# 6. Create a Private Endpoint for the Web App
# 6. 1 Get the web app ID
WEBAPP_ID=$(az webapp show --name $WEBAPP_NAME --resource-group $WEB_APP_RESOURCE_GROUP --query id --output tsv)

WEB_APP_PRIVATE_ENDPOINT="webapp-private-endpoint"

# 6. 2 Create a Private Endpoint
az network private-endpoint create \
--name $WEB_APP_PRIVATE_ENDPOINT \
--resource-group $WEB_APP_RESOURCE_GROUP \
--vnet-name $WEB_APP_VNET_NAME \
--subnet $WEB_APP_SUBNET_NAME \
--connection-name "webapp-connection" \
--private-connection-resource-id $WEBAPP_ID \
--group-id sites

# 7. Create Private DNS Zone
az network private-dns zone create \
--name privatelink.azurewebsites.net \
--resource-group $WEB_APP_RESOURCE_GROUP

# 7.1 Link between my VNET and the Private DNS Zone
az network private-dns link vnet create \
--name "${WEB_APP_VNET_NAME}-link" \
--resource-group $WEB_APP_RESOURCE_GROUP \
--registration-enabled false \
--virtual-network $WEB_APP_VNET_NAME \
--zone-name privatelink.azurewebsites.net

# 7.2 Create a DNS zone group
az network private-endpoint dns-zone-group create \
--name "webapp-group" \
--resource-group $WEB_APP_RESOURCE_GROUP \
--endpoint-name $WEB_APP_PRIVATE_ENDPOINT \
--private-dns-zone privatelink.azurewebsites.net \
--zone-name privatelink.azurewebsites.net

###### Scenario 1: Access the web app from the same VNET ######

VM_SUBNET_NAME="vms"
VM_SUBNET_CIDR=10.10.2.0/24
VM_NAME="same-vnet-vm"

# 8. Create a new subnet in the VNET
az network vnet subnet create \
--name $VM_SUBNET_NAME \
--resource-group $WEB_APP_RESOURCE_GROUP \
--vnet-name $WEB_APP_VNET_NAME \
--address-prefixes $VM_SUBNET_CIDR

# 9. Create a VM in the new subnet
az vm create \
--name $VM_NAME \
--resource-group $WEB_APP_RESOURCE_GROUP \
--vnet-name $WEB_APP_VNET_NAME \
--subnet $VM_SUBNET_NAME \
--image "Win2019Datacenter" \
--admin-username "azureuser" \
--admin-password "P@ssw0rdforMe" \
--nsg-rule NONE

# 10. Create a bastion host
BASTION_PUBLIC_IP_NAME="bastion-public-ip"
BASTION_HOST_NAME="bastion-host"
BASTION_SUBNET_CIDR=10.10.3.0/27

# 10.1 Create a subnet for the bastion host
az network vnet subnet create \
--name AzureBastionSubnet \
--resource-group $WEB_APP_RESOURCE_GROUP \
--vnet-name $WEB_APP_VNET_NAME \
--address-prefixes $BASTION_SUBNET_CIDR

# 10.2 Create a public IP
az network public-ip create \
--resource-group $WEB_APP_RESOURCE_GROUP \
--name $BASTION_PUBLIC_IP_NAME \
--sku Standard --location $LOCATION

# 10.3 Create a bastion host
az network bastion create --name $BASTION_HOST_NAME \
--resource-group $WEB_APP_RESOURCE_GROUP \
--location $LOCATION \
--vnet-name $WEB_APP_VNET_NAME \
--public-ip-address $BASTION_PUBLIC_IP_NAME