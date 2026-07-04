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
commit-SHA images. The release path promotes those existing images to the
immutable `vX.Y.Z` tag; it must not rebuild source code for a release tag.
`yas-staging` is intentionally a manual-sync ArgoCD app, so a GitOps release
commit does not change cluster runtime until an operator approves the sync.

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
- Docker Hub `v1.2.3` images point at images that already existed for the
  release commit SHA
- `dev` and `staging` are active
- `developer` is dormant
- `scripts/validate-gitops.sh` passes
- `scripts/validate-staging-immutable.sh` passes

Approve the release in ArgoCD:

```bash
argocd app diff yas-staging
argocd app sync yas-staging
argocd app wait yas-staging --health --sync --timeout 600
```

Cluster evidence:

```bash
sudo k3s kubectl get app -n argocd yas-staging
sudo k3s kubectl get deploy -n staging
sudo k3s kubectl get pods -n staging
sudo k3s kubectl top nodes
curl -H 'Host: yas.staging.local' http://34.124.212.254:30846/
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

The `developer` namespace is dormant in the default runtime policy. For the
course-required `developer_build` demo, use a separate GitOps preview mode that
keeps `dev` active, switches `staging` dormant, and activates `developer`. This
avoids running three full Java environments on the single-node VM.

Important app-repo note:

- CD repo keeps developer dormant by default.
- The main app pipeline does not deploy developer previews.
- The explicit preview path is the separate Jenkins `developer_build` job.

```bash
scripts/prepare-developer-preview.sh tax=9f2c4a1
git status --short
git add overlays
git commit -m "cd(lab2): prepare developer tax preview"
git pull --rebase origin main
git push origin main
argocd app sync yas-developer
```

Expected result:

- `developer` is active with the requested image tag
- `dev` remains active
- `staging` is dormant during preview
- `YAS_CD_EXPECTED_ACTIVE="dev developer" scripts/validate-gitops.sh` passes
- developer access uses `http://yas.developer.local:30846/`

Teardown restores the baseline:

```bash
scripts/teardown-developer.sh
git add overlays
git commit -m "cd(lab2): teardown developer preview"
git pull --rebase origin main
git push origin main
argocd app sync yas-developer
argocd app sync yas-staging
```

Expected result:

- `developer` is dormant again
- `dev` and `staging` are active
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
