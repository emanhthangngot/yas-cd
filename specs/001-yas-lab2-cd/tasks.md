# Tasks: YAS Lab 2 CD GitOps Repository

## Phase 1 - Repo Split Foundation

- [x] Create local `yas-cd` Git repository.
- [x] Move GitOps desired state into root-level `base/`, `overlays/`, and `argocd/`.
- [x] Move chart snapshot into `charts/`.
- [x] Move project docs into `docs/project02/`.
- [x] Move Spec Kit runtime into `.specify/`.
- [x] Move Spec Kit feature artifacts into `specs/001-yas-lab2-cd/`.
- [x] Move agent context/playbooks/skills into `.agents/`.
- [ ] Create remote `git@github.com:emanhthangngot/yas-cd.git`.
- [ ] Push branch `lab2/task/tri-xuan` to remote.

## Phase 2 - GitOps Validation

- [x] Update ArgoCD app manifests to target `yas-cd/main`.
- [x] Update Kustomize chart path for standalone CD repo render.
- [x] Update staging immutability script for new overlay path.
- [x] Add GitOps validation script for catalog, overlays, stale references, and secret-pattern scan.
- [x] Add Jenkins image-tag update contract script.
- [x] Render `dev`, `staging`, and `developer` overlays successfully.
- [x] Confirm no ArgoCD app points back to `tzin1401/yas.git`.
- [x] Confirm no committed real secrets.

## Phase 3 - App Repo Integration

- [ ] Update `tzin1401/yas` Jenkinsfile to clone and push `yas-cd`.
- [ ] Replace active `deploy/gitops/**`, `docs/project02/**`, `.specify/**`, `specs/001-yas-lab2-cd/**`, and `.agents/**` in app repo with pointers or remove them.
- [ ] Keep Lab 1 CI gates intact in the app repo.
- [ ] Verify GitOps commits no longer trigger app repo full CI.

## Phase 4 - Cluster And Evidence

- [ ] Provision one 32 GB Google Cloud VM and reserve or record its external IP.
- [ ] Configure GCP firewall for app/demo ports and admin-only access.
- [ ] Execute K3s single-node cluster runbook.
- [ ] Verify K3s local-path storage, then install ingress, ArgoCD, Istio, and Kiali.
- [ ] Apply `argocd/apps/` and confirm apps are `Synced/Healthy`.
- [ ] Capture required evidence logs/screenshots.

## Checkpoint

- [x] CD repo contains docs, Spec Kit, and agent skills.
- [ ] CD repo exists on GitHub under `emanhthangngot/yas-cd`.
- [ ] App repo only owns app source and CI.
- [ ] ArgoCD apps sync from `yas-cd/main`.
- [ ] Developer deployment includes platform dependencies.
