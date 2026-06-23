# YAS Lab 2 CD Context Summary

## Muc tieu hien tai

Repo `yas-cd` la GitOps/CD source of truth cho Lab 2. App/CI repo van la `tzin1401/yas`; repo nay chi giu desired state Kubernetes, ArgoCD apps, docs, Spec Kit artifacts, va agent context.

## Nguon su that chinh

- App/CI repo: `git@github.com:tzin1401/yas.git`
- CD/GitOps repo: `git@github.com:emanhthangngot/yas-cd.git`
- ArgoCD sync branch: `main`
- Feature/migration branch trong CD repo: `lab2/task/tri-xuan`
- Runtime target: 1 Google Cloud Compute Engine VM, 32 GB RAM, Ubuntu 24.04 LTS, `k3s` single-node
- Khong dung Tailscale

## Quy uoc kien truc da chot

- Jenkins trong `tzin1401/yas` build/test/push image, sau do clone `emanhthangngot/yas-cd` va update overlay desired state.
- ArgoCD chi sync tu `emanhthangngot/yas-cd/main`.
- GitOps update phai di qua `scripts/update-image-tag.sh` thay vi sua YAML thu cong.
- Validation phai di qua `scripts/validate-gitops.sh` va `scripts/validate-staging-immutable.sh`.
- Staging chi duoc deploy tag bat bien `vX.Y.Z`.
- `dev` va `developer` co the dung `main` cho image tag mac dinh.

## Cac file quan trong trong `yas-cd`

- `AGENTS.md`: rules chinh cua repo CD
- `README.md`: boundary app repo vs CD repo, validation commands
- `argocd/apps/*.yaml`: ArgoCD Applications tro ve `main`
- `scripts/update-image-tag.sh`: contract script cho Jenkins/CD updates
- `scripts/validate-gitops.sh`: validation tong hop cho overlays, stale refs, secret-like patterns
- `specs/001-yas-lab2-cd/*`: Spec Kit feature artifacts
- `docs/project02/*`: runbook, decisions, task split, report scaffolding

## Dang da hoan thanh

- Tao local repo `yas-cd`
- Tach desired state sang `base/`, `overlays/`, `argocd/`
- Tach chart snapshot sang `charts/`
- Tach docs sang `docs/project02/`
- Tach Spec Kit sang `.specify/`
- Tach agent context/skills sang `.agents/`
- Tao remote private repo `emanhthangngot/yas-cd`
- Push `main` va `lab2/task/tri-xuan`
- Chuyen ArgoCD source repo sang `emanhthangngot/yas-cd`
- Chuyen target platform docs/spec sang `k3s` single-node
- Cap nhat chart placeholders de khong dung demo secret cu
- Them `validate-gitops.sh` va `update-image-tag.sh`

## Trang thai hien tai

- `origin/main` va `origin/lab2/task/tri-xuan` dang cung commit
- Repo local sach sau validation
- `scripts/validate-gitops.sh` pass
- `scripts/validate-staging-immutable.sh` pass
- `kustomize build` cho `overlays/dev`, `overlays/staging`, `overlays/developer` pass
- ArgoCD apps da trỏ `git@github.com:emanhthangngot/yas-cd.git` va `main`

## Viec con lai

- Sua `Jenkinsfile` trong repo app `tzin1401/yas` de clone/push `emanhthangngot/yas-cd`
- Dam bao app repo van giu Lab 1 CI gates
- Trien khai thuc te GCP VM 32 GB, firewall, K3s, ingress, ArgoCD, Istio, Kiali
- Lay evidence cho report: node Ready, StorageClass, ArgoCD health, Jenkins logs, mesh evidence

## Luong hoat dong end-to-end

```text
Developer push code to tzin1401/yas
  -> Jenkins CI gates in app repo
  -> Jenkins builds/pushes Docker Hub image
  -> Jenkins clones emanhthangngot/yas-cd
  -> Jenkins runs scripts/update-image-tag.sh
  -> Jenkins validates with scripts/validate-gitops.sh
  -> Jenkins commits/pushes to yas-cd/main
  -> ArgoCD syncs dev/staging/developer
```

## Lua chon da chot

- GitOps repo owner: `emanhthangngot`
- GitOps source branch for ArgoCD: `main`
- Runtime Kubernetes: `k3s`, khong phai `kubeadm`
- CD update model: direct push to `main` sau khi validate
- Staging image policy: immutable release tags only

## Cach tiep tuc sau `/clear`

1. Doc file nay truoc.
2. Mo `AGENTS.md`, `specs/001-yas-lab2-cd/spec.md`, va `docs/project02/jenkins-jobs.md`.
3. Neu can thuc hien lab thuc te, tiep tuc tu `docs/project02/cluster-runbook.md`.
4. Neu can sua CI app repo, phai sang `tzin1401/yas` va cap nhat Jenkinsfile theo contract o tren.
