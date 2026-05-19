variable "namespace" {
  description = "Namespace where Argo CD is installed."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Helm chart version of Argo CD."
  type        = string
}

variable "hostname" {
  description = "Hostname for the Argo CD UI ingress."
  type        = string
}

variable "ingress_class_name" {
  description = "IngressClass name for the Argo CD UI ingress."
  type        = string
  default     = "nginx"
}

variable "repo_url" {
  description = "Git URL Argo CD reads manifests from."
  type        = string
}

variable "target_revision" {
  description = "Branch, tag, or commit Argo CD tracks."
  type        = string
}

variable "app_path" {
  description = "Path in the repo containing Argo CD Application manifests."
  type        = string
  default     = "gitops"
}

variable "app_source_type" {
  description = "How the root Argo CD Application reads app_path: 'directory' or 'helm'."
  type        = string
  default     = "directory"

  validation {
    condition     = contains(["directory", "helm"], var.app_source_type)
    error_message = "app_source_type must be 'directory' or 'helm'."
  }
}

variable "root_app_values" {
  description = "Helm values passed to the root Argo CD Application source."
  type        = any
  default     = {}
}

variable "bootstrap_chart_path" {
  description = "Local path to the chart that creates the root Argo CD Application."
  type        = string
}
