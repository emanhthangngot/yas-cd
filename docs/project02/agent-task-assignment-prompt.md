# Agent Task Assignment Prompt - Lab 2 CD Split Repo

This file is the canonical assignment prompt for the current split-repo plan.
The older monorepo-style prompt in `tzin1401/yas` is legacy context only.

## Context

Lab 1 CI lives in `tzin1401/yas`. Lab 2 CD desired state lives in `emanhthangngot/yas-cd`.
The CD repo owns only GitOps desired state, runbooks, Spec Kit artifacts, and agent context.

Runtime source of truth: one Google Cloud Compute Engine VM, 32 GB RAM, Ubuntu 24.04 LTS, `k3s` single-node Kubernetes. Do not use Tailscale.

## Hard Rules

- Do not commit real secrets, tokens, kubeconfigs, SSH keys, Docker Hub tokens, Snyk tokens, SonarQube tokens, ArgoCD tokens, or Google Cloud service account keys.
- Do not use `kubectl set image`, `kubectl apply`, or `kubectl delete` directly in namespaces managed by ArgoCD: `dev`, `staging`, `developer`.
- Jenkins in `tzin1401/yas` builds images and pushes GitOps commits to `emanhthangngot/yas-cd`.
- ArgoCD syncs only from `emanhthangngot/yas-cd/main`.
- Staging must not use mutable tags such as `latest`, `main`, or branch names.
- Admin UIs are not public-open; use SSH tunnel or GCP firewall allowlist.

## Team Ownership

| Member | Role | Scope | Done When |
|---|---|---|---|
| Trí Xuân | Cluster + CD integration owner | GCP VM, K3s, ArgoCD bootstrap from `emanhthangngot/yas-cd`, mesh evidence | VM/cluster runs, ArgoCD apps Healthy, mesh evidence captured |
| Vinh Nhỏ | Jenkins + image pipeline owner | `tzin1401/yas` Jenkinsfile, Docker Hub image pipeline, credentials binding, update `emanhthangngot/yas-cd` overlays | CI/CD jobs run, image tags correct, deploy/rollback/smoke job logs captured |
| Vinh Bự | GitOps + security + report owner | `emanhthangngot/yas-cd` overlays, ArgoCD apps, secret/RBAC audit, report/evidence | CD repo renders, app YAML correct, report complete |

## Implementation Boundary

- App repo `tzin1401/yas`: source code, Lab 1 CI, Docker build/push, Jenkins logic.
- CD repo `emanhthangngot/yas-cd`: desired state, ArgoCD apps, overlays, docs, evidence, scripts.
- Jenkins may read `services.yaml` from the app repo, but it must write GitOps changes only to `emanhthangngot/yas-cd`.
- ArgoCD must sync only from `emanhthangngot/yas-cd/main`.
- Staging must deploy only immutable release tags.

## Final Demo Flow

1. Show GCP VM, firewall, and cluster evidence.
2. Show Jenkins Lab 1 CI gates still active in `tzin1401/yas`.
3. Push feature branch and build Docker Hub image tag.
4. Run `developer_build`; show Jenkins updates `emanhthangngot/yas-cd`.
5. Show ArgoCD syncs `yas-developer` from `emanhthangngot/yas-cd/main`.
6. Push/merge main; show `yas-dev` sync.
7. Push release tag; show `yas-staging` sync with immutable tag.
8. Run rollback and teardown.
9. Show mesh evidence.
