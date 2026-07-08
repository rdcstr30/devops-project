resource "azurerm_resource_group" "devops_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "devops_vnet" {
  name                = "devops-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name
}

resource "azurerm_subnet" "devops_subnet" {
  name                 = "devops-subnet"
  resource_group_name  = azurerm_resource_group.devops_rg.name
  virtual_network_name = azurerm_virtual_network.devops_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "devops_public_ip" {
  name                = "devops-public-ip"
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "devops_nsg" {
  name                = "devops-nsg"
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name

}

resource "azurerm_network_interface" "devops_nic" {
  name                = "devops-nic"
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.devops_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.devops_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "devops_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.devops_nic.id
  network_security_group_id = azurerm_network_security_group.devops_nsg.id
}

resource "azurerm_linux_virtual_machine" "devops_vm" {
  name                = "devops-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2als_v2"
  admin_username      = var.admin_username


  network_interface_ids = [
    azurerm_network_interface.devops_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa_azure.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  lifecycle {
    ignore_changes = [
      admin_ssh_key,
      custom_data,
    ]
  }
}

# --- NSG rules for K3s inter-node communication ---

resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.devops_rg.name
  network_security_group_name = azurerm_network_security_group.devops_nsg.name
}

resource "azurerm_network_security_rule" "k3s_api" {
  name                        = "K3s-API-Server"
  priority                    = 1040
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.devops_rg.name
  network_security_group_name = azurerm_network_security_group.devops_nsg.name
}

resource "azurerm_network_security_rule" "k3s_flannel" {
  name                        = "K3s-Flannel-VXLAN"
  priority                    = 1020
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "8472"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.devops_rg.name
  network_security_group_name = azurerm_network_security_group.devops_nsg.name
}

resource "azurerm_network_security_rule" "k3s_kubelet" {
  name                        = "K3s-Kubelet-API"
  priority                    = 1030
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "10250"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.devops_rg.name
  network_security_group_name = azurerm_network_security_group.devops_nsg.name
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "allow-http"
  priority                    = 1012
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.devops_rg.name
  network_security_group_name = azurerm_network_security_group.devops_nsg.name
}

resource "azurerm_network_security_rule" "allow_https" {
  name                        = "allow-https"
  priority                    = 1013
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.devops_rg.name
  network_security_group_name = azurerm_network_security_group.devops_nsg.name
}

resource "azurerm_network_security_rule" "allow_nodeport" {
  name                        = "allow-k8s-nodeport"
  priority                    = 1011
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "30007-32767"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.devops_rg.name
  network_security_group_name = azurerm_network_security_group.devops_nsg.name
}

resource "azurerm_network_security_rule" "allow_app" {
  name                        = "allow-app"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5000"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.devops_rg.name
  network_security_group_name = azurerm_network_security_group.devops_nsg.name
}

# --- Worker Node 1 ---

resource "azurerm_public_ip" "worker1_public_ip" {
  name                = "worker1-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "worker1_nic" {
  name                = "worker1-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.devops_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.5"
    public_ip_address_id          = azurerm_public_ip.worker1_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "worker1_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.worker1_nic.id
  network_security_group_id = azurerm_network_security_group.devops_nsg.id
}

resource "azurerm_linux_virtual_machine" "worker1" {
  name                = "worker1"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_D2ds_v6"
  admin_username      = var.admin_username

  custom_data = base64encode(templatefile("${path.module}/cloud-init-worker.yaml", {
    control_plane_ip = var.control_plane_private_ip
    k3s_token        = var.k3s_token
  }))

  network_interface_ids = [
    azurerm_network_interface.worker1_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa_azure.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# --- Worker Node 2 ---

resource "azurerm_public_ip" "worker2_public_ip" {
  name                = "worker2-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "worker2_nic" {
  name                = "worker2-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.devops_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.6"
    public_ip_address_id          = azurerm_public_ip.worker2_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "worker2_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.worker2_nic.id
  network_security_group_id = azurerm_network_security_group.devops_nsg.id
}

resource "azurerm_linux_virtual_machine" "worker2" {
  name                = "worker2"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_D2ds_v6"
  admin_username      = var.admin_username

  custom_data = base64encode(templatefile("${path.module}/cloud-init-worker.yaml", {
    control_plane_ip = var.control_plane_private_ip
    k3s_token        = var.k3s_token
  }))

  network_interface_ids = [
    azurerm_network_interface.worker2_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa_azure.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}