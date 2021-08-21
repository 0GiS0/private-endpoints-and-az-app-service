###### Scenario 3: Access a web app from a VPN using transit routing ######

# 17. Create a VPN Gateway to connect wit my machine
VPN_GATEWAY_NAME="gateway"
VPN_GATEWAY_CIDR=10.20.3.0/24

# 17.1. Create a subnet for the VPN Gateway
az network vnet subnet create \
  --vnet-name $OTHER_VNET_NAME \
  --name GatewaySubnet \
  --resource-group $OTHER_RESOURCE_GROUP \
  --address-prefix $VPN_GATEWAY_CIDR

# 18. Create a public IP for the VPN Gateway
az network public-ip create \
  --name "${VPN_GATEWAY_NAME}-ip" \
  --resource-group $OTHER_RESOURCE_GROUP \
  --allocation-method Dynamic 

# 19. Define CIDR block for the VPN clients
ADDRESS_POOL_FOR_VPN_CLIENTS=10.30.0.0/16

# Azure Active Directory info
#https://login.microsoftonline.com/e26de2cd-b981-4ec4-a628-95cb1e11debf
TENANT_ID="e26de2cd-b981-4ec4-a628-95cb1e11debf"
AZURE_VPN_CLIENT_ID="41b23e61-6c1e-4545-b367-cd054e0ed4b4"
#You have to consent Azure VPN application in your tenant first:
https://login.microsoftonline.com/common/oauth2/authorize?client_id=41b23e61-6c1e-4545-b367-cd054e0ed4b4&response_type=code&redirect_uri=https://portal.azure.com&nonce=1234&prompt=admin_consent

# 20. Create a VPN Gateway
az network vnet-gateway create \
  --name $VPN_GATEWAY_NAME \
  --location $LOCATION \
  --public-ip-address "${VPN_GATEWAY_NAME}-ip" \
  --resource-group $OTHER_RESOURCE_GROUP \
  --vnet $OTHER_VNET_NAME \
  --gateway-type Vpn \
  --sku VpnGw2 \
  --vpn-type RouteBased \
  --address-prefixes $ADDRESS_POOL_FOR_VPN_CLIENTS \
  --client-protocol OpenVPN \
  --vpn-auth-type AAD \
  --aad-tenant "https://login.microsoftonline.com/${TENANT_ID}" \
  --aad-audience $AZURE_VPN_CLIENT_ID \
  --aad-issuer "https://sts.windows.net/${TENANT_ID}/"


# 21. Get VPN client configuration
az network vnet-gateway vpn-client generate \
--resource-group $OTHER_RESOURCE_GROUP \
--name $VPN_GATEWAY_NAME

# 22. Update peering to use transit routing
az network vnet peering update \
--name "peering-with-webapp-vnet" \
--resource-group $OTHER_RESOURCE_GROUP \
--vnet-name $OTHER_VNET_NAME \
--set allowGatewayTransit=true

az network vnet peering update \
--name "peering-with-other-vnet" \
--resource-group $WEB_APP_RESOURCE_GROUP \
--vnet-name $WEB_APP_VNET_NAME \
--set useRemoteGateways=true