# UDRs for Firewalling templates using Terraform

These Terraform scripts are used to deploy UDRs to force the traffic to go through the Firewall, following this approach:

- [x] Create UDR for each Vnet with rules for each on-prem route (these rules are collected from the effective routes of a reference VM) and rules for each Vnet peering
- [ ] Associate each UDR with all the subnets of the context Vnet
- [ ] Update the Hub Vnet UDR with the rules for each Vnet
- [ ] If needed, rollback (dissociate UDRs to all Vnet subnets and revert the changes made to the Hub UDR)


## How to run it

**Step 1.** Login with `az login`.

**Step 2.** Create a copy of file `sample.params.json` with the name `params.json` and customize it with your own settings:
- **firewall_ip**: Firewall IP used in the routes to forward traffic to.
- **reference_vm_for_routes** section: Reference Virtual Machine used to collect the effective routes from on-premises.
- **vnets** section: List of VNETs for which we want to create UDRs.

**Step 3.** Run the script with the option to generate the configuration files first `create-udr.sh -g`. You can validate the generate files namely:
- **vnets.auto.tfvars.json**: VNET configuration and rules.
- **tmp_subscriptions.json**: List of subscriptions to consider.
- **provider.tf**: Terraform script with the provider aliases for each subscription.
- **main.tf**: Terraform script with a call to module *udr_creation* for each subscription.

**Step 4.** Run the script with the option to deploy with Terraform `create-udr.sh -d`.
