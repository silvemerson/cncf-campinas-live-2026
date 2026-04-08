# ---------------------------------------------------------------------------
# Proxmox provider
# ---------------------------------------------------------------------------
variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://192.168.1.100:8006"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token identifier in user@realm!token form."
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret value."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS cert verification when true."
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox host."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_password" {
  description = "SSH password for Proxmox host."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Proxmox placement
# ---------------------------------------------------------------------------
variable "target_node" {
  description = "Target Proxmox node."
  type        = string
  default     = "pve"
}

variable "disk_storage" {
  description = "Proxmox datastore for VM boot disks."
  type        = string
  default     = "local-lvm"
}

variable "cloud_init_datastore" {
  description = "Proxmox datastore for cloud-init drives."
  type        = string
  default     = "local-lvm"
}

variable "snippets_datastore" {
  description = "Proxmox datastore for snippet files — must have 'snippets' content type enabled (usually 'local')."
  type        = string
  default     = "local"
}

# ---------------------------------------------------------------------------
# Talos image
# ---------------------------------------------------------------------------
variable "talos_version" {
  description = "Talos version without the 'v' prefix (e.g. 1.9.5)."
  type        = string
}

variable "talos_schematic_id" {
  description = "Talos factory schematic ID (gerado em factory.talos.dev)."
  type        = string
}

variable "talos_iso_id" {
  description = "Proxmox storage reference for the Talos nocloud ISO (e.g. local:iso/nocloud-amd64.iso)."
  type        = string
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "network_bridge" {
  description = "Proxmox bridge for all cluster NICs."
  type        = string
  default     = "vmbr0"
}

variable "network_vlan_id" {
  description = "VLAN ID (0 = no VLAN)."
  type        = number
  default     = 0
}

variable "network_prefix" {
  description = "Subnet prefix length (e.g. 24 for /24)."
  type        = number
  default     = 24
}

variable "network_gateway_ipv4" {
  description = "Default IPv4 gateway for all cluster nodes."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers configured in each node's machineconfig."
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------
variable "cluster_name" {
  description = "Talos / Kubernetes cluster name."
  type        = string
}

variable "controlplane_vip" {
  description = "Virtual IP for the controlplane HA endpoint. Leave empty to use the first controlplane IP."
  type        = string
  default     = ""
}

variable "controlplane_ips" {
  description = "Static IPv4 addresses for controlplane nodes (3 recommended for HA)."
  type        = list(string)

  validation {
    condition     = length(var.controlplane_ips) >= 1
    error_message = "At least one controlplane IP is required."
  }
}

variable "worker_ips" {
  description = "Static IPv4 addresses for worker nodes."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Controlplane specs
# ---------------------------------------------------------------------------
variable "controlplane_start_id" {
  description = "Starting VMID for controlplane VMs."
  type        = number
  default     = 201
}

variable "controlplane_cores" {
  description = "vCPU count for controlplane nodes."
  type        = number
  default     = 2
}

variable "controlplane_memory_mb" {
  description = "RAM in MiB for controlplane nodes."
  type        = number
  default     = 2048
}

variable "controlplane_disk_gb" {
  description = "Boot disk size in GiB for controlplane nodes."
  type        = number
  default     = 20
}

# ---------------------------------------------------------------------------
# Worker specs
# ---------------------------------------------------------------------------
variable "worker_start_id" {
  description = "Starting VMID for worker VMs."
  type        = number
  default     = 211
}

variable "worker_cores" {
  description = "vCPU count for worker nodes."
  type        = number
  default     = 4
}

variable "worker_memory_mb" {
  description = "RAM in MiB for worker nodes."
  type        = number
  default     = 4096
}

variable "worker_disk_gb" {
  description = "Boot disk size in GiB for worker nodes."
  type        = number
  default     = 40
}

# ---------------------------------------------------------------------------
# Cilium CNI
# ---------------------------------------------------------------------------
variable "cilium_enabled" {
  description = "Install Cilium as CNI (disables Flannel and kube-proxy)."
  type        = bool
  default     = true
}

variable "cilium_version" {
  description = "Cilium Helm chart version."
  type        = string
  default     = "1.17.1"
}
