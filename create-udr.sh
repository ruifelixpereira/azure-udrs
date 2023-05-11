#!/bin/bash

# Number of steps in this setup
numberOfSteps=6

########################################
# Setup TF variables"
echo "STEP (1/${numberOfSteps}) - Setup Terraform variables."
date

# Load environment settings
# <--- Customize file 'params.json' according to your environment --->
PARAMS_FILE="params.json"

# Terraform service principal
export TF_VAR_client_id=$(jq -r '.auth.client_id' $PARAMS_FILE)
export TF_VAR_client_secret=$(jq -r '.auth.client_secret' $PARAMS_FILE)
export TF_VAR_tenant_id=$(jq -r '.auth.tenant_id' $PARAMS_FILE)

# Firewall IP address to use in UDR routing rules
export TF_VAR_firewall_ip=$(jq -r '.firewall_ip' $PARAMS_FILE)

# Reference VM to collect routes
export VAR_reference_vm_for_routes_resource_group=$(jq -r '.reference_vm_for_routes.resource_group' $PARAMS_FILE)
export VAR_reference_vm_for_routes_nic_name=$(jq -r '.reference_vm_for_routes.nic_name' $PARAMS_FILE)
export VAR_reference_vm_subscription_id=$(jq -r '.reference_vm_for_routes.subscription_id' $PARAMS_FILE)


########################################
# Login
echo "STEP (2/${numberOfSteps}) - Login with service principal."
date
az login --service-principal --username $TF_VAR_client_id --password $TF_VAR_client_secret --tenant $TF_VAR_tenant_id

########################################
# Initialize subscriptions file

SUBSFILE="tmp_subscriptions.json"
echo "[" > $SUBSFILE
MYSUBSSEP=""
SUB_PROVIDER_ALIAS_COUNTER=0

########################################
# Get effective routes from reference VM
echo "STEP (3/${numberOfSteps}) - Get effective route."
date
az account set -s ${VAR_reference_vm_subscription_id}
#az network nic show-effective-route-table -g ${VAR_reference_vm_for_routes_resource_group} -n ${VAR_reference_vm_for_routes_nic_name} --output json
GATEWAY_RULES_JSON=$(cat list_routes.json | jq  -r '.value | map(select(.nextHopType == "VirtualNetworkGateway")) | .[].addressPrefix[0]' | jq -Rcn '[inputs]')

########################################
# Process list of VNETs
echo "STEP (4/${numberOfSteps}) - Process list of VNETs."
date
# Flat array of vnets
FLAT_VNETS_ARRAY=$(jq -r '.vnets[].vnet' $PARAMS_FILE)

# Clean file
PROCFILE="tmp_creation_vnets.json"
echo "[" > $PROCFILE
MYSEP=""

# For each vnet
for VNET in ${FLAT_VNETS_ARRAY}
do
    VNET_COMPLETE=$(cat $PARAMS_FILE | jq --arg vnet $VNET -r '.vnets | map(select(.vnet == $vnet)) | .[0]')
    export VAR_vnet_rg=$(echo $VNET_COMPLETE | jq -r '.rg')
    export VAR_vnet_subscription_id=$(echo $VNET_COMPLETE | jq -r '.subscription_id')
    export VAR_vnets_to_pair=$(cat $PARAMS_FILE | jq --arg vnet $VNET -r '.vnets | map(select(.vnet != $vnet)) ')

    # Add subscription to file
    SUB_PROVIDER_ALIAS_COUNTER=$((SUB_PROVIDER_ALIAS_COUNTER+1))
    printf "%s" "$MYSUBSSEP { \"alias\":\"sub$SUB_PROVIDER_ALIAS_COUNTER\", \"rg\":\"$VAR_vnet_subscription_id\"}" >> $SUBSFILE
    MYSUBSSEP=","

    # Process VNET
    arrSpaces=()
    for row in $(echo $VAR_vnets_to_pair | jq -c '. | map(.) | .[]'); do
        _jq() {
            echo ${row} | jq -r "${1}"
        }
        MYVNET=$(_jq '.vnet')
        MYVNETRG=$(_jq '.rg')

        # Get Address space
        az account set -s ${VAR_vnet_subscription_id}
        vnetSpaces=$(az network vnet show -g ${MYVNETRG} -n ${MYVNET} --query "addressSpace.addressPrefixes" --output tsv)
        if [ $? -ne 0 ]; then
            echo "Failed to get address space for ${MYVNETRG}/${MYVNET}"
            exit 1
        fi
        arrSpaces+=( $vnetSpaces )
    done
    MYSPACES=$(echo ${arrSpaces[@]})
    MYSPACES_JSON=$(echo "[\"$MYSPACES\"]" | jq 'map(. |= split(" ")) | flatten')
    MERGED_JSON=$(jq --argjson arr1 "$MYSPACES_JSON" --argjson arr2 "$GATEWAY_RULES_JSON" -n '$arr1 + $arr2 | unique')
    printf "%s" "$MYSEP { \"vnet\":\"$VNET\", \"rg\":\"$VAR_vnet_rg\", \"alias\":\"sub$SUB_PROVIDER_ALIAS_COUNTER\", \"rules\":$MERGED_JSON}" >> $PROCFILE
    MYSEP=","

done
echo "]" >> $PROCFILE
echo "]" >> $SUBSFILE


########################################
# Terraform steps
echo "STEP (3/${numberOfSteps}) - Terraform init."
date
#terraform init

echo "STEP (5/${numberOfSteps}) - Terraform plan."
date
#terraform plan -out main.tfplan

echo "STEP (6/${numberOfSteps}) - Terraform apply."
date
#terraform apply main.tfplan
