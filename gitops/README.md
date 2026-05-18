# gitops/

ArgoCD reads this folder when `enable_gitops = true` in Terraform.

Each `*.yaml` here is an ArgoCD `Application`. The root Application installed
by Terraform (`gitops.tf` -> `kubernetes_manifest.root_app`) syncs this
directory recursively, so adding a new app = adding a new YAML file here and
pushing to the branch ArgoCD tracks.

In-house apps use the in-repo `charts/generic-app` chart. Podinfo uses its
upstream OCI chart.

To use the OCI form of the generic-app chart instead (published by CI), see
`app1.yaml` -- swap the `repoURL`/`chart` block for the commented OCI variant.
