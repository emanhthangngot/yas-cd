# Plan: YAS Lab 2 CD GitOps Repository

## Summary

Use a two-repository model. `tzin1401/yas` remains the app and CI repo. `emanhthangngot/yas-cd` owns GitOps desired state, ArgoCD apps, CD docs, Spec Kit artifacts, and agent context.

## Repository Layout

```text
base/
overlays/
  dev/
  staging/
  developer/
argocd/
  apps/
charts/
scripts/
docs/project02/
specs/001-yas-lab2-cd/
.specify/
.agents/
```

## Implementation Decisions

- ArgoCD source repo is `git@github.com:emanhthangngot/yas-cd.git`.
- ArgoCD target revision is `main`.
- Jenkins in the app repo clones this repo, updates `overlays/<env>/kustomization.yaml`, commits, and pushes.
- Chart snapshot under `charts/` allows this repo to render independently.
- `services.yaml` is a CD snapshot. App repo changes to service catalog must be synced here before overlay changes.

## Remaining Work

- Update the app repo Jenkinsfile to push GitOps commits to `yas-cd`.
- Apply ArgoCD apps from `argocd/apps/` on the GCP cluster.

## Risks

- Catalog drift between app repo and CD repo: mitigate by syncing `services.yaml` from app repo during Jenkins CD updates.
- Chart drift between app repo and CD repo: mitigate by syncing `charts/` when Helm chart templates change.
- Jenkins credential scope too broad: use a deploy key or fine-scoped token for `yas-cd` only.
