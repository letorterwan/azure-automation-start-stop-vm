# Create an Automation Account
# Remember to create a RunAsAccount before running the runbooks
resource "azurerm_automation_account" "automation-account" {
  name                = "${local.base_name}-aa"
  location            = local.region
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
  tags                = local.common_tags
}