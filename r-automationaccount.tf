# Create an Automation Account
# Remember to create a RunAsAccount before running the runbooks
resource "azurerm_automation_account" "automation-account" {
  name                = "${local.base_name}-aa"
  location            = local.region
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
  tags                = local.common_tags
}

# Add base module Az.Accounts
resource "azurerm_automation_module" "azaccounts-module" {
  name                    = "Az.Accounts"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts/2.4.0"
  }
}

# Then add modules that depends on the first one
# Use a foreach to lighten code
locals {
  az-modules = {
    "Az.Automation" = "1.7.0"
    "Az.Compute"    = "4.14.0"
    "Az.Resources"  = "4.2.0"
  }
}

resource "azurerm_automation_module" "az-modules" {
  depends_on = [
    azurerm_automation_module.azaccounts-module
  ]
  for_each                = local.az-modules
  name                    = each.key
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation-account.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/${each.key}/${each.value}"
  }
}
