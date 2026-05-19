output "kubeconfig_path" {
  description = "Path to the kubeconfig written by the kind provider"
  value       = kind_cluster.this.kubeconfig_path
}

output "app_urls" {
  description = "URLs for each deployed in-house app"
  value       = { for k, _ in var.apps : k => "http://${local.app_hosts[k]}" }
}

output "podinfo_url" {
  description = "URL for podinfo"
  value       = "http://${local.resolved_podinfo_host}"
}

output "argocd_url" {
  description = "URL for the ArgoCD UI when GitOps mode is enabled"
  value       = var.enable_gitops ? "http://${local.resolved_argocd_host}" : null
}

output "argocd_initial_password_cmd" {
  description = "Command to fetch the bootstrap admin password for ArgoCD"
  value       = var.enable_gitops ? "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : null
}
