resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version

  values = [yamlencode({
    configs = {
      params = {
        # Serve HTTP on the controller's port so ingress-nginx can forward
        # plain HTTP in local clusters without TLS termination.
        "server.insecure" = true
      }
    }
    server = {
      ingress = {
        enabled          = true
        ingressClassName = var.ingress_class_name
        hostname         = var.hostname
      }
    }
    dex = {
      enabled = false
    }
    notifications = {
      enabled = false
    }
  })]
}

resource "helm_release" "root_app" {
  name      = "argocd-root-app"
  namespace = var.namespace
  chart     = var.bootstrap_chart_path

  values = [yamlencode({
    repoURL        = var.repo_url
    targetRevision = var.target_revision
    path           = var.app_path
  })]

  depends_on = [helm_release.argocd]
}
