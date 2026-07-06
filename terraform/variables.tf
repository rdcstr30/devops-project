variable "location" {
  description = "Azure region"
  type        = string
  default     = "UAE North"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "devops-terraform-rg"
}

variable "admin_username" {
  description = "VM admin username"
  type        = string
  default     = "azureuser"
}

variable "control_plane_private_ip" {
  description = "Private IP of the K3s control plane node"
  type        = string
  default     = "10.0.1.4"
}

variable "k3s_token" {
  description = "K3s cluster join token"
  type        = string
  sensitive   = true
}