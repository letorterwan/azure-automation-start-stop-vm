terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = ">= 2.60.0"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription-id
}
