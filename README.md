# surf-task — Terraform-driven apps on a local kind cluster

Provisions a local Kubernetes cluster (kind), installs ingress-nginx +
metrics-server, and deploys N web apps + podinfo — either directly via
Terraform/Helm, or via ArgoCD (GitOps). One `terraform apply` either way.

```
┌─ Act (local) ────────────────────────────────────────────┐
│  .github/workflows/build-and-publish.yml                 │
│   matrix(apps/*) → docker build → push to GHCR           │
│   helm package charts/generic-app → push OCI → GHCR      │
└──────────────────────────────────────────────────────────┘
                          │ images + chart on ghcr.io
                          ▼
┌─ terraform apply (local) ────────────────────────────────┐
│  kind_cluster (control-plane + worker, ports 80/443)     │
│  helm_release ingress-nginx                              │
│  helm_release metrics-server                             │
│                                                          │
│  ── Mode A (default): enable_gitops = false ──           │
│     module "app" × N  (for_each over var.apps)           │
│     helm_release podinfo                                 │
│                                                          │
│  ── Mode B: enable_gitops = true ──                      │
│     helm_release argocd                                  │
│     root Application → syncs gitops/                     │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
   http://app1.localtest.me   → {app, podName, podIP}
   http://app2.localtest.me   → {app, podName, podIP}
   http://podinfo.localtest.me
   http://argocd.localtest.me
```

`*.localtest.me` resolves to `127.0.0.1` — no `/etc/hosts` edits needed.

## Prerequisites

- Docker
- [kind](https://kind.sigs.k8s.io/) (the Terraform provider drives it but the
  binary is not required; Docker is)
