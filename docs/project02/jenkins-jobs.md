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

- Current app repo `main` has one `Jenkinsfile`, not three separate Jenkinsfiles.
- The main Jenkinsfile selects the CD path by `TAG_NAME` and `BRANCH_NAME`.
- Keeps Lab 1 gates.
- Validates `services.yaml`.
- Builds and pushes Docker Hub images for changed deployable services.
- Tags images:
  - feature branch: commit SHA
  - `main`: commit SHA, `main`, `latest`
  - `vX.Y.Z`: promote existing commit SHA images to `vX.Y.Z`
- Clones `git@github.com:emanhthangngot/yas-cd.git`.
- Updates `overlays/dev` through `scripts/update-image-tag.sh` and
  `overlays/staging` through `scripts/promote-staging-release.sh`.
- Runs `scripts/validate-gitops.sh` before committing.
- Commits and pushes to `yas-cd/main`.

Current target selection on app repo `main`:

- `TAG_NAME=vX.Y.Z`: target `staging`, image tag `vX.Y.Z`.
- `BRANCH_NAME=main`: target `dev`, image tag `main`.
- Feature branch: image is pushed with commit SHA, GitOps update is skipped.

Release tags follow build-once/promote-many. The tag job verifies the
corresponding commit-SHA image exists in Docker Hub and creates the release tag
with `docker buildx imagetools create`; it fails instead of rebuilding if the
source image is missing.

Current CD repo runtime policy:

- `dev` and `staging` run in parallel.
- `developer` stays dormant.

Important mismatch to resolve:

- Developer preview belongs in the separate `Jenkinsfile.developer-build` job that updates this CD repo via GitOps.
- The Jenkinsfile contains release-tag logic, but Jenkins multibranch must be configured to
  discover/build Git tags for the staging release flow to run automatically.

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

- `developer_build`: separate parameterized job for the course-required developer preview. It commits `overlays/developer` through GitOps, activates preview mode (`dev + developer`), and does not run `kubectl apply`.
- `teardown_developer`: restore the baseline where `developer` is dormant and `dev`/`staging` are active.
- `deploy_dev`: update `overlays/dev` from successful `main` images.
- `release_staging`: update `overlays/staging` only with `vX.Y.Z` image tags, then require explicit `argocd app sync yas-staging` approval.
- `rollback_environment`: revert overlay to a previous tag or GitOps commit.
- `cluster_smoke_check`: run read-only `kubectl`, `argocd`, and curl checks.

## Skip-CI Rule

GitOps commits live in `yas-cd`, so they must not trigger full Maven/image CI in `tzin1401/yas`. App repo CI should still run normally for source code changes.
