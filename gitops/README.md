# gitops/

ArgoCD reads this folder when `enable_gitops = true` in Terraform. The root
Application installed by `terraform/gitops.tf` syncs this directory
recursively, so each `*.yaml` here becomes an ArgoCD object.

- `inhouse-apps.yaml` — ApplicationSet covering every in-house app
  (`app1`, `app2`, ...). They share a chart (`charts/generic-app`), an image
  registry, and an ingress style. Each list element has three fields:
  - `name` — identity (Application name, Helm release name, host prefix).
  - `app`  — which container image to run. Decoupled from `name`, so you
    can spin up another instance of an existing app without building a new
    image (e.g. `name: app3, app: app1`).
  - `host` — ingress hostname.
- `podinfo.yaml` — plain Application for podinfo (different chart, repo,
  values shape).

**Adding a new instance of an existing app:** one entry, no CI changes.
```yaml
- name: app3
  app:  app1
  host: app3.localtest.me
```

**Adding a genuinely new app** (new binary): build a new image (`apps/app3/`
+ add to the CI matrix in `.github/workflows/build-and-publish.yml`), then
add an element with `app: app3`.

Push the change. ArgoCD picks it up within ~3 minutes. Force it sooner
with:

```bash
kubectl -n argocd patch app root --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

**Image promotion:** CI's `bump-gitops-tag` job rewrites the `tag:` line in
this file and opens a PR. Merging the PR rolls the apps forward via ArgoCD;
`main` is never written to directly by CI.

**Fork note:** if you fork this repo, replace `melamed777` in
`inhouse-apps.yaml` (three occurrences) with your GitHub username.
