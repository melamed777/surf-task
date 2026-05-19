# gitops/

ArgoCD reads this folder when `enable_gitops = true` in Terraform. The root
Application installed by `terraform/gitops.tf` renders this folder as a Helm
chart, so cluster-specific values such as repo URL, GHCR owner, host suffix,
namespace, and app list can come from Terraform instead of being hardcoded
in manifests.

- `templates/inhouse-apps.yaml` — ApplicationSet covering every in-house app
  (`app1`, `app2`, ...). They share a chart, an image registry, and an
  ingress style.
- `templates/podinfo.yaml` — plain Application for podinfo. It uses a different
  chart (upstream OCI), repository, and values shape.
- `values.yaml` — GitOps-owned values split into `global`, `inhouse`, and
  `podinfo` sections. CI updates `inhouse.imageTag` here by PR after publishing
  images, so merging that PR rolls app1/app2 forward via ArgoCD.

**Adding a new in-house app:** add it to `var.apps` in Terraform so both
Terraform-direct mode and GitOps mode get the same app inventory. ArgoCD picks
it up within ~3 minutes after apply. Force it sooner with:

```bash
kubectl -n argocd patch app root --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

**Switching the chart source** can be added in `templates/inhouse-apps.yaml`
by changing the ApplicationSet source from `path: charts/generic-app` to the
published OCI chart.
