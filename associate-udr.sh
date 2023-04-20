#!/bin/bash

# Number of steps in this setup
numberOfSteps=6

########################################
# Setup TF variables"
echo "STEP (1/${numberOfSteps}) - Setup Terraform variables."

# Load environment settings
# <--- Customize file 'params.json' according to your environment --->
PARAMS_FILE="params.json"

# Terraform service principal
export TF_VAR_client_id=$(jq -r '.auth.client_id' $PARAMS_FILE)
export TF_VAR_client_secret=$(jq -r '.auth.client_secret' $PARAMS_FILE)
export TF_VAR_tenant_id=$(jq -r '.auth.tenant_id' $PARAMS_FILE)

# Azure Subscription id
export TF_VAR_subscription_id=$(jq -r '.subscription_id' $PARAMS_FILE)

# New UDR
export TF_VAR_udr_resource_group=$(jq -r '.new_udr.resource_group' $PARAMS_FILE)


########################################
# Login
echo "STEP (2/${numberOfSteps}) - Login with service principal."
az login --service-principal --username $TF_VAR_client_id --password $TF_VAR_client_secret --tenant $TF_VAR_tenant_id


########################################
# Process list of VNETs
echo "STEP (3/${numberOfSteps}) - Process list of VNETs."
# Flat array of vnets
FLAT_VNETS_ARRAY=$(jq -r '.vnets[].vnet' $PARAMS_FILE)

# Clean file
PROCFILE="tmp_association_subnets.json"
echo "[" > $PROCFILE
MYSEP=""

# For each vnet
for VNET in ${FLAT_VNETS_ARRAY}
do
    VNET_COMPLETE=$(cat $PARAMS_FILE | jq --arg vnet $VNET -r '.vnets | map(select(.vnet == $vnet)) | .[0]')
    MYVNETRG=$(echo $VNET_COMPLETE | jq -r '.rg')

    # Get VNET subnets
    subnets=$(az network vnet subnet list -g ${MYVNETRG} --vnet-name ${VNET} --query "[].name" --output tsv)
    if [ $? -ne 0 ]; then
        echo "Failed to get subnets list for ${MYVNETRG}/${MYVNET}"
        exit 1
    fi
    
    # Get Subnet id
    arrSubnets=()
    for row in $subnets; do
        # Filter GatewaySubnet and AzureBastionSubnet
        if [ "$row" != "GatewaySubnet" ] && [ "$row" != "AzureBastionSubnet" ]; then
            # Get subnet id
            subnet_id=$(az network vnet subnet show -g $MYVNETRG -n $row --vnet-name $VNET --query "id" --output tsv)
            if [ $? -ne 0 ]; then
                echo "Failed to get subnets list for ${MYVNETRG}/${VNET/${row}}"
                exit 1
            fi
            arrSubnets+=( $subnet_id )
        fi
    done
    MYSUBS=$(echo ${arrSubnets[@]})
    MYSUBS_JSON=$(echo "[\"$MYSUBS\"]" | jq 'map(. |= split(" ")) | flatten')
    printf "%s" "$MYSEP { \"vnet\":\"$VNET\", \"rg\":\"$MYVNETRG\", \"subnets\":$MYSUBS_JSON}" >> $PROCFILE
    MYSEP=","
done
echo "]" >> $PROCFILE

########################################
# Terraform steps
echo "STEP (3/${numberOfSteps}) - Terraform init."
terraform init

echo "STEP (5/${numberOfSteps}) - Terraform plan."
terraform plan -out main.tfplan

echo "STEP (6/${numberOfSteps}) - Terraform apply."
#terraform apply main.tfplan
