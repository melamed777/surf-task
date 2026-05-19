output "url" {
  description = "URL for the Argo CD UI."
  value       = "http://${var.hostname}"
}

output "initial_password_cmd" {
  description = "Command to fetch the bootstrap admin password for Argo CD."
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
