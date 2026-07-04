# Lab 2 CD Implementation Progress

Last updated: 2026-07-04

CD repo: `git@github.com:emanhthangngot/yas-cd.git`
App repo: `git@github.com:tzin1401/yas.git`

This file records the current repo and runtime progress. For a short handoff
before starting a new chat, read `docs/project02/current-handoff.md` first.

## Current Status Summary

| Area | Status | Notes |
|---|---|---|
| Split GitOps repo | Done | CD repo owns `base/`, `overlays/`, `argocd/`, `charts/`, docs, specs, and agent context. |
| CQ service scope | Done in CD repo | Merged through CD PR #11; normal runtime excludes non-required heavy services. |
| Runtime policy | Done in CD repo | Merged through CD PR #12; `dev` and `staging` active, `developer` dormant. |
| Staging resource control | Done in CD repo | PR #13 sets staging CPU throttle; PR #14 sets `maxSurge: 0` rollouts. |
| ArgoCD apps | Implemented and previously observed | `yas-dev`, `yas-staging`, `yas-developer` point at `yas-cd/main`. Re-check after PR #14. |
| App repo Jenkinsfile | Partially aligned on `main` | One Jenkinsfile exists. `main` still has old `DEPLOY_TO_DEVELOPER` behavior. |
| Staging release tag flow | Implemented in Jenkinsfile/CD scripts | Needs Jenkins tag-discovery verification. |
| Service mesh | Planned/documented | Needs final runtime evidence. |
| Final evidence pack | In progress | Use `.agents/evidence/README.md`. |

## Recent CD Repo PRs

- PR #11: `cd(lab2): align cq demo service scope`
  - Kept teacher-required services and minimal runtime dependencies.
  - Added `swagger-ui`.
  - Kept `sampledata` dormant after seeding.
  - Removed `promotion`, `rating`, `recommendation`, and `webhook` from normal runtime pressure.
- PR #12: `cd(lab2): run dev staging in parallel`
  - `dev` active.
  - `staging` active.
  - `developer` dormant.
  - `scripts/activate-environment.sh baseline` now restores this policy.
- PR #13: `cd(lab2): throttle staging cpu usage`
  - Staging services render with lower CPU request/limit.
  - Observed staging service limits: `250m` CPU, memory limits unchanged.
- PR #14: `cd(lab2): cap staging rollout surge`
  - Staging rollouts render with `maxSurge: 0` and `maxUnavailable: 1`.
  - Purpose: avoid temporarily doubling Java pods on the single-node VM.

## Current Desired State

Runtime policy:

- `dev`: active.
- `staging`: active.
- `developer`: dormant.
- `sampledata`: dormant after seed data is available.

Image tag policy:

- `dev`: mutable `main` image tags.
- `staging`: immutable release tags only, such as `v1.2.3`.
- `developer`: dormant; app repo `main` can still update it if `DEPLOY_TO_DEVELOPER=true`, so merge or revise that app-side behavior before relying on the dormant policy end-to-end.

## App Repo Jenkins State

Checked after returning local app repo to `main`:

- Only one Jenkinsfile exists.
- No separate dev/staging/developer Jenkinsfiles exist.
- One Jenkinsfile selects behavior using `TAG_NAME`, `BRANCH_NAME`, and `DEPLOY_TO_DEVELOPER`.
- Feature branch image tag: short commit id.
- `main` image tags: short commit id, `main`, and `latest`.
- Release tag image tags: short commit id and `vX.Y.Z`.
- GitOps target:
  - `TAG_NAME=vX.Y.Z` -> `staging`
  - `BRANCH_NAME=main` -> `dev`
  - feature branch with `DEPLOY_TO_DEVELOPER=true` -> `developer`
  - feature branch with `DEPLOY_TO_DEVELOPER=false` -> no GitOps update

Important follow-up:

- The app repo branch/PR that disables developer preview GitOps is not merged into app repo `main` yet.
- Jenkins multibranch tag discovery for `vX.Y.Z` release jobs still needs verification.

## Last Runtime Observation

Last observed before the final runtime refresh was interrupted:

- `yas-dev`: `Synced/Healthy`.
- `yas-staging`: `Synced/Progressing`, but all staging deployments were observed `1/1`.
- `yas-developer`: `Synced/Healthy`, all deployments `0/0`.
- Node CPU was high because staging rollout and Jenkins jobs were running at the same time.

Required re-check after CD PR #14:

```bash
ssh -i ~/.ssh/gcp_key_member -F /dev/null -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new xuantri@34.124.212.254 '
sudo k3s kubectl get applications -n argocd yas-dev yas-staging yas-developer -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision --no-headers
sudo k3s kubectl get deploy -n dev --no-headers | awk "{print \$1,\$2}" | sort
sudo k3s kubectl get deploy -n staging --no-headers | awk "{print \$1,\$2}" | sort
sudo k3s kubectl get deploy -n developer --no-headers | awk "{print \$1,\$2}" | sort
sudo k3s kubectl top nodes 2>/dev/null || true
sudo k3s kubectl top pods -A --sort-by=cpu 2>/dev/null | head -30 || true
'
```

## Required Local Checks Before Any Commit

```bash
git status --short
scripts/validate-gitops.sh
scripts/validate-staging-immutable.sh
git diff --check
```

For staging changes, also render and inspect rollout/resource policy:

```bash
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging \
  | yq e 'select(.kind == "Deployment") | .metadata.name + " replicas=" + (.spec.replicas | tostring) + " maxSurge=" + (.spec.strategy.rollingUpdate.maxSurge | tostring) + " cpuLimit=" + (.spec.template.spec.containers[0].resources.limits.cpu | tostring)' - \
  | sort
```

## Remaining Work

1. Decide whether to merge the app repo PR/branch that disables developer preview GitOps.
2. Confirm Jenkins multibranch is configured to discover/build Git tags.
3. Trigger or simulate a `vX.Y.Z` release and confirm staging GitOps update.
4. Re-check ArgoCD and cluster health after CD PR #14.
5. Capture evidence for dev, staging, Docker Hub tags, ArgoCD sync, external access, and mesh.
