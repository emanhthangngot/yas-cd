# Project Map

## Root

- `services.yaml`: render-time service catalog snapshot for CD validation.
- `base/`: namespace-neutral Kustomize base for deployable YAS services.
- `overlays/`: environment overlays for `dev`, `staging`, and `developer`.
- `argocd/apps/`: ArgoCD Application manifests.
- `charts/`: Helm chart snapshot copied from the app repo for independent Kustomize rendering.
- `scripts/`: CD validation helpers.
- `docs/project02/`: Lab 2 CD plan, runbooks, assignment, and evidence guidance.
- `.specify/` and `specs/001-yas-lab2-cd/`: Spec Kit SDD workflow for the CD repo.

## External Repo Boundary

- App/CI repo: `git@github.com:tzin1401/yas.git`
- This repo: `git@github.com:emanhthangngot/yas-cd.git`
- Jenkins runs in the app repo, builds images, then commits overlay changes here.
- ArgoCD syncs only from this repo.

## Agent Entry Points

1. Read `AGENTS.md`.
2. Read `docs/project02/final-plan-lab2-cd.md`.
3. Read `services.yaml`.
4. Read `specs/001-yas-lab2-cd/`.
5. Read `docs/project02/cluster-runbook.md` before cluster, firewall, ingress, ArgoCD, or mesh work.
6. Render affected overlays before editing or committing GitOps changes.
