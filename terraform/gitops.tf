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

resource "helm_release" "argocd" {
  count = var.enable_gitops ? 1 : 0

  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version

  values = [yamlencode({
    configs = {
      params = {
        "server.insecure" = true
      }
    }
    dex = {
      enabled = false
    }
    notifications = {
      enabled = false
    }
  })]

  depends_on = [kind_cluster.this]
}

resource "helm_release" "argocd_root_app" {
  count = var.enable_gitops ? 1 : 0

  name      = "argocd-root-app"
  namespace = "argocd"
  chart     = "${path.module}/../charts/argocd-bootstrap"

  values = [yamlencode({
    repoURL        = var.repo_url
    targetRevision = var.repo_revision
    path           = "gitops"
  })]

  depends_on = [helm_release.argocd]
}
