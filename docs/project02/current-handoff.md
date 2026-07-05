# Current Handoff - Lab 2 CD

Last updated: 2026-07-04

Use this file as the first context file when starting a new chat.

## Repositories

- App/CI repo: `git@github.com:tzin1401/yas.git`
- CD/GitOps repo: `git@github.com:emanhthangngot/yas-cd.git`
- CD sync branch: `main`
- App repo local checkout was returned to `main` and fast-forwarded to `origin/main`.

## Current CD Repo State

CD repo `main` includes these recent merged GitOps PRs:

- PR #11: aligned deployable service scope with the teacher CQ service PDF.
- PR #12: changed runtime policy to keep `dev` and `staging` active in parallel while `developer` stays dormant.
- PR #13: throttled staging CPU to reduce pressure on the single-node GCP VM.
- PR #14: capped staging rolling updates with `maxSurge: 0` and `maxUnavailable: 1` so updates do not temporarily double Java pods.

Current desired runtime policy:

- `dev`: active.
- `staging`: active.
- `developer`: dormant.
- `sampledata`: Deployment dormant (`0` replicas); seed data is loaded by the separate `seed_sampledata` Jenkins job through manual ArgoCD sync of `yas-<env>-sampledata-seed`.

Current deployable CQ service scope:

- `cart`
- `customer`
- `inventory`
- `location`
- `media`
- `order`
- `payment`
- `payment-paypal`
- `product`
- `search`
- `tax`
- `backoffice-bff`
- `storefront-bff`
- `backoffice-ui`
- `storefront-ui`
- `swagger-ui`

The default scope intentionally excludes `promotion`, `rating`, `recommendation`, and `webhook` from normal runtime pressure.

## Current App Repo Main State

The app repo currently has one Jenkinsfile, not three Jenkinsfiles.

Observed on app repo `main`:

- File present: `Jenkinsfile`.
- No separate `Jenkinsfile.dev`, `Jenkinsfile.staging`, or `Jenkinsfile.developer`.
- Feature branches build/push Docker images with the short commit id tag.
- `main` builds/pushes commit id, `main`, and `latest` tags.
- `vX.Y.Z` Git tags build/push commit id and `vX.Y.Z` tags.
- GitOps target selection is inside the one Jenkinsfile:
  - release tag -> `staging`
  - `main` -> `dev`
  - feature branch -> build/push image only; GitOps developer preview is skipped

Important mismatch:

- CD repo policy keeps `developer` dormant by default.
- App repo working tree removes the old `DEPLOY_TO_DEVELOPER` parameter from the main Jenkinsfile.
- The required course `developer_build` path is implemented as a separate Jenkinsfile that calls this repo's `scripts/prepare-developer-preview.sh`.
- The sample data path is implemented as a separate `Jenkinsfile.seed-sampledata` job in `yas-cd`; do not expose Kubernetes Job creation through storefront-bff.

## Staging Release Case

Staging is a separate release case and must use immutable tags.

Expected release flow:

1. Create or push a Git tag in the app repo such as `v1.2.3`.
2. Jenkins must run the multibranch/tag job for that tag.
3. Jenkins builds/pushes Docker Hub images with `:v1.2.3`.
4. Jenkins updates `overlays/staging/kustomization.yaml` through `scripts/promote-staging-release.sh v1.2.3`.
5. Jenkins commits and pushes the GitOps change to `yas-cd/main`.
6. An operator approves the release with `argocd app sync yas-staging`.

Risk to verify:

- The Jenkinsfile contains release-tag logic, but Jenkins multibranch must also be configured to discover/build Git tags. This was not confirmed because the Jenkins API became unreachable during the last check.

## Last Runtime Observation

Last verified cluster state after CD PR #13, before final PR #14 runtime refresh was interrupted:

- `yas-dev`: `Synced`, `Healthy`.
- `yas-staging`: `Synced`, `Progressing`, but all staging deployments were observed at `1/1`.
- `yas-developer`: `Synced`, `Healthy`, all deployments `0/0`.
- Node CPU was still high because staging rollout and Jenkins PR jobs were running concurrently.
- Staging CPU limits were observed as `250m` for services after PR #13.

After PR #14, the repo now has staging `maxSurge: 0`, but runtime confirmation should be repeated.

## Commands To Resume

Check CD repo:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas-cd
git status --short --branch
scripts/validate-gitops.sh
scripts/validate-staging-immutable.sh
kustomize build --load-restrictor=LoadRestrictionsNone operations/sampledata-seed/dev
kustomize build --load-restrictor=LoadRestrictionsNone operations/sampledata-seed/staging
```

Check app repo main:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas
git status --short --branch
git ls-tree -r --name-only main | grep -i 'jenkinsfile'
grep -n -E 'TAG_NAME|BRANCH_NAME|latest|target_env|DEPLOY_TO_DEVELOPER|developer|staging|release' Jenkinsfile
```

Check cluster:

```bash
ssh -i ~/.ssh/gcp_key_member -F /dev/null -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new xuantri@34.124.212.254 '
sudo k3s kubectl get applications -n argocd yas-dev yas-staging yas-developer -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision --no-headers
sudo k3s kubectl get deploy -n dev --no-headers | awk "{print \\$1,\\$2}" | sort
sudo k3s kubectl get deploy -n staging --no-headers | awk "{print \\$1,\\$2}" | sort
sudo k3s kubectl get deploy -n developer --no-headers | awk "{print \\$1,\\$2}" | sort
sudo k3s kubectl top nodes 2>/dev/null || true
sudo k3s kubectl top pods -A --sort-by=cpu 2>/dev/null | head -30 || true
'
```

## Next Decisions

1. Decide whether to merge the app repo PR/branch that disables developer GitOps previews.
2. Confirm Jenkins tag discovery for `vX.Y.Z` release jobs.
3. Re-check ArgoCD after PR #14 to confirm staging rollout cap is applied.
4. Collect final evidence for `dev`, `staging`, ArgoCD, Docker Hub tags, and service mesh.
5. Keep app runtime access examples on NodePort `30846`; older `30080` examples are legacy Traefik references unless re-verified.
