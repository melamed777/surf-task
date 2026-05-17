variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "surf-task"
}

variable "ghcr_owner" {
  description = "GitHub owner/org used in ghcr.io paths for both images and (OCI) charts"
  type        = string
}

variable "image_tag" {
  description = "Tag for app images published to GHCR"
  type        = string
  default     = "latest"
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

variable "apps" {
  description = "Map of in-house apps to deploy via the generic chart"
  type = map(object({
    image    = string
    tag      = optional(string)
    host     = string
    replicas = optional(number, 2)
  }))
  default = {
    app1 = {
      image = "app1"
      host  = "app1.localtest.me"
    }
    app2 = {
      image = "app2"
      host  = "app2.localtest.me"
    }
  }
}

variable "podinfo_host" {
  description = "Hostname for the podinfo ingress"
  type        = string
  default     = "podinfo.localtest.me"
}
