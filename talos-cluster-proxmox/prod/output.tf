output "controlplane_ips" {
  description = "IP addresses of controlplane nodes."
  value       = var.controlplane_ips
}

output "worker_ips" {
  description = "IP addresses of worker nodes."
  value       = var.worker_ips
}

output "talosconfig" {
  description = "Talos client configuration — use with: terraform output -raw talosconfig > ~/.talos/config"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "controlplane_machineconfigs" {
  description = "Machineconfig YAML per controlplane node — use to apply updates via talosctl apply-config."
  value       = module.talos_cluster.controlplane_configs
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes client configuration — use with: kubectl --kubeconfig <(terraform output -raw kubeconfig)"
  value       = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}
