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
}

module "argocd" {
  count = var.enable_gitops ? 1 : 0

  source = "./modules/argocd"

  chart_version        = var.argocd_version
  hostname             = local.resolved_argocd_host
  repo_url             = var.repo_url
  target_revision      = var.repo_revision
  bootstrap_chart_path = "${path.module}/../charts/argocd-bootstrap"

  depends_on = [
    kind_cluster.this,
    helm_release.ingress_nginx,
  ]
}
