resource "azurerm_resource_group" "rg" {
  name     = "${local.base_name}-rg"
  location = local.region

  tags = local.common_tags
}
