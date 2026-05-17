# surf-task — Terraform-driven apps on a local kind cluster

Provisions a local Kubernetes cluster (kind), installs ingress-nginx, and
deploys N web apps + podinfo via Helm — all from a single `terraform apply`.

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
│  module "app" × N  (for_each over var.apps)              │
│  helm_release podinfo (upstream OCI chart)               │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
   http://app1.localtest.me   → {app, podName, podIP}
   http://app2.localtest.me   → {app, podName, podIP}
   http://podinfo.localtest.me
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

## Deploy

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

## Tear down

```bash
cd terraform
terraform destroy
```

## Adding a third in-house app

This is the "minimal lines for app #3" bonus.

1. `cp -r apps/app1 apps/app3` and tweak.
2. Add `app3` to the matrix in `.github/workflows/build-and-publish.yml`.
3. Add one entry to `var.apps` in `terraform/variables.tf` (or override in
   tfvars):
   ```hcl
   app3 = {
     image = "app3"
     host  = "app3.localtest.me"
   }
   ```

The Terraform `for_each` and the Helm chart handle the rest — no new
resources, no copy-pasted module blocks.

## Chart source: local vs OCI

`terraform/variables.tf` exposes `chart_source`:

- `local` (default) — Terraform reads `charts/generic-app` from this repo.
  Fast iteration; doesn't depend on CI having run.
- `oci` — Terraform pulls `generic-app` from
  `oci://ghcr.io/<owner>/charts`. Truer to a real pipeline; requires you to
  run the workflow at least once first.

Switch by editing `terraform.tfvars` or with `-var chart_source=oci`.

## Design notes

- **One chart, many apps.** `charts/generic-app` is parameterized
  (image / replicas / host). The Terraform `module/app` wraps `helm_release`
  and is instantiated once per app via `for_each`. Adding an app is a map
  entry, not a new resource block.
- **Pod identity via downward API.** `POD_NAME` and `POD_IP` are injected as
  env vars; the app just reads them. No in-cluster API calls.
- **"Route only to pods capable of responding"** is satisfied by the
  readiness probe on `/healthz` — kube-proxy/Service only forwards to Ready
  endpoints.
- **Ingress on host ports.** The kind config opens 80/443 on the
  control-plane node; ingress-nginx is pinned there with `hostPort` so
  traffic to `localhost:80` reaches the controller directly.
- **Podinfo uses its upstream chart** — proving the same Terraform shape
  works whether the chart is ours or a third party's.

## What's intentionally out of scope

- TLS / cert-manager (plain HTTP via `localtest.me`)
- Remote Terraform state (local file is fine for a kind demo)
- HPA, PDBs, NetworkPolicies, observability stack

## AI usage disclosure

This project was scaffolded with the help of Claude (Anthropic).

- **Planning prompt:** the task brief above, plus a request for a plan that
  uses kind + GHCR + Helm + Terraform with a CI pipeline runnable via Act.
- **Decisions I made directly:** Node.js for the app runtime, end-to-end CI
  via Act, podinfo via its upstream chart, and a `chart_source = local|oci`
  toggle so the same Terraform works pre- and post-CI.
- **What Claude generated:** the Express app, the generic Helm chart,
  Terraform (root + `module/app`), the GitHub Actions workflow, and this
  README.
- **Review pass:** everything was reviewed before commit. The main edits
  were around the ingress-nginx host-port pinning (so kind's port mappings
  actually land on the controller) and the chart-source toggle in the
  module.
