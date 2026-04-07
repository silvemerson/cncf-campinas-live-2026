terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.96.0"
    }
  }
}

# Upload machineconfig YAML as a Proxmox snippet so it can be referenced
# by the cloud-init drive as user-data. Talos nocloud reads it on first boot.
resource "proxmox_virtual_environment_file" "machine_config" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.target_node

  source_raw {
    data      = var.machine_config
    file_name = "${var.vm_name}-machineconfig.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  node_name = var.target_node
  vm_id     = var.vm_id
  name      = var.vm_name
  tags      = sort(var.tags)

  description = var.description

  machine       = "q35"
  scsi_hardware = "virtio-scsi-pci"

  cpu {
    cores   = var.vm_cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  agent {
    enabled = true
    trim    = true
    timeout = "30s"
  }

  network_device {
    bridge   = var.network_bridge
    firewall = false
    model    = "virtio"
    vlan_id  = var.network_vlan_id
  }

  # Boot disk — created empty. SeaBIOS skips it on first boot (empty),
  # falls to the ISO CDROM. Talos installs here, then boots from disk on reboot.
  disk {
    interface    = "scsi0"
    datastore_id = var.disk_storage
    size         = var.disk_size_gb
    discard      = "on"
    ssd          = true
    file_format  = "raw"
  }

  # Talos ISO — OVMF detects the EFI boot entry on the ISO and boots from it.
  # After Talos installs to scsi0 and reboots, OVMF uses the entry on the EFI disk.
  cdrom {
    file_id   = var.talos_iso_id
    interface = "ide0"
  }

  operating_system {
    type = "l26"
  }

  # Pass machineconfig via nocloud user-data.
  # Talos reads this from the cloud-init drive on first boot.
  initialization {
    datastore_id      = var.cloud_init_datastore
    user_data_file_id = proxmox_virtual_environment_file.machine_config.id
  }

  stop_on_destroy = true

  lifecycle {
    ignore_changes = [initialization, cdrom]
  }
}
