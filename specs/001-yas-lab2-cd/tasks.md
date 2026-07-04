# Tasks: YAS Lab 2 CD GitOps Repository

## Phase 1 - Repo Split Foundation

- [x] Create local `yas-cd` Git repository.
- [x] Move GitOps desired state into root-level `base/`, `overlays/`, and `argocd/`.
- [x] Move chart snapshot into `charts/`.
- [x] Move project docs into `docs/project02/`.
- [x] Move Spec Kit runtime into `.specify/`.
- [x] Move Spec Kit feature artifacts into `specs/001-yas-lab2-cd/`.
- [x] Move agent context/playbooks/skills into `.agents/`.
- [x] Create remote `git@github.com:emanhthangngot/yas-cd.git`.
- [x] Push branch `lab2/task/tri-xuan` to remote.

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

- [x] Update `tzin1401/yas` Jenkinsfile to clone and push `yas-cd`.
- [x] Replace active `deploy/gitops/**`, `docs/project02/**`, `.specify/**`, `specs/001-yas-lab2-cd/**`, and `.agents/**` in app repo with pointers or remove them.
- [x] Keep Lab 1 CI gates intact in the app repo.
- [x] Verify GitOps commits no longer trigger app repo full CI.

## Phase 4 - Cluster And Evidence

- [x] Provision one 32 GB Google Cloud VM and reserve or record its external IP.
- [x] Configure GCP firewall for app/demo ports and admin-only access.
- [x] Execute K3s single-node cluster runbook.
- [x] Verify K3s local-path storage, then install ingress, ArgoCD, Istio, and Kiali.
- [x] Apply `argocd/apps/` and confirm apps are `Synced/Healthy`.
- [x] Capture required evidence logs/screenshots.

## Checkpoint

- [x] CD repo contains docs, Spec Kit, and agent skills.
- [x] CD repo exists on GitHub under `emanhthangngot/yas-cd`.
- [x] App repo only owns app source and CI.
- [x] ArgoCD apps sync from `yas-cd/main`.
- [x] CQ service scope is aligned in CD repo.
- [x] `dev` and `staging` run in parallel by desired state.
- [x] `developer` is dormant by desired state.
- [x] Staging CPU and rollout surge are capped for the single-node VM.
- [ ] App repo `main` fully matches the new developer-dormant policy.
- [ ] Jenkins multibranch tag discovery for `vX.Y.Z` releases is confirmed.
- [ ] Runtime state after CD PR #14 is re-verified and captured.
- [ ] Service mesh evidence is captured.

## Phase 5 - Platform Infrastructure And Istio Sidecar Readiness

- [ ] Document platform infrastructure contract for active `dev` and `staging`
  workloads: PostgreSQL, Redis, Kafka, Elasticsearch, Keycloak, identity
  aliases, ingress NodePorts, and K3s local-path PVCs.
- [ ] Verify `yas-platform` is `Synced/Healthy` before accepting `yas-dev` or
  `yas-staging` health.
- [ ] Verify required platform namespaces exist: `postgres`, `redis`, `kafka`,
  `elasticsearch`, and `keycloak`.
- [ ] Verify platform pods are ready: PostgreSQL, Redis, Kafka,
  Elasticsearch, and Keycloak.
- [ ] Verify stateful infrastructure PVCs are `Bound` for PostgreSQL, Kafka,
  and Elasticsearch.
- [ ] Verify required PostgreSQL databases exist for CQ services and runtime
  dependencies.
- [ ] Verify internal service names used by app pods exist and route to the
  correct infrastructure endpoints.
- [ ] Add GitOps-managed Istio injection policy for required `dev` workloads.
- [ ] Add GitOps-managed Istio injection policy for required `staging`
  workloads.
- [ ] Add or update `PeerAuthentication`, `DestinationRule`, `VirtualService`,
  and `AuthorizationPolicy` resources for `dev`.
- [ ] Add or update `PeerAuthentication`, `DestinationRule`, `VirtualService`,
  and `AuthorizationPolicy` resources for `staging`.
- [ ] Render `overlays/dev` and confirm required workload pod templates opt in
  to sidecar injection.
- [ ] Render `overlays/staging` and confirm required workload pod templates
  opt in to sidecar injection while preserving CPU throttle and `maxSurge: 0`.
- [ ] Reconcile or restart affected `dev` workloads after sidecar injection is
  enabled.
- [ ] Reconcile or restart affected `staging` workloads after sidecar
  injection is enabled.
- [ ] Capture `kubectl get pods -n dev` evidence showing all required running
  app pods as `READY 2/2`.
- [ ] Capture `kubectl get pods -n staging` evidence showing all required
  running app pods as `READY 2/2`.
- [ ] Capture representative container-name evidence showing `istio-proxy`
  exists beside the application container in `dev` and `staging`.
- [ ] Capture mTLS, retry, authorization allow/deny, and Kiali topology
  evidence from `dev` and `staging`; treat `mesh-demo` as supporting evidence
  only.
- [ ] Document any approved sidecar exception with service name, reason,
  compensating evidence, and approval note.
