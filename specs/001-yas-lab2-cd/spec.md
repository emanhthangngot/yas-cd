# Spec: YAS Lab 2 CD GitOps Repository

## Objective

Build and operate the Lab 2 CD layer for YAS using a two-repository model. The app repo `tzin1401/yas` preserves Lab 1 CI gates and builds Docker Hub images. This repo `emanhthangngot/yas-cd` is the GitOps source of truth for Kubernetes desired state, ArgoCD apps, CD documentation, Spec Kit artifacts, and agent context.

## Users

- Developer: pushes branches to the app repo and deploys preview images through Jenkins `developer_build`.
- Release owner: tags `vX.Y.Z` in the app repo and promotes immutable staging images.
- Operator: validates the GCP VM, Kubernetes, ArgoCD, rollback, teardown, and service mesh evidence.
- GitOps maintainer: reviews desired-state diffs in this CD repo.

## Functional Requirements

- FR-001: ArgoCD must sync from `git@github.com:emanhthangngot/yas-cd.git`, branch `main`.
- FR-002: The app repo `tzin1401/yas` must remain the source for CI, tests, Docker build, and image push.
- FR-003: Jenkins must update this repo's `overlays/<env>` files rather than mutate ArgoCD-managed namespaces directly.
- FR-004: `services.yaml` in this repo must be kept as a render-time snapshot of deployable services.
- FR-005: This repo must render `dev`, `staging`, and `developer` overlays independently using the chart snapshot under `charts/`.
- FR-006: Staging must deploy only immutable release tags in the form `vX.Y.Z`.
- FR-007: Jenkins must update image tags through `scripts/update-image-tag.sh` and run `scripts/validate-gitops.sh` before pushing `main`.
- FR-008: `developer_build` must deploy branch-specific images for selected services and default all others to `main`.
- FR-009: `teardown_developer` must remove developer resources through GitOps/ArgoCD prune.
- FR-010: Service mesh evidence must show mTLS, authorization allow/deny, retry, and Kiali topology.
- FR-011: The cluster runbook must provision a GCP VM based `k3s` single-node cluster without Tailscale.
- FR-012: Admin interfaces must be accessed through SSH tunnels or firewall allowlisting, not broad public exposure.

## Non-Functional Requirements

- NFR-001: No real secrets are committed.
- NFR-002: Base GitOps manifests must not hardcode environment namespaces.
- NFR-003: NodePort, hosts-file DNS, K3s bundled local-path storage, and demo credentials must be documented as lab-only.
- NFR-004: GitOps commits in this repo must not trigger full app CI in `tzin1401/yas`.
- NFR-005: The plan must not rely on Tailscale.

## Success Criteria

- Jenkins in `tzin1401/yas` still passes Lab 1 CI for a changed service.
- Docker Hub contains commit SHA, `main/latest`, and `vX.Y.Z` image tags.
- Jenkins commits image tag updates to `emanhthangngot/yas-cd`.
- ArgoCD apps for `dev`, `staging`, and `developer` point to this repo and are `Synced/Healthy`.
- `developer_build` deploys one branch-specific service with dependencies ready.
- Teardown and rollback produce auditable Jenkins, Git, and ArgoCD logs.
- App URLs are reachable through the GCP VM external IP plus hosts file or Host header.
- Mesh demo has curl and Kiali evidence.

## Boundaries

- Always: follow `AGENTS.md`, render manifests before GitOps commits, restrict admin access, and keep secrets out of Git.
- Ask first: changing Java/Spring version decision, removing app CI gates, adding real external services, exposing admin UIs publicly, or replacing K3s with another Kubernetes distribution.
- Never: commit secrets, deploy direct into ArgoCD-managed namespaces, use GHCR upstream images for final CD, or reintroduce Tailscale as the Lab 2 network path.
