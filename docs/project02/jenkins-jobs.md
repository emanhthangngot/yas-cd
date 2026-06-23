# Jenkins Jobs - Lab 2 CD

Jenkins runs from the app repo `tzin1401/yas`. It must not treat this CD repo as application source code.

## Credentials

- `dockerhub-creds`: username/password, where password is a Docker Hub access token.
- `github-gitops-ssh`: SSH private key or deploy key with push permission to `emanhthangngot/yas-cd`.
- `argocd-token`: secret text for optional `argocd app sync/get`.
- `kubeconfig-readonly`: secret file for read-only cluster smoke checks.
- Existing Lab 1 credentials in app repo: `sonarqube-token`, `snyk-token`.

Do not commit credential material, kubeconfig content, Google Cloud service account keys, SSH keys, or tokens.

## App Repo Pipeline

`yas-ci-multibranch` in `tzin1401/yas`:

- Keeps Lab 1 gates.
- Validates `services.yaml`.
- Builds and pushes Docker Hub images for changed deployable services.
- Tags images:
  - feature branch: commit SHA
  - `main`: commit SHA, `main`, `latest`
  - `vX.Y.Z`: commit SHA, `vX.Y.Z`
- Clones `git@github.com:emanhthangngot/yas-cd.git`.
- Updates `overlays/dev`, `overlays/staging`, or `overlays/developer` through `scripts/update-image-tag.sh`.
- Runs `scripts/validate-gitops.sh` before committing.
- Commits and pushes to `yas-cd/main`.

Required Jenkins environment contract:

```text
GITOPS_REPO=git@github.com:emanhthangngot/yas-cd.git
GITOPS_BRANCH=main
GITOPS_CREDENTIALS_ID=github-gitops-ssh
```

GitOps push sequence:

```bash
git clone "$GITOPS_REPO" yas-cd
cd yas-cd
git checkout "$GITOPS_BRANCH"
scripts/update-image-tag.sh "$TARGET_ENV" "$SERVICE_NAME" "$IMAGE_TAG"
git status --short
git add services.yaml overlays
git commit -m "cd(lab2): update ${TARGET_ENV} image tags [skip ci]"
git pull --rebase origin "$GITOPS_BRANCH"
git push origin "$GITOPS_BRANCH"
```

## CD Actions

- `developer_build`: resolve selected service branches to commit SHA, build/push missing tags, update `overlays/developer`, then sync or wait for `yas-developer`.
- `teardown_developer`: remove or disable developer desired state through GitOps and let ArgoCD prune.
- `deploy_dev`: update `overlays/dev` from successful `main` images.
- `release_staging`: update `overlays/staging` only with `vX.Y.Z` image tags.
- `rollback_environment`: revert overlay to a previous tag or GitOps commit.
- `cluster_smoke_check`: run read-only `kubectl`, `argocd`, and curl checks.

## Skip-CI Rule

GitOps commits live in `yas-cd`, so they must not trigger full Maven/image CI in `tzin1401/yas`. App repo CI should still run normally for source code changes.
