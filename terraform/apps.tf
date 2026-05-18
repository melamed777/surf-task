# ---------------------------------------------------------------------------
# Mode A: Terraform-direct deployment.
# Terraform deploys each in-house app via the wrapper module, and podinfo via
# its upstream OCI chart. Enabled when var.enable_gitops == false.
# ---------------------------------------------------------------------------

module "app" {
  source   = "./modules/app"
  for_each = var.enable_gitops ? {} : var.apps

  release_name     = each.key
  namespace        = kubernetes_namespace.apps.metadata[0].name
  image_repo       = "ghcr.io/${var.ghcr_owner}/${each.value.image}"
  image_tag        = coalesce(each.value.tag, var.image_tag)
  replicas         = each.value.replicas
  host             = each.value.host
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
  version    = "6.7.0"

  values = [yamlencode({
    ingress = {
      enabled   = true
      className = "nginx"
      hosts = [{
        host  = var.podinfo_host
        paths = [{ path = "/", pathType = "ImplementationSpecific" }]
      }]
    }
  })]

  depends_on = [helm_release.ingress_nginx]
}
