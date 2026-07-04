# Implementation Plan: Single-Node Runtime Governance And Mesh Completion

**Branch**: `main` | **Date**: 2026-06-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-yas-lab2-cd/spec.md`

## Summary

Complete the remaining Lab 2 deliverables by converting the current GitOps
design into a single-node-safe operating model. The implementation will keep
`yas-platform` always-on, run `dev` and `staging` in parallel, keep
`developer` dormant, harden generic charts with resources and safer secret
handling, and enable Istio sidecars for the required running application pods
in `dev` and `staging` so readiness evidence shows workload plus sidecar as
`2/2 Ready`. Jenkins operational jobs will be aligned to that runtime policy
so cluster validation does not trigger a three-environment startup storm.

## Technical Context

**Language/Version**: YAML/Kustomize/Helm for GitOps manifests; Bash for
automation; Java 21 / Spring Boot 3.x workloads already defined by YAS

**Primary Dependencies**: ArgoCD, K3s, Helm via Kustomize, Docker Hub, Jenkins,
PostgreSQL, Redis, Kafka, Elasticsearch, Keycloak, Istio, Kiali, Sealed
Secrets

**Storage**: Kubernetes manifests in Git; K3s bundled local-path PVCs for the
lab runtime; sealed secret ciphertext stored in Git; runtime secrets materialize
as Kubernetes Secrets

**Testing**: `scripts/validate-gitops.sh`,
`scripts/validate-staging-immutable.sh`, `kubectl kustomize ... --enable-helm`,
Jenkins job runs, ArgoCD health checks, `sudo k3s kubectl` runtime validation,
curl-based mesh evidence

**Target Platform**: Ubuntu 24.04 GCP VM `gcp-ci-cd-agent`, `e2-standard-8`
class, single-node `k3s`, Jenkins inbound agent on the same host

**Project Type**: GitOps repository and operational platform plan for a
single-node lab deployment

**Performance Goals**:
- keep SSH and `kubectl` usable after reboot or app sync
- avoid sustained `99%` CPU from three concurrent full-stack environment boots
- keep one full active environment plus platform healthy on the single node

**Constraints**:
- must not bypass ArgoCD for `dev`, `staging`, `developer`
- must not commit real secrets
- must retain Docker Hub and existing app-repo Lab 1 CI gates
- must fit the current single-node lab budget

**Scale/Scope**:
- approximately 16 required application deployments per active CQ environment
- two active application environments plus one dormant developer environment
- one always-on platform stack for shared dependencies

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Principle I, GitOps source of truth: pass. The plan keeps Jenkins limited to
  Git commits in this repo and keeps ArgoCD as the deployment actor.
- Principle II, two-repository boundary: pass. App repo remains CI/build
  source; this repo remains desired state and operational documentation source.
- Principle III, service catalog first: pass. The plan continues to use
  `services.yaml` and shared charts instead of hardcoded service lists.
- Principle IV, existing CI gates stay enforced: pass. No change weakens the
  Lab 1 CI stages in the app repo.
- Principle V, immutable images for CD: pass. `staging` stays release-tag-only;
  `developer` and `dev` continue to use mutable lab-friendly tags only where
  already permitted.
- Principle VI, GCP single-node lab boundary explicit: pass. The design leans
  into the single-node constraint instead of pretending all three full
  environments can be always-on.

Post-design re-check result: still pass. The new artifacts add stronger
guardrails without violating any constitution rule.

## Project Structure

### Documentation (this feature)

```text
specs/001-yas-lab2-cd/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── jenkins-jobs.yaml
│   ├── mesh-demo.yaml
│   └── runtime-governance.yaml
└── tasks.md
```

### Source Code (repository root)

```text
base/
overlays/
  dev/
  staging/
  developer/
platform/
  base/
argocd/
  apps/
charts/
scripts/
docs/project02/
.specify/
.agents/
AGENTS.md
```

**Structure Decision**: Keep the existing GitOps repository structure. Add the
remaining design detail through `specs/001-yas-lab2-cd/` artifacts instead of
creating a second feature tree. Runtime governance changes belong in
`base/`, `overlays/`, `platform/`, and `argocd/`; operator guidance belongs in
`docs/project02/`.

## Phase 0 Research Summary

Research conclusions are documented in [research.md](./research.md). The
important decisions are:

- Use an `active + dormant` environment model for the single node.
- Keep `yas-platform` always-on and keep `dev` plus `staging` active for the
  final demo baseline.
- Treat PostgreSQL, Redis, Kafka, Elasticsearch, Keycloak, identity aliases,
  ingress NodePorts, and local-path PVCs as prerequisite infrastructure before
  accepting `dev` or `staging` application health.
- Enable Istio sidecars for required `dev` and `staging` application pods and
  collect `2/2 Ready` evidence.
- Use `tax -> location` as the default mesh evidence path.
- Harden secrets with Sealed Secrets for committed desired state.
- Add resource defaults before considering any autoscaling.

## Phase 1 Design Summary

- [data-model.md](./data-model.md) defines the operational entities:
  environment profiles, runtime budgets, mesh scenarios, Jenkins job contracts,
  and evidence artifacts.
- `contracts/` captures the explicit interfaces for Jenkins jobs, runtime
  governance, platform infrastructure readiness, and Istio sidecar readiness.
- [quickstart.md](./quickstart.md) defines the operator validation flow for
  stabilizing the node, validating platform infrastructure, validating `dev`
  and `staging`, and collecting mesh sidecar evidence.

## Complexity Tracking

No constitution violation needs justification. The design deliberately reduces
operational complexity by shrinking runtime scope instead of layering on more
always-on workloads.
