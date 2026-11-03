# --- AKS Subnet ---

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.devops_rg.name
  virtual_network_name = azurerm_virtual_network.devops_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# --- Azure Container Registry ---

resource "azurerm_container_registry" "acr" {
  name                = "devopsacr${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.devops_rg.name
  location            = azurerm_resource_group.devops_rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "random_string" "acr_suffix" {
  length  = 6
  upper   = false
  special = false
}

# --- AKS Cluster ---

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "devops-aks"
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name
  dns_prefix          = "devopsaks"
  kubernetes_version  = "1.36.2"
  oidc_issuer_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_D2ds_v6"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
    orchestrator_version = "1.36.2"
    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.3.10"
    service_cidr   = "10.0.3.0/24"
  }
}

# --- ACR Pull Role Assignment ---

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}