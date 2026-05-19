# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "surf-task"
}

variable "host_suffix" {
  description = "DNS suffix appended to every app's hostname. Default 'localtest.me' resolves to 127.0.0.1 with no /etc/hosts edits; in a real environment, replace with your real domain."
  type        = string
  default     = "localtest.me"
}

# ---------------------------------------------------------------------------
# Add-on chart versions (pin one place, bump one place)
# ---------------------------------------------------------------------------

variable "ingress_nginx_version" {
  description = "Helm chart version of ingress-nginx"
  type        = string
  default     = "4.10.1"
}

variable "metrics_server_version" {
  description = "Helm chart version of metrics-server"
  type        = string
  default     = "3.12.1"
}

variable "argocd_version" {
  description = "Helm chart version of Argo CD"
  type        = string
  default     = "7.7.0"
}

variable "podinfo_version" {
  description = "Helm chart version of podinfo"
  type        = string
  default     = "6.7.0"
}

# ---------------------------------------------------------------------------
# Images & chart source
# ---------------------------------------------------------------------------

variable "ghcr_owner" {
  description = "GitHub owner/org used in ghcr.io paths for both images and (OCI) charts"
  type        = string
}

variable "image_tag" {
  description = "Tag for app images published to GHCR. 'auto' resolves to the current git HEAD SHA at apply time; any other string is used verbatim ('latest', 'v1.2.3', a specific SHA, etc.)."
  type        = string
  default     = "auto"
}

variable "chart_source" {
  description = "Where to load the generic-app chart from: 'local' (path) or 'oci' (ghcr.io OCI registry)"
  type        = string
  default     = "local"
  validation {
    condition     = contains(["local", "oci"], var.chart_source)
    error_message = "chart_source must be 'local' or 'oci'."
  }
}

variable "chart_version" {
  description = "Version of the generic-app chart when pulled from OCI"
  type        = string
  default     = "0.1.0"
}

# ---------------------------------------------------------------------------
# Apps (in-house)
#
# Per-app fields:
#   image         (required) image name under ghcr.io/<ghcr_owner>/
#   tag           (optional) override image_tag for this app
#   host          (optional) override hostname; defaults to "<key>.<host_suffix>"
#   replicas      (optional) default 2
#   extra_values  (optional) raw map merged into Helm values, for one-off
#                            overrides that don't deserve a top-level field
# ---------------------------------------------------------------------------

variable "apps" {
  description = "Map of in-house apps to deploy via the generic chart"
  type = map(object({
    image        = string
    tag          = optional(string)
    host         = optional(string)
    replicas     = optional(number, 2)
    extra_values = optional(any, {})
  }))
  default = {
    app1 = { image = "app1" }
    app2 = { image = "app2" }
  }
}

variable "apps_namespace" {
  description = "Namespace in which the in-house apps and podinfo are deployed"
  type        = string
  default     = "apps"
}

# ---------------------------------------------------------------------------
# Podinfo (third-party demo)
# ---------------------------------------------------------------------------

variable "podinfo_host" {
  description = "Hostname for the podinfo ingress. Default builds from host_suffix."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# GitOps mode
# ---------------------------------------------------------------------------

variable "enable_gitops" {
  description = "If true, install ArgoCD and let it deploy apps from gitops/; if false, Terraform deploys apps directly via the module."
  type        = bool
  default     = false
}

variable "repo_url" {
  description = "Git URL ArgoCD reads manifests from. Required when enable_gitops = true."
  type        = string
  default     = ""
}

variable "repo_revision" {
  description = "Branch, tag, or commit ArgoCD tracks."
  type        = string
  default     = "main"
}

variable "argocd_host" {
  description = "Hostname for the ArgoCD UI ingress. Empty string builds 'argocd.<host_suffix>' (e.g. argocd.localtest.me)."
  type        = string
  default     = ""
}
