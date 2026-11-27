# Repository instructions

## Architecture

This repository provisions a development Azure network footprint with Terraform and the AzureRM provider.

- `main.tf` defines the root module:
  - Azure resource group
  - virtual network and application/data subnets
  - data-subnet network security group and two SQL-port inbound rules
- `variables.tf` declares deployment inputs.
- `terraform.tfvars` supplies the development environment, short name, and Azure region.
- The Terraform AzureRM backend stores remote state in `rg-cloudsentinel-tfstate/stcloudsentinel267418/tfstate/cloudsentinel-dev.tfstate` using Azure AD and Azure CLI authentication.
- `subscription_id` must be supplied separately (for example with `-var` or an environment variable); it is not set in `terraform.tfvars`.

The resources form one dependency chain: resource group -> virtual network -> subnets and NSG -> subnet association and NSG rules. Add Azure resources to `main.tf` and root-module inputs to `variables.tf`.

## Build and validation

Run commands from the repository root.

```bash
terraform fmt -recursive
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -var="subscription_id=<azure-subscription-id>"
terraform apply -var="subscription_id=<azure-subscription-id>"
```

Use `terraform plan -var="subscription_id=<azure-subscription-id>" -out=tfplan` to capture a plan, then `terraform apply tfplan` to apply it. Authentication and AzureRM backend access require an Azure CLI login with permissions to the subscription and remote state account.

## Conventions

- Resource names use descriptive CloudSentinel prefixes and environment suffixes: `rg-cloudsentinel-*`, `vnet-cloudsentinel-*`, `snet-cloudsentinel-*`, and `nsg-cloudsentinel-*`.
- Preserve explicit `resource_group_name`, `location`, and subnet associations by referencing Terraform resource attributes (`azurerm_resource_group.main.location`, for example) instead of duplicating names or regions.
- Keep environment-dependent names and values parameterized in `variables.tf` and `terraform.tfvars`; keep fixed topology values, such as address prefixes and NSG priorities, in `main.tf`.
- Tag resources with `environment` and `project = "cloudsentinel-ai"` when adding resource types that support tags.
- The data NSG permits TCP 1433 only from the application subnet and denies other virtual-network traffic to the data subnet prefix. Preserve this separation when changing NSG rules.
- Do not edit `.terraform/`, `.terraform.lock.hcl`, or Terraform state files manually. Commit `.terraform.lock.hcl` and configuration changes, but keep state and plan files out of source control.
