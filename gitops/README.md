# gitops/

ArgoCD reads this folder when `enable_gitops = true` in Terraform. The root
Application installed by `terraform/gitops.tf` syncs this directory
recursively.

- `inhouse-apps.yaml` — ApplicationSet covering every in-house app
  (`app1`, `app2`, ...). They share a chart, an image registry, and an
  ingress style; the only per-app values are name and host, so a list
  generator produces them from a 2-line template entry each.
- `podinfo.yaml` — plain Application for podinfo. It uses a different
  chart (upstream OCI), repository, and values shape, so it doesn't share
  the template.

**Adding a new in-house app:** add a `- name: ... host: ...` entry to the
`elements:` list in `inhouse-apps.yaml`. ArgoCD picks it up within ~3
minutes. Force it sooner with:

```bash
kubectl -n argocd patch app root --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

**Switching the chart source** (in-repo vs OCI from CI): see the comment
block in `inhouse-apps.yaml`.
