#!/bin/bash

############################################################
# Help                                                     #
############################################################
show_help()
{
   # Display Help
   echo "Associate UDRs with VNET subnets."
   echo
   echo "Syntax: associate-udr [-d|f|g|h]"
   echo "options:"
   echo "d     Deploy mode: only deploy with Terraform using pre-existing generated support files."
   echo "f     Full mode: generate support files and deploy with Terraform."
   echo "g     Generate mode: only generate support files and don't deploy with Terraform."
   echo "h     Print this Help."
   echo
}


############################################################
# Main program                                             #
############################################################

load_variables()
{
    # Number of steps in this setup
    numberOfSteps=7

    ########################################
    # Setup TF variables
    echo "STEP (1/${numberOfSteps}) - Setup Terraform variables."
    date

    # Load environment settings
    # <--- Customize file 'params.json' according to your environment --->
    export PARAMS_FILE="../params.json"

    # Debug Terraform
    # Levels: TRACE, DEBUG, INFO, WARN or ERROR. 
    export TF_LOG=DEBUG
}

generate_files()
{
    load_variables

    ########################################
    # Login
    echo "STEP (2/${numberOfSteps}) - Login with service principal."
    date
    #az login --service-principal --username $TF_VAR_client_id --password $TF_VAR_client_secret --tenant $TF_VAR_tenant_id

    ########################################
    # Initialize subscriptions file

    SUBSFILE="tmp_subscriptions.json"
    echo "[" > $SUBSFILE
    MYSUBSSEP=""
    SUB_PROVIDER_ALIAS_COUNTER=0

    ########################################
    # Process list of VNETs
    echo "STEP (4/${numberOfSteps}) - Process list of VNETs."
    date

    # Flat array of vnets
    FLAT_VNETS_ARRAY=$(jq -r '.vnets[].vnet' $PARAMS_FILE)

    # Clean file
    VNETSFILE="vnets.auto.tfvars.json"
    echo "{ \"vnets\": {" > $VNETSFILE
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

        printf "%s" "$MYSUBSSEP {\"alias\":\"sub$SUB_PROVIDER_ALIAS_COUNTER\", \"subscription_id\":\"$VAR_vnet_subscription_id\"}" >> $SUBSFILE
        MYSUBSSEP=","

        # Get VNET subnets
        az account set -s ${VAR_vnet_subscription_id}
        subnets=$(az network vnet subnet list -g ${VAR_vnet_rg} --vnet-name ${VNET} --query "[].name" --output tsv)
        if [ $? -ne 0 ]; then
            echo "Failed to get subnets list for ${VAR_vnet_rg}/${VNET}"
            exit 1
        fi
    
        # Get Subnet id
        arrSubnets="[]"
        for row in $subnets; do
            # Filter GatewaySubnet and AzureBastionSubnet
            if [ "$row" != "GatewaySubnet" ] && [ "$row" != "AzureBastionSubnet" ]; then
                # Get subnet id
                subnet_id=$(az network vnet subnet show -g $VAR_vnet_rg -n $row --vnet-name $VNET --query "id" --output json)
                if [ $? -ne 0 ]; then
                    echo "Failed to get subnets list for ${VAR_vnet_rg}/${VNET/${row}}"
                    exit 1
                fi
                arrSubnets=$(jq --argjson arr1 "$arrSubnets" --argjson arr2 "[$subnet_id]" -n '$arr1 + $arr2')
            fi
        done
     
        printf "%s" "$MYSEP \"$VNET\": {\"rg\":\"$VAR_vnet_rg\", \"alias\":\"sub$SUB_PROVIDER_ALIAS_COUNTER\", \"subnets\":$arrSubnets}" >> $VNETSFILE
        MYSEP=","
    done
    echo "} }" >> $VNETSFILE
    echo "]" >> $SUBSFILE

    ########################################
    # Generate new provider.tf and a new main.tf

    cp provider.tf.template provider.tf
    cp main.tf.template main.tf

    # Flat array of subscriptions
    FLAT_SUBS_ARRAY=$(jq -r '.[].alias' $SUBSFILE)

    # For each vnet
    for SUBSC in ${FLAT_SUBS_ARRAY}
    do
        SUB_ID=$(cat $SUBSFILE | jq --arg alias $SUBSC -r '. | map(select(.alias == $alias)) | .[0].subscription_id')
        printf "%b\n" "provider \"azurerm\" {\n  alias = \"$SUBSC\"\n  subscription_id = \"$SUB_ID\"\n  skip_provider_registration = true\n  features {}\n}" >> provider.tf
        printf "%b\n" "module \"udr_association_module_$SUBSC\" {\n  for_each = {\n    for k, v in var.vnets : k => v\n    if contains([\"$SUBSC\"], v.alias)\n  }\n  source = \"../modules/udr_association\"\n  providers = {\n    azurerm = azurerm.$SUBSC\n  }\n  udr_name = \"udr-\${each.key}\"\n  udr_resource_group_name = each.value.rg\n  subnets = each.value.subnets\n}" >> main.tf
    done
}


deploy_terraform()
{
    load_variables

    ########################################
    # Terraform steps
    echo "STEP (5/${numberOfSteps}) - Terraform init."
    date
    terraform init

    echo "STEP (6/${numberOfSteps}) - Terraform plan."
    date
    terraform plan -out main.tfplan

    echo "STEP (7/${numberOfSteps}) - Terraform apply."
    date
    terraform apply main.tfplan
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
DEPLOY_MODE=0
GENERATE_MODE=0

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

while getopts ":dfgh" option; do
   case $option in
      d) # Deploy with Terraform
         deploy_terraform
         exit
         ;;
      f) # Full: Generate files + Deploy
         generate_files
         deploy_terraform
         exit
         ;;
      g) # Generate files
         generate_files
         exit
         ;;
      h|\?) # display Help
         show_help
         exit 0
         ;;
   esac
done
