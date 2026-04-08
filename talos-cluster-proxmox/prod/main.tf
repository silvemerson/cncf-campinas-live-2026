terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.96.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "= 0.7.1"
    }
  }
}


provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = var.proxmox_insecure

  ssh {
    agent    = false
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
  }
}

# ---------------------------------------------------------------------------
# Locals — build node maps used by both the talos-cluster and vm-talos modules
# ---------------------------------------------------------------------------
locals {
  controlplane_nodes = {
    for i, ip in var.controlplane_ips :
    "${var.cluster_name}-cp-${i + 1}" => {
      id      = var.controlplane_start_id + i
      ip      = ip
      prefix  = var.network_prefix
      gateway = var.network_gateway_ipv4
    }
  }

  worker_nodes = {
    for i, ip in var.worker_ips :
    "${var.cluster_name}-worker-${i + 1}" => {
      id      = var.worker_start_id + i
      ip      = ip
      prefix  = var.network_prefix
      gateway = var.network_gateway_ipv4
    }
  }
}

# ---------------------------------------------------------------------------
# Talos cluster config — generates machineconfigs from cluster secrets
# ---------------------------------------------------------------------------
module "talos_cluster" {
  source = "../modules/talos-cluster"

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${coalesce(var.controlplane_vip, var.controlplane_ips[0])}:6443"
  talos_version      = var.talos_version
  talos_schematic_id = var.talos_schematic_id
  dns_servers        = var.dns_servers
  controlplane_vip   = var.controlplane_vip

  cilium_enabled = var.cilium_enabled

  controlplane_nodes = {
    for k, v in local.controlplane_nodes : k => {
      ip      = v.ip
      prefix  = v.prefix
      gateway = v.gateway
    }
  }

  worker_nodes = {
    for k, v in local.worker_nodes : k => {
      ip      = v.ip
      prefix  = v.prefix
      gateway = v.gateway
    }
  }
}

# ---------------------------------------------------------------------------
# Control plane VMs
# ---------------------------------------------------------------------------
module "controlplane" {
  source   = "../modules/vm-talos"
  for_each = local.controlplane_nodes

  target_node         = var.target_node
  vm_id               = each.value.id
  vm_name             = each.key
  description         = "Talos controlplane – ${each.key} – managed by Terraform"
  talos_iso_id = var.talos_iso_id

  vm_cores     = var.controlplane_cores
  vm_memory_mb = var.controlplane_memory_mb
  disk_size_gb = var.controlplane_disk_gb
  disk_storage = var.disk_storage

  network_bridge       = var.network_bridge
  network_vlan_id      = var.network_vlan_id
  snippets_datastore   = var.snippets_datastore
  cloud_init_datastore = var.cloud_init_datastore

  machine_config = module.talos_cluster.controlplane_configs[each.key]
  tags           = ["terraform", "talos", "controlplane"]
}

# ---------------------------------------------------------------------------
# Worker VMs
# ---------------------------------------------------------------------------
module "worker" {
  source   = "../modules/vm-talos"
  for_each = local.worker_nodes

  target_node         = var.target_node
  vm_id               = each.value.id
  vm_name             = each.key
  description         = "Talos worker – ${each.key} – managed by Terraform"
  talos_iso_id = var.talos_iso_id

  vm_cores     = var.worker_cores
  vm_memory_mb = var.worker_memory_mb
  disk_size_gb = var.worker_disk_gb
  disk_storage = var.disk_storage

  network_bridge       = var.network_bridge
  network_vlan_id      = var.network_vlan_id
  snippets_datastore   = var.snippets_datastore
  cloud_init_datastore = var.cloud_init_datastore

  machine_config = module.talos_cluster.worker_configs[each.key]
  tags           = ["terraform", "talos", "worker"]
}

# ---------------------------------------------------------------------------
# Bootstrap — triggers etcd init on first controlplane after VMs are up
# ---------------------------------------------------------------------------
resource "talos_machine_bootstrap" "this" {
  depends_on = [module.controlplane, module.worker]

  client_configuration = module.talos_cluster.client_configuration
  node                 = var.controlplane_ips[0]
  endpoint             = var.controlplane_ips[0]
}

# ---------------------------------------------------------------------------
# Kubeconfig — retrieved after bootstrap completes
# ---------------------------------------------------------------------------
data "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = module.talos_cluster.client_configuration
  node                 = var.controlplane_ips[0]
  endpoint             = var.controlplane_ips[0]
}

# ---------------------------------------------------------------------------
# Talosconfig — generates a valid talosconfig YAML via the provider
# ---------------------------------------------------------------------------
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = module.talos_cluster.client_configuration
  endpoints            = var.controlplane_vip != "" ? [var.controlplane_vip] : var.controlplane_ips
  nodes                = var.controlplane_ips
}

# ---------------------------------------------------------------------------
# Cilium CNI — installed via Helm after bootstrap
# ---------------------------------------------------------------------------
resource "terraform_data" "cilium" {
  count = var.cilium_enabled ? 1 : 0

  depends_on = [data.talos_cluster_kubeconfig.this]

  triggers_replace = [var.cilium_version]

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      set -e
      KUBECONFIG_FILE=$(mktemp /tmp/talos-kubeconfig-XXXXXX.yaml)
      trap 'rm -f "$KUBECONFIG_FILE"' EXIT

      cat > "$KUBECONFIG_FILE" <<'KUBEEOF'
${data.talos_cluster_kubeconfig.this.kubeconfig_raw}
KUBEEOF

      echo "Waiting for Kubernetes API server to become ready..."
      RETRIES=0
      until kubectl --kubeconfig "$KUBECONFIG_FILE" get nodes > /dev/null 2>&1; do
        RETRIES=$((RETRIES + 1))
        if [ "$RETRIES" -ge 30 ]; then
          echo "ERROR: API server not ready after 5 minutes."
          exit 1
        fi
        echo "  API server not ready yet (attempt $RETRIES/30), retrying in 10s..."
        sleep 10
      done
      echo "API server is ready."

      helm repo add cilium https://helm.cilium.io/ --force-update
      helm repo update cilium

      helm upgrade --install cilium cilium/cilium \
        --version "${var.cilium_version}" \
        --namespace kube-system \
        --kubeconfig "$KUBECONFIG_FILE" \
        --set ipam.mode=kubernetes \
        --set kubeProxyReplacement=true \
        --set k8sServiceHost="${coalesce(var.controlplane_vip, var.controlplane_ips[0])}" \
        --set k8sServicePort=6443 \
        --set securityContext.capabilities.ciliumAgent="{NET_ADMIN,NET_RAW,SYS_PTRACE,SYS_ADMIN,AUDIT_WRITE,NET_BIND_SERVICE,PERFMON,BPF}" \
        --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
        --set cgroup.autoMount.enabled=false \
        --set cgroup.hostRoot=/sys/fs/cgroup \
        --wait --timeout 5m
    EOT
  }
}
