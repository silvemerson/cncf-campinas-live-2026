terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "= 0.7.1"
    }
  }
}

# Generates cluster PKI + secrets and persists them in state.
# WARNING: destroying this resource forces a full cluster rebuild.
resource "talos_machine_secrets" "this" {
  talos_version = "v${var.talos_version}"
}

# ---------------------------------------------------------------------------
# Controlplane machineconfigs
# ---------------------------------------------------------------------------
data "talos_machine_configuration" "controlplane" {
  for_each = var.controlplane_nodes

  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = var.cluster_endpoint
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v${var.talos_version}"

  config_patches = concat(
    [
      yamlencode({
        machine = {
          install = {
            image = "factory.talos.dev/nocloud-installer/${var.talos_schematic_id}:v${var.talos_version}"
          }
          network = {
            hostname    = each.key
            nameservers = var.dns_servers
            interfaces = [{
              interface = "eth0"
              addresses = ["${each.value.ip}/${each.value.prefix}"]
              routes = [{
                network = "0.0.0.0/0"
                gateway = each.value.gateway
              }]
            }]
          }
        }
      })
    ],
    var.controlplane_vip != "" ? [
      yamlencode({
        machine = {
          pods = [
            {
              apiVersion = "v1"
              kind       = "Pod"
              metadata = {
                name      = "kube-vip"
                namespace = "kube-system"
              }
              spec = {
                containers = [
                  {
                    name  = "kube-vip"
                    image = "ghcr.io/kube-vip/kube-vip:v0.8.9"
                    args  = ["manager"]
                    env = [
                      { name = "vip_arp", value = "true" },
                      { name = "port", value = "6443" },
                      { name = "vip_interface", value = "eth0" },
                      { name = "vip_cidr", value = "32" },
                      { name = "cp_enable", value = "true" },
                      { name = "cp_namespace", value = "kube-system" },
                      { name = "vip_ddns", value = "false" },
                      { name = "svc_enable", value = "false" },
                      { name = "vip_leaderelection", value = "true" },
                      { name = "vip_leaseduration", value = "5" },
                      { name = "vip_renewdeadline", value = "3" },
                      { name = "vip_retryperiod", value = "1" },
                      { name = "address", value = var.controlplane_vip },
                    ]
                    securityContext = {
                      capabilities = {
                        add = ["NET_ADMIN", "NET_RAW"]
                      }
                    }
                    volumeMounts = [
                      {
                        mountPath = "/etc/kubernetes/admin.conf"
                        name      = "kubeconfig"
                      }
                    ]
                  }
                ]
                hostAliases = [
                  {
                    ip        = "127.0.0.1"
                    hostnames = ["kubernetes"]
                  }
                ]
                hostNetwork = true
                volumes = [
                  {
                    name = "kubeconfig"
                    hostPath = {
                      path = "/etc/kubernetes/admin.conf"
                    }
                  }
                ]
              }
            }
          ]
        }
      })
    ] : [],
    var.cilium_enabled ? [
      yamlencode({
        cluster = {
          network = {
            cni = {
              name = "none"
            }
          }
          proxy = {
            disabled = true
          }
        }
      })
    ] : []
  )
}

# ---------------------------------------------------------------------------
# Worker machineconfigs
# ---------------------------------------------------------------------------
data "talos_machine_configuration" "worker" {
  for_each = var.worker_nodes

  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = var.cluster_endpoint
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v${var.talos_version}"

  config_patches = concat(
    [
      yamlencode({
        machine = {
          install = {
            image = "factory.talos.dev/nocloud-installer/${var.talos_schematic_id}:v${var.talos_version}"
          }
          network = {
            hostname    = each.key
            nameservers = var.dns_servers
            interfaces = [{
              interface = "eth0"
              addresses = ["${each.value.ip}/${each.value.prefix}"]
              routes = [{
                network = "0.0.0.0/0"
                gateway = each.value.gateway
              }]
            }]
          }
        }
      })
    ],
    var.cilium_enabled ? [
      yamlencode({
        cluster = {
          network = {
            cni = {
              name = "none"
            }
          }
          proxy = {
            disabled = true
          }
        }
      })
    ] : []
  )
}
