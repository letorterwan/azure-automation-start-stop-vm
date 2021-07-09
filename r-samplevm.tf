# All resources stated here are only for demo/test purpose.
# This file should not be used for real-life deployments
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.base_name}-vnet"
  location            = local.region
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "${local.base_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_interface" "sample-vm-nic" {
  name                = "${local.base_name}-sample-vm-nic"
  location            = local.region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "sample-vm" {
  name                            = "poc-vm1"
  location                        = local.region
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B2s"
  admin_username                  = "adminuser"
  admin_password                  = "MySuperSecuredPwd123"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.sample-vm-nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = merge(local.common_tags, local.vm_tags)
}