- Terraform `>= 1.6`
- [Act](https://github.com/nektos/act) — to run the CI workflow locally
- A GitHub Personal Access Token with `write:packages` + `read:packages`
  (needed by Act to push to GHCR, and by your local Docker to pull private
  images if your packages aren't public)

## One-time setup

```bash
cp .secrets.example .secrets
# edit .secrets — paste your GitHub PAT

cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform/terraform.tfvars — set ghcr_owner to your GitHub username
```

If your GHCR packages are private, log Docker in once so kind can pull them:

```bash
echo $YOUR_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

(The simpler path is to make the packages public from the GitHub UI after the
first publish.)

## Run the CI workflow locally

```bash
act push --secret-file .secrets
```

This builds `app1` and `app2`, pushes them to
`ghcr.io/<you>/app1:latest` and `ghcr.io/<you>/app2:latest`, packages
`charts/generic-app` and pushes it to `oci://ghcr.io/<you>/charts/generic-app`.

## Deploy — Mode A: Terraform-direct (default)

Terraform installs the cluster, the controllers, **and** the apps in one
shot. The simplest path.

```bash
cd terraform
terraform init
terraform apply
```

After it completes:

```bash
curl http://app1.localtest.me
# {"app":"app1","podName":"app1-7c9...","podIP":"10.244.1.5"}

curl http://app2.localtest.me
curl http://podinfo.localtest.me
```

Refreshing in a browser will rotate through pods (load-balanced by the
Service) — you can watch `podName` change.

## Deploy — Mode B: GitOps via ArgoCD

Terraform installs the cluster, the controllers, and ArgoCD; ArgoCD then
syncs everything in `gitops/` from this repo. The app inventory is still
declared once in Terraform, while image promotion happens through GitOps PRs.

1. Push this repo to GitHub (the cluster needs to reach a remote URL).
2. Enable the mode and point Terraform at the repo:
   ```hcl
   # terraform.tfvars
   enable_gitops = true
   repo_url      = "https://github.com/<your-github-username>/surf-task"
   ```
3. ```bash
   cd terraform
   terraform apply
   ```

Access the ArgoCD UI:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo
# username: admin
# open http://argocd.localtest.me
```

You'll see three Applications (`app1`, `app2`, `podinfo`) being reconciled.
When CI opens and you merge a GitOps tag-bump PR, ArgoCD applies it within a
minute or so.

The default root Application mode is `gitops_source_type = "directory"` so it
can sync the legacy plain-YAML `gitops/` folder already on `main`. After the
Helm-based `gitops/Chart.yaml` change is pushed to the branch ArgoCD tracks,
set `gitops_source_type = "helm"` to let Terraform inject repo, owner, host,
namespace, and app inventory values into the GitOps chart.

## Image tags

CI tags each pushed image twice: `:latest` (moving) and `:<commit-sha>`
(immutable).

- **Mode A** uses `var.image_tag`. The default `"auto"` resolves to the
  current `git rev-parse HEAD` at apply time, so each apply pins to the
  exact image CI produced for that commit. Pass `-var image_tag=latest`
  or `-var image_tag=<sha>` to override.
- **Mode B** is image-promotion via PR: when CI publishes images for a
  commit, it opens a PR that rewrites `imageTag` in `gitops/values.yaml`
  to that commit's SHA. Merging the PR is
  what rolls the apps forward via ArgoCD — main is never written to
  directly by CI.

## Metrics

`metrics-server` is installed in both modes, so `kubectl top` works:

```bash
kubectl top pods -A
kubectl top nodes
```

## Tear down

```bash
cd terraform
terraform destroy
```

## Adding a third in-house app

This is the "minimal lines for app #3" bonus.

1. `cp -r apps/app1 apps/app3` and tweak.
2. Add `app3` to the matrix in `.github/workflows/build-and-publish.yml`.
3. **Mode A:** add one entry to `var.apps` in `terraform/variables.tf` (or
   override in tfvars):
   ```hcl
   app3 = {
     image = "app3"
     host  = "app3.localtest.me"
   }
   ```
   In GitOps mode, Terraform passes the same `var.apps` inventory into the
   ArgoCD root app, so the ApplicationSet generator produces the new
   Application automatically after apply.

Either way the Helm chart handles the rest — no new resources, no
copy-pasted module blocks.

## Chart source: local vs OCI

`terraform/variables.tf` exposes `chart_source` for Mode A:

- `local` (default) — Terraform reads `charts/generic-app` from this repo.
  Fast iteration; doesn't depend on CI having run.
- `oci` — Terraform pulls `generic-app` from
  `oci://ghcr.io/<owner>/charts`. Truer to a real pipeline; requires you to
  run the workflow at least once first.

In Mode B, the ArgoCD Applications default to the git-path source; each
manifest contains a commented-out OCI variant.

## Design notes

- **One chart, many apps.** `charts/generic-app` is parameterized (image /
  replicas / host). In Mode A, `module/app` wraps `helm_release` and is
  instantiated once per app via `for_each`; in Mode B, an ArgoCD
  `ApplicationSet` with a list generator produces one Application per
  in-house app from a single template. Same reusability story, two
  mechanisms.
- **Pod identity via downward API.** `POD_NAME` and `POD_IP` are injected as
  env vars; the app just reads them. No in-cluster API calls.
- **"Route only to pods capable of responding"** is satisfied by the
  readiness probe on `/healthz` — kube-proxy/Service only forwards to Ready
  endpoints.
- **Ingress on host ports.** The kind config opens 80/443 on the
  control-plane node; ingress-nginx is pinned there with `hostPort` so
  traffic to `localhost:80` reaches the controller directly.
- **Podinfo uses its upstream chart** — proving the same Terraform/ArgoCD
  shape works whether the chart is ours or a third party's.
- **metrics-server uses `--kubelet-insecure-tls`** — required for kind
  because its kubelet serves a self-signed cert. Fine for a local demo;
  in production you'd use proper kubelet certs.

## What's intentionally out of scope

- TLS / cert-manager (plain HTTP via `localtest.me`)
- Remote Terraform state (local file is fine for a kind demo)
- HPA, PDBs, NetworkPolicies, full observability stack

## AI usage disclosure

This project was scaffolded with the help of Claude (Anthropic).

- **Planning prompt:** the task brief above, plus a request for a plan that
  uses kind + GHCR + Helm + Terraform with a CI pipeline runnable via Act.
  Followed by a request to add a GitOps path and metrics-server.
- **Decisions I made directly:** Node.js for the app runtime, end-to-end CI
  via Act, podinfo via its upstream chart, a `chart_source = local|oci`
  toggle, and adding an optional GitOps mode alongside the Terraform-direct
  one rather than replacing it.
- **What Claude generated:** the Express app, the generic Helm chart,
  Terraform (root + `module/app` + GitOps wiring), the GitHub Actions
  workflow, the ArgoCD manifests in `gitops/`, and this README.
- **Review pass:** everything was reviewed before commit. The main edits
  were around the ingress-nginx host-port pinning (so kind's port mappings
  actually land on the controller), the chart-source toggle in the module,
  and gating Mode A vs Mode B with `count`/empty-map so both can live in
  the same Terraform configuration.
