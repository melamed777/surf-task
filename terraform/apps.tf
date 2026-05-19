# ---------------------------------------------------------------------------
# Mode A: Terraform-direct deployment.
# Terraform deploys each in-house app via the wrapper module, and podinfo via
# its upstream OCI chart. Enabled when var.enable_gitops == false.
# ---------------------------------------------------------------------------

# Resolve the current commit SHA at apply time. This lets us pin each apply
# to the exact image CI produced for HEAD instead of riding the mutable
# 'latest' tag. var.image_tag (default "auto") triggers this; any other
# value is used verbatim.
data "external" "git_sha" {
  count   = var.image_tag == "auto" ? 1 : 0
  program = ["sh", "-c", "printf '{\"sha\":\"%s\"}' \"$(git -C ${path.module}/.. rev-parse HEAD 2>/dev/null || echo latest)\""]
}

locals {
  resolved_image_tag    = var.image_tag == "auto" ? data.external.git_sha[0].result.sha : var.image_tag
  resolved_podinfo_host = var.podinfo_host != "" ? var.podinfo_host : "podinfo.${var.host_suffix}"

  # Compute per-app hostnames: per-app override wins, else "<key>.<host_suffix>".
  app_hosts = { for k, v in var.apps : k => coalesce(v.host, "${k}.${var.host_suffix}") }
}

module "app" {
  source   = "./modules/app"
  for_each = var.enable_gitops ? {} : var.apps

  release_name     = each.key
  namespace        = kubernetes_namespace.apps.metadata[0].name
  image_repo       = "ghcr.io/${var.ghcr_owner}/${each.value.image}"
  image_tag        = coalesce(each.value.tag, local.resolved_image_tag)
  replicas         = each.value.replicas
  host             = local.app_hosts[each.key]
  extra_values     = each.value.extra_values
  chart_source     = var.chart_source
  chart_version    = var.chart_version
  chart_local_path = "${path.module}/../charts/generic-app"
  chart_oci_repo   = "oci://ghcr.io/${var.ghcr_owner}/charts"

  depends_on = [helm_release.ingress_nginx]
}

resource "helm_release" "podinfo" {
  count = var.enable_gitops ? 0 : 1

  name       = "podinfo"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  repository = "oci://ghcr.io/stefanprodan/charts"
  chart      = "podinfo"
  version    = var.podinfo_version

  values = [yamlencode({
    ingress = {
      enabled   = true
      className = "nginx"
      hosts = [{
        host  = local.resolved_podinfo_host
        paths = [{ path = "/", pathType = "ImplementationSpecific" }]
      }]
    }
  })]

  depends_on = [helm_release.ingress_nginx]
}
