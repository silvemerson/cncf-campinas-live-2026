variable "target_node" {
  description = "Proxmox node name where the VM will run."
  type        = string
}

variable "vm_id" {
  description = "Unique VM ID in Proxmox cluster."
  type        = number

  validation {
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "vm_id must be between 100 and 999999999."
  }
}

variable "vm_name" {
  description = "VM hostname."
  type        = string

  validation {
    condition     = length(trim(var.vm_name, " ")) > 0
    error_message = "vm_name cannot be empty."
  }
}

variable "description" {
  description = "Free-text VM description shown in the Proxmox UI."
  type        = string
  default     = "Managed by Terraform - Talos node"
}

variable "talos_iso_id" {
  description = "Proxmox storage reference for the Talos nocloud ISO (e.g. local:iso/nocloud-amd64.iso)."
  type        = string
}

variable "vm_cores" {
  description = "vCPU core count."
  type        = number
  default     = 2

  validation {
    condition     = var.vm_cores >= 1 && var.vm_cores <= 128
    error_message = "vm_cores must be between 1 and 128."
  }
}

variable "vm_memory_mb" {
  description = "VM RAM in MiB."
  type        = number
  default     = 2048

  validation {
    condition     = var.vm_memory_mb >= 512
    error_message = "vm_memory_mb must be at least 512 MiB."
  }
}

variable "disk_size_gb" {
  description = "Boot disk size in GiB (must be >= template disk size)."
  type        = number
  default     = 20

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb must be at least 10 GiB."
  }
}

variable "disk_storage" {
  description = "Proxmox datastore for the VM boot disk."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox bridge for the primary NIC."
  type        = string
  default     = "vmbr0"
}

variable "network_vlan_id" {
  description = "VLAN ID (0 = no VLAN)."
  type        = number
  default     = 0
}

# ---------------------------------------------------------------------------
# Talos-specific
# ---------------------------------------------------------------------------
variable "snippets_datastore" {
  description = "Proxmox datastore for snippet files (must have 'snippets' content type enabled — usually 'local')."
  type        = string
  default     = "local"
}

variable "cloud_init_datastore" {
  description = "Proxmox datastore for the cloud-init drive."
  type        = string
  default     = "local-lvm"
}

variable "machine_config" {
  description = "Talos machineconfig YAML passed as nocloud user-data."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to the VM."
  type        = list(string)
  default     = ["terraform", "talos"]
}
