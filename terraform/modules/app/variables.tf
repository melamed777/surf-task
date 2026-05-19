variable "release_name" {
  type        = string
  description = "Helm release name (also used as resource name prefix)"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to deploy into"
}

variable "image_repo" {
  type        = string
  description = "Full image repository, e.g. ghcr.io/owner/app1"
}

variable "image_tag" {
  type        = string
  description = "Image tag"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "host" {
  type        = string
  description = "Ingress host"
}

variable "chart_source" {
  type        = string
  description = "'local' or 'oci'"
}

variable "chart_version" {
  type        = string
  description = "Chart version when chart_source = 'oci'"
}

variable "chart_local_path" {
  type        = string
  description = "Path to the chart on disk when chart_source = 'local'"
}

variable "chart_oci_repo" {
  type        = string
  description = "OCI repository URL (e.g. oci://ghcr.io/owner/charts) when chart_source = 'oci'"
}

variable "extra_values" {
  type        = any
  default     = {}
  description = "Raw map merged into the Helm values for this release. Last-write-wins against module-managed keys; use for one-off overrides that don't deserve a top-level field."
}
