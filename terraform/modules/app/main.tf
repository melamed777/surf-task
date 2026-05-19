terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
  }
}

locals {
  use_oci = var.chart_source == "oci"

  base_values = {
    replicaCount = var.replicas
    image = {
      repository = var.image_repo
      tag        = var.image_tag
      pullPolicy = var.image_pull_policy
    }
    ingress = {
      enabled   = true
      className = var.ingress_class_name
      host      = var.host
    }
  }

  # extra_values is passed as a SECOND values document so Helm performs the
  # merge (later wins per Helm semantics). Cleaner than trying to deep-merge
  # in HCL.
}

resource "helm_release" "this" {
  name      = var.release_name
  namespace = var.namespace

  # Chart source toggle: a local path bypasses 'repository' entirely;
  # OCI mode sets repository to oci://... and pins a version.
  chart      = local.use_oci ? "generic-app" : var.chart_local_path
  repository = local.use_oci ? var.chart_oci_repo : null
  version    = local.use_oci ? var.chart_version : null

  values = concat(
    [yamlencode(local.base_values)],
    length(keys(var.extra_values)) > 0 ? [yamlencode(var.extra_values)] : [],
  )
}
