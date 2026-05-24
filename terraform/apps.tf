# ---------------------------------------------------------------------------
# Mode A: Terraform-direct deployment.
# Terraform deploys each in-house app via the wrapper module, and podinfo via
# its upstream OCI chart. Enabled when var.enable_gitops == false.
# ---------------------------------------------------------------------------

# Resolve the most recent commit SHA that actually triggered an image build,
# not just HEAD. The CI workflow's `paths:` filter only fires on changes
# under apps/, charts/, or the workflow file itself -- so HEAD may point at
# a gitops-only or docs-only commit whose SHA never produced an image. Walk
# the git log for the last commit touching those build inputs.
# var.image_tag = "auto" enables this; any other value is used verbatim.
data "external" "git_sha" {
  count = var.image_tag == "auto" ? 1 : 0
  program = ["sh", "-c", <<-EOT
    sha=$(git -C ${path.module}/.. log -1 --format=%H -- apps charts .github/workflows/build-and-publish.yml 2>/dev/null)
    [ -z "$sha" ] && sha=latest
    printf '{"sha":"%s"}' "$sha"
  EOT
  ]
}

locals {
  resolved_image_tag    = var.image_tag == "auto" ? data.external.git_sha[0].result.sha : var.image_tag
  resolved_podinfo_host = var.podinfo_host != "" ? var.podinfo_host : "podinfo.${var.host_suffix}"

  # Compute per-app hostnames: per-app override wins, else "<key>.<host_suffix>".
  app_hosts = { for k, v in var.apps : k => coalesce(v.host, "${k}.${var.host_suffix}") }

  # Resolve each app's target namespace (per-app override > default). Then
  # collect the unique set so each namespace is created exactly once even
  # when several apps share one.
  app_namespaces_per_app = { for k, v in var.apps : k => coalesce(v.namespace, var.apps_namespace) }
  app_namespaces         = toset(values(local.app_namespaces_per_app))
}

# Create every namespace any app needs, plus the default one (used by
# podinfo and as the fallback for apps that don't set a namespace).
resource "kubernetes_namespace_v1" "app" {
  for_each = setunion(local.app_namespaces, toset([var.apps_namespace]))

  metadata {
    name = each.key
  }

  depends_on = [kind_cluster.this]
}

module "app" {
  source   = "./modules/app"
  for_each = var.enable_gitops ? {} : var.apps

  release_name       = each.key
  namespace          = kubernetes_namespace_v1.app[local.app_namespaces_per_app[each.key]].metadata[0].name
  image_repo         = "ghcr.io/${var.ghcr_owner}/${each.value.image}"
  image_tag          = coalesce(each.value.tag, local.resolved_image_tag)
  image_pull_policy  = var.image_pull_policy != "" ? var.image_pull_policy : (coalesce(each.value.tag, local.resolved_image_tag) == "latest" ? "Always" : "IfNotPresent")
  replicas           = each.value.replicas
  host               = local.app_hosts[each.key]
  ingress_class_name = var.ingress_class_name
  extra_values       = each.value.extra_values
  chart_source       = var.chart_source
  chart_version      = var.chart_version
  chart_local_path   = "${path.module}/../charts/generic-app"
  chart_oci_repo     = "oci://ghcr.io/${var.ghcr_owner}/charts"

  depends_on = [helm_release.ingress_nginx]
}

resource "helm_release" "podinfo" {
  count = var.enable_gitops ? 0 : 1

  name       = "podinfo"
  namespace  = kubernetes_namespace_v1.app[var.apps_namespace].metadata[0].name
  repository = "oci://ghcr.io/stefanprodan/charts"
  chart      = "podinfo"
  version    = var.podinfo_version

  values = [yamlencode({
    ingress = {
      enabled   = true
      className = var.ingress_class_name
      hosts = [{
        host  = local.resolved_podinfo_host
        paths = [{ path = "/", pathType = "ImplementationSpecific" }]
      }]
    }
  })]

  depends_on = [helm_release.ingress_nginx]
}
