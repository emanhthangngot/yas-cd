# Dev And Staging Parallel CD Runbook

This runbook keeps the single-node K3s cluster useful while matching the Lab 2
demo shape: `dev` and `staging` run in parallel, while `developer` stays
dormant. Jenkins must change this repository and let ArgoCD reconcile the
cluster. Do not use `kubectl set image` or direct `kubectl apply` in `dev`,
`staging`, or `developer`.

## Default State

- `dev`: active
- `staging`: active
- `developer`: dormant

The overlay state is controlled by these patch files:

- `replicas-active.yaml`
- `replicas-dormant.yaml`

## Staging Release Flow

Use this for the Jenkins `release_staging` job after Docker Hub contains the
release images.

```bash
scripts/promote-staging-release.sh v1.2.3
git status --short
git add overlays scripts docs README.md
git commit -m "cd(lab2): promote staging v1.2.3"
git pull --rebase origin main
git push origin main
```

Expected result:

- all `overlays/staging` images use `v1.2.3`
- `dev` and `staging` are active
- `developer` is dormant
- `scripts/validate-gitops.sh` passes
- `scripts/validate-staging-immutable.sh` passes

Cluster evidence:

```bash
sudo k3s kubectl get app -n argocd yas-staging
sudo k3s kubectl get deploy -n staging
sudo k3s kubectl get pods -n staging
sudo k3s kubectl top nodes
curl -H 'Host: yas.staging.local' http://34.124.212.254:30080/
```

After validation, keep or restore the baseline runtime:

```bash
scripts/activate-environment.sh baseline
git add overlays
git commit -m "cd(lab2): restore dev staging baseline"
git pull --rebase origin main
git push origin main
```

## Developer Preview Policy

The `developer` namespace is intentionally dormant in this runtime policy. The
cluster is sized for `dev + staging` plus platform services, not a third full
environment. `scripts/prepare-developer-preview.sh` now exits with a clear
message instead of changing desired state.

Important app-repo note:

- CD repo policy disables developer runtime.
- App repo `main` still has a Jenkins parameter `DEPLOY_TO_DEVELOPER` that can update
  `overlays/developer`.
- Merge or revise the app-side Jenkinsfile change before treating developer as permanently
  disabled end-to-end.

```bash
scripts/prepare-developer-preview.sh tax=9f2c4a1
```

Expected result:

- `developer` is dormant
- `dev` and `staging` remain active
- `scripts/validate-gitops.sh` passes

## Rollback

Rollback by reverting the GitOps commit that changed the target overlay.

```bash
git revert <gitops-commit-sha>
scripts/validate-gitops.sh
scripts/validate-staging-immutable.sh
git push origin main
```

ArgoCD will reconcile the reverted desired state.
