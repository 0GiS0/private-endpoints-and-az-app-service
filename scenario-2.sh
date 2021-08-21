###### Scenario 2: Access a web app from a VM in a different VNET ######

# 11. Create a new resource group
OTHER_RESOURCE_GROUP="Other-VM-In-Another-VNet"
az group create -n $OTHER_RESOURCE_GROUP --location $LOCATION

# 12. Create a new VNET
OTHER_VNET_NAME="other-vnet"
OTHER_VNET_CIDR=10.20.0.0/16
OTHER_SUBNET_NAME="other-vms"
OTHER_SUBNET_CIDR=10.20.1.0/24

# 13. Create other VNET
az network vnet create \
--name $OTHER_VNET_NAME \
--resource-group $OTHER_RESOURCE_GROUP \
--location $LOCATION \
--address-prefixes $OTHER_VNET_CIDR \
--subnet-name $OTHER_SUBNET_NAME \
--subnet-prefixes $OTHER_SUBNET_CIDR

# 14. Create other VM in the other-vnet
az vm create \
--name $OTHER_VNET_NAME \
--resource-group $OTHER_RESOURCE_GROUP \
--vnet-name $OTHER_VNET_NAME \
--subnet $OTHER_SUBNET_NAME \
--image "Win2019Datacenter" \
--admin-username "azureuser" \
--admin-password "P@ssw0rdforMe" \
--nsg-rule NONE

# 15. Create a bastion host
BASTION_PUBLIC_IP_NAME="bastion-for-other-vnet-public-ip"
BASTION_HOST_NAME="bastion-for-other-vnet-host"
BASTION_SUBNET_CIDR=10.20.2.0/27

# 16 Create a subnet for the bastion host
az network vnet subnet create \
--name AzureBastionSubnet \
--resource-group $OTHER_RESOURCE_GROUP \
--vnet-name $OTHER_VNET_NAME \
--address-prefixes $BASTION_SUBNET_CIDR

# 17 Create a public IP
az network public-ip create \
--resource-group $OTHER_RESOURCE_GROUP \
--name $BASTION_PUBLIC_IP_NAME \
--sku Standard --location $LOCATION

# 18 Create a bastion host
az network bastion create --name $BASTION_HOST_NAME \
--resource-group $OTHER_RESOURCE_GROUP \
--location $LOCATION \
--vnet-name $OTHER_VNET_NAME \
--public-ip-address $BASTION_PUBLIC_IP_NAME


# 19. Create a peering between webapp and other-vnet. It has to be in both directions.
WEB_APP_VNET_ID=$(az network vnet show --name $WEB_APP_VNET_NAME --resource-group $WEB_APP_RESOURCE_GROUP --query id --output tsv)

az network vnet peering create \
--name "peering-with-webapp-vnet" \
--resource-group $OTHER_RESOURCE_GROUP \
--vnet-name $OTHER_VNET_NAME \
--remote-vnet $WEB_APP_VNET_ID \
--allow-vnet-access \
--allow-forwarded-traffic

OTHER_VNET_ID=$(az network vnet show --name $OTHER_VNET_NAME --resource-group $OTHER_RESOURCE_GROUP --query id --output tsv)

az network vnet peering create \
--name "peering-with-other-vnet" \
--resource-group $WEB_APP_RESOURCE_GROUP \
--vnet-name $WEB_APP_VNET_NAME \
--remote-vnet $OTHER_VNET_ID \
--allow-vnet-access \
--allow-forwarded-traffic

# 20. Link between other-vnet and the Private DNS Zone
az network private-dns link vnet create \
--name "${OTHER_VNET_NAME}-link" \
--resource-group $WEB_APP_RESOURCE_GROUP \
--registration-enabled false \
--virtual-network $OTHER_VNET_ID \
--zone-name privatelink.azurewebsites.net

