terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {}
}
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "main" {
  name     = "rg-cloudsentinel-${var.env-short-name}"
  location = var.location

  tags = {
    environment = var.environment
    project     = "cloudsentinel-ai"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-cloudsentinel-dev"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "application" {
  name                 = "snet-cloudsentinel-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "data" {
  name                 = "snet-cloudsentinel-data"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "data" {
  name                = "nsg-cloudsentinel-data"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    environment = "development"
    project     = "cloudsentinel-ai"
  }
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

resource "azurerm_network_security_rule" "allow_app_to_data" {
  name      = "AllowAppToData"
  priority  = 100
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range      = "*"
  destination_port_range = "1433"

  source_address_prefix      = azurerm_subnet.application.address_prefixes[0]
  destination_address_prefix = azurerm_subnet.data.address_prefixes[0]

  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.data.name
}

resource "azurerm_network_security_rule" "deny_other_vnet_to_data" {
  name      = "DenyOtherVNetToData"
  priority  = 200
  direction = "Inbound"
  access    = "Deny"
  protocol  = "*"

  source_port_range      = "*"
  destination_port_range = "*"

  source_address_prefix      = "VirtualNetwork"
  destination_address_prefix = azurerm_subnet.data.address_prefixes[0]

  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.data.name
}