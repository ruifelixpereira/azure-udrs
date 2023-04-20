# UDRs for Firewalling templates using Terraform

These Terraform scripts are used to deploy UDRs to force the traffic to go through the Firewall, following this approach:

- [x] Create UDR for each Vnet with
  - Rules for each on-prem route (these rules are collected from the effective routes of a reference VM)
  - Rule per each Vnet peering
- [ ] Associate each UDR with all the subnets of the context Vnet
- [ ] Update the Hub Vnet UDR with the rules for each Vnet
- [ ] If needed, rollback (dissociate UDRs to all Vnet subnets and revert the changes made to the Hub UDR)


## How to run it

**Step 1.** Create a copy of file `sample.params.json` with the name `params.json` and customize it with your own settings:
- **auth** section: Terraform service principal to use in the deployment.
- **subscription_id**: Target Azure Subscription id.
- **firewall_ip**: Firewall IP used in the routes to forward traffic to.
- **new_udr** section: The resource group and the prefix name of the new UDRs to be created.
- **reference_vm_for_routes** section: Reference Virtual Machine used to collect the effective routes from on-premises.
- **vnets** section: List of VNETs for which we want to create UDRs.

**Step 2.** Just run the script `create-udr.sh`.

