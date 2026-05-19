# ---------------------------------------------------------------------------
# Mode B: GitOps via ArgoCD.
# Terraform installs ArgoCD and a one-resource bootstrap chart that creates
# the root "Application", which then syncs the per-app Applications from
# gitops/ in this repo. Enabled when var.enable_gitops == true.
#
# Why a bootstrap chart instead of kubernetes_manifest? The Kubernetes
# provider's `kubernetes_manifest` validates against the API server at plan
# time, which fails when the cluster is being created in the same plan.
# helm_release is evaluated at apply time and tolerates this.
# ---------------------------------------------------------------------------

locals {
  resolved_argocd_host = var.argocd_host != "" ? var.argocd_host : "argocd.${var.host_suffix}"
  gitops_apps = {
    for name, app in var.apps : name => {
      image = app.image
      host  = app.host != null ? app.host : ""
    }
  }
}

module "argocd" {
  count = var.enable_gitops ? 1 : 0

  source = "./modules/argocd"

  chart_version        = var.argocd_version
  hostname             = local.resolved_argocd_host
  ingress_class_name   = var.ingress_class_name
  repo_url             = var.repo_url
  target_revision      = var.repo_revision
  app_source_type      = var.gitops_source_type
  bootstrap_chart_path = "${path.module}/../charts/argocd-bootstrap"
  root_app_values = {
    global = {
      argocdNamespace  = "argocd"
      appsNamespace    = var.apps_namespace
      repoURL          = var.repo_url
      targetRevision   = var.repo_revision
      hostSuffix       = var.host_suffix
      ingressClassName = var.ingress_class_name
    }
    inhouse = {
      ghcrOwner       = var.ghcr_owner
      imagePullPolicy = var.image_pull_policy != "" ? var.image_pull_policy : "Always"
      apps            = local.gitops_apps
    }
    podinfo = {
      version = var.podinfo_version
      host    = local.resolved_podinfo_host
    }
  }

  depends_on = [
    kind_cluster.this,
    helm_release.ingress_nginx,
  ]
}
