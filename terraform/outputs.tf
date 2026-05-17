output "kubeconfig_path" {
  description = "Path to the kubeconfig written by the kind provider"
  value       = kind_cluster.this.kubeconfig_path
}

output "app_urls" {
  description = "URLs for each deployed in-house app"
  value       = { for k, v in var.apps : k => "http://${v.host}" }
}

output "podinfo_url" {
  description = "URL for podinfo"
  value       = "http://${var.podinfo_host}"
}
