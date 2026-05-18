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

output "argocd_port_forward" {
  description = "Command to access the ArgoCD UI when GitOps mode is enabled"
  value       = var.enable_gitops ? "kubectl port-forward -n argocd svc/argocd-server 8080:80 (then http://localhost:8080)" : null
}

output "argocd_initial_password_cmd" {
  description = "Command to fetch the bootstrap admin password for ArgoCD"
  value       = var.enable_gitops ? "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : null
}
