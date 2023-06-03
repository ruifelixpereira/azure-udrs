#!/bin/bash

############################################################
# Help                                                     #
############################################################
show_help()
{
   # Display Help
   echo "Create UDRs to force VNETs traffic going thru a Firewall."
   echo
   echo "Syntax: create-udr [-d|f|g|h]"
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
    export PARAMS_FILE="params.json"

    # Terraform service principal
    #export TF_VAR_client_id=$(jq -r '.auth.client_id' $PARAMS_FILE)
    #export TF_VAR_client_secret=$(jq -r '.auth.client_secret' $PARAMS_FILE)
    #export TF_VAR_tenant_id=$(jq -r '.auth.tenant_id' $PARAMS_FILE)

    # Firewall IP address to use in UDR routing rules
    export TF_VAR_firewall_ip=$(jq -r '.firewall_ip' $PARAMS_FILE)

    # Debug Terraform
    # Levels: TRACE, DEBUG, INFO, WARN or ERROR. 
    export TF_LOG=DEBUG
}

generate_files()
{
    load_variables

    # Reference VM to collect routes
    export VAR_reference_vm_for_routes_resource_group=$(jq -r '.reference_vm_for_routes.resource_group' $PARAMS_FILE)
    export VAR_reference_vm_for_routes_nic_name=$(jq -r '.reference_vm_for_routes.nic_name' $PARAMS_FILE)
    export VAR_reference_vm_subscription_id=$(jq -r '.reference_vm_for_routes.subscription_id' $PARAMS_FILE)


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
    # Get effective routes from reference VM
    echo "STEP (3/${numberOfSteps}) - Get effective routes."
    date
    az account set -s ${VAR_reference_vm_subscription_id}
    #az network nic show-effective-route-table -g ${VAR_reference_vm_for_routes_resource_group} -n ${VAR_reference_vm_for_routes_nic_name} --output json > list_routes.json
    GATEWAY_RULES_JSON=$(cat list_routes.json | jq  -r '.value | map(select(.nextHopType == "VirtualNetworkGateway")) | .[].addressPrefix[0]' | jq -Rcn '[inputs]')


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

        # Process VNET
        arrSpaces="[]"
        for row in $(echo $VAR_vnets_to_pair | jq -c '. | map(.) | .[]'); do
            _jq() {
                echo ${row} | jq -r "${1}"
            }
            MYVNET=$(_jq '.vnet')
            MYVNETRG=$(_jq '.rg')
            MYVNETSUBS=$(_jq '.subscription_id')

            # Get Address space
            az account set -s ${MYVNETSUBS}
            vnetLocation=$(az network vnet show -g ${MYVNETRG} -n ${MYVNET} --query "location" --output tsv)
            vnetSpaces=$(az network vnet show -g ${MYVNETRG} -n ${MYVNET} --query "addressSpace.addressPrefixes" --output json)
            if [ $? -ne 0 ]; then
                echo "Failed to get address space for ${MYVNETRG}/${MYVNET}"
                exit 1
            fi
            arrSpaces=$(jq --argjson arr1 "$arrSpaces" --argjson arr2 "$vnetSpaces" -n '$arr1 + $arr2')
        done
     
        MERGED_JSON=$(jq --argjson arr1 "$arrSpaces" --argjson arr2 "$GATEWAY_RULES_JSON" -n '$arr1 + $arr2 | unique')
        printf "%s" "$MYSEP \"$VNET\": {\"rg\":\"$VAR_vnet_rg\", \"location\": \"$vnetLocation\", \"alias\":\"sub$SUB_PROVIDER_ALIAS_COUNTER\", \"rules\":$MERGED_JSON}" >> $VNETSFILE
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
        #printf "%b\n" "provider \"azurerm\" {\n  alias = \"$SUBSC\"\n  subscription_id = \"$SUB_ID\"\n  tenant_id = var.tenant_id\n  client_id = var.client_id\n  client_secret = var.client_secret\n  skip_provider_registration = true\n  features {}\n}" >> provider.tf
        printf "%b\n" "provider \"azurerm\" {\n  alias = \"$SUBSC\"\n  subscription_id = \"$SUB_ID\"\n  skip_provider_registration = true\n  features {}\n}" >> provider.tf
        printf "%b\n" "module \"udr_creation_module_$SUBSC\" {\n  source = \"./modules/udr_creation\"\n  providers = {\n    azurerm = azurerm.$SUBSC\n  }\n  vnets = var.vnets\n  firewall_ip = var.firewall_ip\n  subscription_alias = [\"$SUBSC\"]\n  tags = var.tags\n}" >> main.tf
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
