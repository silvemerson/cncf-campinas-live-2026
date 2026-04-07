output "vm_id" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "vm_name" {
  description = "Proxmox VM name."
  value       = proxmox_virtual_environment_vm.this.name
}

output "target_node" {
  description = "Proxmox node where VM is deployed."
  value       = proxmox_virtual_environment_vm.this.node_name
}

output "primary_ip" {
  description = "First IPv4 reported by QEMU guest agent, if available."
  value = try(
    [
      for ip in flatten(proxmox_virtual_environment_vm.this.ipv4_addresses) : ip
      if !startswith(ip, "127.")
    ][0],
    null
  )
}
