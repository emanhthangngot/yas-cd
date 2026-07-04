# Staging And Developer CD Runbook

This runbook keeps the single-node K3s cluster stable while validating
`staging` and `developer`. The rule is one active full-stack environment at a
time. Jenkins must change this repository and let ArgoCD reconcile the cluster.
Do not use `kubectl set image` or direct `kubectl apply` in `dev`, `staging`,
or `developer`.

## Default State

- `dev`: active
- `staging`: dormant
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
- `staging` is active
- `dev` and `developer` are dormant
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

After validation, restore the default runtime:

```bash
scripts/activate-environment.sh dev
git add overlays
git commit -m "cd(lab2): return staging to dormant"
git pull --rebase origin main
git push origin main
```

## Developer Preview Flow

Use this for the Jenkins `developer_build` job after building and pushing the
selected branch images.

```bash
scripts/prepare-developer-preview.sh tax=9f2c4a1 payment=6d7e8f9
git status --short
git add overlays scripts docs README.md
git commit -m "cd(lab2): activate developer preview"
git pull --rebase origin main
git push origin main
```

Expected result:

- selected services use the supplied commit SHA tags
- unselected services reset to `main`
- `developer` is active
- `dev` and `staging` are dormant
- `scripts/validate-gitops.sh` passes

Cluster evidence:

```bash
sudo k3s kubectl get app -n argocd yas-developer
sudo k3s kubectl get deploy -n developer
sudo k3s kubectl get pods -n developer
sudo k3s kubectl top nodes
curl -H 'Host: yas.developer.local' http://34.124.212.254:30080/
```

## Developer Teardown Flow

Use this for the Jenkins `teardown_developer` job.

```bash
scripts/teardown-developer.sh
git add overlays
git commit -m "cd(lab2): teardown developer preview"
git pull --rebase origin main
git push origin main
```

Expected result:

- `developer` is dormant
- all developer image tags reset to `main`
- `dev` is active
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
