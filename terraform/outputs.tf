output "control_plane_public_ip" {
  description = "Control plane public IP"
  value       = azurerm_public_ip.devops_public_ip.ip_address
}

output "worker1_public_ip" {
  description = "Worker 1 public IP"
  value       = azurerm_public_ip.worker1_public_ip.ip_address
}

output "worker2_public_ip" {
  description = "Worker 2 public IP"
  value       = azurerm_public_ip.worker2_public_ip.ip_address
}

output "vm_public_ip" {
   value = azurerm_public_ip.devops_public_ip.ip_address
}