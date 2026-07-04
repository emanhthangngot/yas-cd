# Development Roadmap - GCP VM Lab 2 CD

## Milestones

| Milestone | Output |
|---|---|
| M0 | Source-of-truth docs/spec/agent context updated for GCP VM |
| M1 | GCP VM, firewall, K3s single-node, bundled local-path storage |
| M2 | Ingress, ArgoCD, GitOps apps |
| M3 | Jenkins CD jobs and Docker Hub image tags |
| M4 | Developer/dev/staging deployment evidence |
| M5 | Istio/Kiali mesh evidence |
| M6 | Final report evidence pack |

## M0 - Source Of Truth

Acceptance:

- `AGENTS.md`, `.specify/memory/constitution.md`, `specs/001-yas-lab2-cd/*`, `.agents/*`, and `docs/project02/*` describe GCP VM single-node.
- No current runbook tells operators to install or use Tailscale.
- Java 25/Spring Boot 4.0.2 decision remains unchanged.

Evidence:

```bash
grep -RIn "[t]ailscale status\\|[t]ailscale up\\|MASTER_[T]AILSCALE\\|WORKER_[T]AILSCALE" \
  AGENTS.md .agents .specify specs docs/project02 \
  --exclude=Project02_HKII_25_26.md
```

Expected result: no active setup instructions remain.

## M1 - GCP VM And Kubernetes

Provision:

- Ubuntu 24.04 LTS.
- 32 GB RAM.
- 4-8 vCPU recommended.
- 150 GB+ disk.
- Static or recorded external IP.

Firewall:

- SSH only from admin IP.
- Demo app ports only for required audience.
- Admin ports restricted or tunneled.

Bootstrap:

- Install K3s with embedded containerd, bundled Flannel, and bundled local-path storage.
- Disable bundled Traefik and ServiceLB during K3s install.
- Install Helm, `yq`, Git, `kustomize`, `argocd`, and `istioctl`.
- Verify the K3s server node can schedule workloads.

Acceptance:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass,pvc -A
```

## M2 - Ingress And ArgoCD

Install Nginx Ingress:

```text
HTTP  30080
HTTPS 30081
```

Install ArgoCD:

```text
ArgoCD UI 30444, admin-only
```

Apply app manifests:

```bash
kubectl apply -f argocd/apps/
argocd app list
```

Acceptance:

- `yas-dev`, `yas-staging`, `yas-developer` exist.
- Apps eventually become `Synced/Healthy` after overlays are populated.
- No NodePort conflict.

## M3 - Jenkins CD

Keep Lab 1 gates:

- Gitleaks.
- Unit tests.
- JaCoCo.
- Coverage gate.
- Build.
- SonarQube.
- Snyk.

Add/finish Lab 2 behavior:

- Read deployable service scope from `services.yaml`.
- Build/push Docker Hub image tags.
- Update GitOps overlays, not cluster resources.
- Provide `developer_build`, `teardown_developer`, `deploy_dev`, `release_staging`, `rollback_environment`, `cluster_smoke_check`.

Acceptance:

- Feature branch pushes commit SHA image tag.
- `main` pushes commit SHA, `main`, and `latest`.
- `vX.Y.Z` pushes commit SHA and release tag.
- Staging overlay contains no `latest`.

## M4 - Environment Evidence

Developer:

- Current policy keeps developer dormant.
- Confirm ArgoCD `yas-developer` is `Synced/Healthy`.
- Confirm developer deployments are `0/0`.
- Review or disable the app repo `DEPLOY_TO_DEVELOPER` behavior before treating this as permanent end-to-end policy.

Dev:

- Push/merge `main`.
- Confirm `yas-dev` sync.
- Curl app through `yas.dev.local:30080`.

Staging:

- Push `vX.Y.Z`.
- Confirm `yas-staging` sync.
- Confirm immutable tag in GitOps diff.
- Confirm staging is active beside dev with CPU throttle and `maxSurge: 0`.

Rollback/teardown:

- Run rollback job and capture log.
- Run teardown developer job and capture GitOps prune evidence.

## M5 - Mesh Evidence

Install Istio/Kiali after basic CD works.

Acceptance:

- Namespace label injection enabled.
- Pods READY `2/2`.
- STRICT mTLS evidence.
- AuthorizationPolicy allow and deny curl logs.
- Retry evidence.
- Kiali graph screenshot.

Mesh URL:

```bash
curl -H "Host: yas.mesh.local" "http://${GCP_VM_EXTERNAL_IP}:30090/"
```

## M6 - Final Report Pack

Include:

- GCP VM and firewall evidence.
- Kubernetes node/pod/storage evidence.
- Jenkins CI/CD logs.
- Docker Hub tag screenshots.
- GitOps diffs.
- ArgoCD app screenshots.
- App curl/browser evidence.
- Mesh evidence.
- Production reality check.

## Risks

| Risk | Mitigation |
|---|---|
| Single VM resource pressure | Use 32 GB RAM, low replicas, staged rollout |
| Admin UI public exposure | SSH tunnel or admin-IP firewall allowlist |
| local-path data loss | Document lab-only storage |
| GitOps drift | Jenkins only commits desired state |
| Secret leak | Gitleaks, staged diff check, Jenkins credentials |
