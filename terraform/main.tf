resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      kubeadm_config_patches = [
        "kind: InitConfiguration\nnodeRegistration:\n  kubeletExtraArgs:\n    node-labels: \"ingress-ready=true\"\n"
      ]

      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.this.endpoint
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
  }
}

provider "kubernetes" {
  host                   = kind_cluster.this.endpoint
  cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  client_certificate     = kind_cluster.this.client_certificate
  client_key             = kind_cluster.this.client_key
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.10.1"

  # Pin the controller onto the labeled control-plane node and use hostPort so
  # the kind extraPortMappings on 80/443 reach the controller directly.
  values = [yamlencode({
    controller = {
      hostPort = {
        enabled = true
        ports   = { http = 80, https = 443 }
      }
      service = {
        type = "NodePort"
      }
      nodeSelector = {
        "ingress-ready" = "true"
      }
      tolerations = [{
        key      = "node-role.kubernetes.io/control-plane"
        operator = "Equal"
        effect   = "NoSchedule"
      }]
      publishService = {
        enabled = false
      }
    }
  })]

  depends_on = [kind_cluster.this]
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
  depends_on = [kind_cluster.this]
}

module "app" {
  source   = "./modules/app"
  for_each = var.apps

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
