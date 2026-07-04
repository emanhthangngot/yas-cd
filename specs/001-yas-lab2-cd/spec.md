# Spec: YAS Lab 2 CD Completion on Single-Node K3s

## Objective

Complete the remaining Lab 2 deliverables on the existing two-repository
GitOps architecture without overloading the single Google Cloud `k3s` node.
The completion scope now has three priorities:

1. Stabilize runtime on the single-node cluster so at least one full YAS
   environment becomes `Synced/Healthy` and survives reboot without startup
   storms.
2. Deliver the missing advanced Service Mesh evidence for the running
   `dev` and `staging` workloads, with every required application pod showing
   both the workload container and the Istio sidecar as `Ready`.
3. Close the remaining Jenkins operational jobs and evidence paths around
   `developer`, `dev`, `staging`, rollback, and smoke-check flows.

## Problem Statement

The current repository structure is correct for GitOps, but the runtime
behavior is not yet compatible with the actual lab boundary:

- The cluster is a single `k3s` node that also runs the Jenkins inbound agent.
- `yas-platform` is healthy, but `yas-dev`, `yas-staging`, and
  `yas-developer` are not all healthy at the same time.
- After reboot or concurrent sync, the node experiences CPU saturation from
  many Spring Boot services starting in parallel.
- The project still lacks a full sidecar-readiness plan for the application
  workloads that are already running healthy in `dev` and `staging`.
- Generic charts still need stronger runtime guardrails, especially resource
  governance and safer secret handling.

## Users

- Developer: pushes feature branches to `tzin1401/yas`, runs
  `developer_build`, validates branch-specific behavior through the lab entry
  point, and tears the environment down after testing.
- Release owner: promotes `main` to `dev`, pushes immutable release tags to
  `staging`, and performs rollback when needed.
- Operator: maintains the GCP VM, validates K3s/ArgoCD health, captures
  evidence, and runs the service mesh demo.
- GitOps maintainer: reviews desired-state diffs in `emanhthangngot/yas-cd`,
  including overlays, runtime policies, secret manifests, and mesh
  configuration.

## Scope

### In Scope

- Runtime stabilization for single-node `k3s`
- Environment activation policy for `dev`, `staging`, and `developer`
- GitOps-safe secret hardening for committed desired state
- Shared backend and UI chart resource governance
- Service Mesh implementation and evidence for required `dev` and `staging`
  application pods
- Platform infrastructure readiness needed before `dev` and `staging`
  application pods can remain healthy
- Jenkins job contracts for deployment, teardown, promotion, rollback, and
  smoke-check operations
- Required documentation and validation artifacts under `specs/001-yas-lab2-cd/`

### Out of Scope

- Replacing `k3s` with a multi-node or managed Kubernetes cluster
- Replacing Jenkins with another CI/CD orchestrator
- Implementing full production-grade HA or managed data services
- Public exposure of admin UIs such as Jenkins, ArgoCD, Kiali, or the
  Kubernetes API

## Priority Workstreams

### Workstream 1: Single-Node Runtime Governance

The cluster must stop treating `dev`, `staging`, and `developer` as three
always-on full-stack environments. The GitOps desired state now encodes a
single-node-safe policy where:

- `yas-platform` remains always-on.
- `dev` and `staging` run in parallel for the final demo baseline.
- `developer` reconciles to a dormant state rather than attempting a third
  full rollout after reboot or sync.
- `staging` uses lower CPU limits and `maxSurge: 0` rollouts to avoid startup
  spikes while running beside `dev`.
- Shared charts enforce resource requests and limits suitable for a Java-heavy
  workload on `e2-standard-8`.

### Workstream 2: Platform Infrastructure Readiness For Dev And Staging

`dev` and `staging` application pods depend on shared platform services that
must exist before the application overlays can be treated as healthy. The
GitOps platform layer must define, sync, and verify these shared dependencies:

- PostgreSQL in namespace `postgres`, including the YAS application databases
  required by `cart`, `customer`, `inventory`, `keycloak`, `location`,
  `media`, `order`, `payment`, `payment-paypal`, `product`, `search`, `tax`,
  and the dormant or optional services kept in the catalog.
- Redis in namespace `redis`, reachable by BFF and cache-dependent services.
- Kafka in namespace `kafka`, reachable through the broker service name used
  by event-driven services such as `order` and `search`.
- Elasticsearch in namespace `elasticsearch`, reachable by `product` and
  `search`.
- Keycloak in namespace `keycloak`, backed by PostgreSQL and reachable through
  the `identity` service alias from `dev` and `staging`.
- K3s local-path persistent storage for stateful platform data.
- Traefik NodePort ingress for application entrypoints while backend services
  stay internal.

The infrastructure evidence must prove that these services are `Ready`, have
stable in-cluster DNS names, own their required PVCs where applicable, and are
available before declaring `dev` or `staging` application health complete.

### Workstream 3: Service Mesh Completion

The advanced requirement must now cover the required application pods in
`dev` and `staging`, not only a separate `mesh-demo` slice. The design must
enable Istio sidecar injection for the relevant namespaces or pod templates in
a GitOps-managed way and prove:

- sidecar injection
- pod readiness as `2/2` for workload container plus `istio-proxy`
- STRICT mTLS
- retry on HTTP 5xx
- authorization allow and deny behavior
- Kiali topology evidence

The `mesh-demo` overlay may remain as a low-footprint fallback or focused
policy test bed, but final acceptance for this workstream requires sidecar
readiness evidence from `dev` and `staging` pods that are part of the required
CQ service scope.

### Workstream 4: Jenkins Operational Flow Completion

The remaining Jenkins jobs must align with the runtime policy above instead of
fighting ArgoCD or overloading the cluster. Jobs must use GitOps commits only,
respect environment exclusivity, and produce auditable evidence.

## Functional Requirements

- FR-001: ArgoCD must continue to sync from
  `git@github.com:emanhthangngot/yas-cd.git`, branch `main`.
- FR-002: The app repo `tzin1401/yas` must remain the source for source code,
  CI gates, Docker build, and image push.
- FR-003: Jenkins must update this repo's desired state rather than mutating
  ArgoCD-managed namespaces directly.
- FR-004: `services.yaml` must remain the service catalog snapshot used by CD
  validation and GitOps automation.
- FR-005: `dev`, `staging`, and `developer` overlays must remain renderable
  independently from this repo.
- FR-006: Staging must continue to accept only immutable tags in the form
  `vX.Y.Z`.
- FR-007: Jenkins must continue to update image tags through
  `scripts/update-image-tag.sh` and validate with
  `scripts/validate-gitops.sh`.
- FR-008: `developer_build` must deploy branch-specific images for selected
  services while defaulting the rest to `main` or the current default policy.
- FR-009: `teardown_developer` must return the developer environment to a
  dormant GitOps state and allow ArgoCD to prune or reconcile accordingly.
- FR-010: Mesh evidence must show mTLS, authorization allow/deny, retry, and
  Kiali topology.
- FR-011: The cluster runbook must continue to target a GCP VM based
  single-node `k3s` cluster without Tailscale.
- FR-012: Admin interfaces must remain restricted by SSH tunnel or firewall
  allowlisting.
- FR-013: The GitOps desired state must encode an environment activation
  policy where `dev` and `staging` are active together and `developer` is
  dormant on the single node.
- FR-014: `dev` must stay active after bootstrap or reboot.
- FR-015: `staging` must stay active beside `dev`, but with conservative CPU
  limits and no rollout surge.
- FR-016: Shared backend and UI charts must define conservative resource
  requests and limits so Kubernetes can schedule predictably and prevent
  uncontrolled JVM growth.
- FR-017: Namespace-level guardrails such as `LimitRange` and, where helpful,
  `ResourceQuota` must be available for application namespaces to enforce the
  chart defaults.
- FR-018: The project must stop storing long-lived app secrets directly as
  plain-text desired state. GitOps-managed secrets must be represented in a
  hardened form suitable for commit, with Bitnami Sealed Secrets as the lab
  default.
- FR-019: The cluster must include a dedicated mesh namespace named
  `mesh-demo` that deploys only the minimal YAS service slice required for the
  Service Mesh deliverables.
- FR-020: The default mesh slice must use the direct dependency chain
  `tax -> location`, because it provides real service-to-service YAS traffic
  with a smaller footprint than broader flows such as `order`.
- FR-021: `dev` and `staging` must enable Istio sidecar injection for required
  application pods through GitOps-managed namespace labels or pod-template
  annotations.
- FR-022: Mesh manifests must include `PeerAuthentication`,
  `DestinationRule`, `VirtualService`, and `AuthorizationPolicy` resources
  needed to prove the assignment scenarios.
- FR-023: `deploy_dev` must promote `main` images into the active `dev`
  environment without waking `developer`.
- FR-024: `release_staging` must promote `staging` only for immutable release
  tags and must keep `developer` dormant.
- FR-025: `rollback_environment` must revert an environment to a previous
  overlay state or image tag while preserving the active/dormant policy.
- FR-026: `cluster_smoke_check` must report the active environment, ArgoCD app
  health, node pressure, and externally reachable demo endpoints.
- FR-027: Developer external access must continue to use the lab entrypoint
  model of `hosts` file plus ingress `NodePort`; application services should
  remain internal `ClusterIP` services behind ingress unless a specific mesh
  or debug case requires otherwise.
- FR-028: `yas-platform` must provide the shared runtime infrastructure needed
  by the active `dev` and `staging` overlays: PostgreSQL, Redis, Kafka,
  Elasticsearch, Keycloak, identity aliases, ingress NodePorts, and persistent
  storage for stateful platform services.
- FR-029: PostgreSQL must initialize or retain databases for all deployed YAS
  services required by the CQ scope and their runtime dependencies.
- FR-030: Kafka, PostgreSQL, Redis, Elasticsearch, and Keycloak must expose
  stable internal service names matching the application configuration used by
  rendered `dev` and `staging` workloads.
- FR-031: Platform infrastructure readiness must be verified before marking
  `dev` or `staging` application readiness complete.
- FR-032: For each required `dev` and `staging` application pod that is not a
  dormant run-once seed pod, readiness evidence must show `READY 2/2` after
  sidecar injection is enabled.
- FR-033: If a pod cannot safely run with an Istio sidecar, the exception must
  be documented with the service name, reason, compensating evidence, and an
  explicit approval note. Silent `sidecar.istio.io/inject: "false"` is not
  acceptable for required CQ services.
- FR-034: Service-mesh rollout must preserve the current single-node baseline:
  `dev` and `staging` remain active, `developer` remains dormant, and staging
  keeps its CPU throttle and `maxSurge: 0` policy.

## Non-Functional Requirements

- NFR-001: No real secrets, kubeconfigs, tokens, or private keys are committed.
- NFR-002: Base manifests must not hardcode environment-specific namespaces.
- NFR-003: NodePort access, hosts-file DNS, single-node local-path storage,
  and demo credentials must remain documented as lab-only shortcuts.
- NFR-004: GitOps commits in this repo must not trigger full application CI in
  `tzin1401/yas`.
- NFR-005: The solution must not rely on Tailscale.
- NFR-006: When `yas-platform`, sidecar-enabled `dev`, and sidecar-enabled
  `staging` are running, node CPU must settle below sustained saturation after
  startup and remain usable for SSH and `kubectl` operations.
- NFR-007: Memory pressure must remain below the point where pods are commonly
  OOM-killed during normal validation workflows.
- NFR-008: Mesh evidence must be reproducible using committed manifests and
  documented commands, not hand-configured cluster state.
- NFR-009: Sidecar rollout must include a resource-budget review because
  adding `istio-proxy` increases CPU and memory pressure for every injected
  pod.

## Success Criteria

- `yas-platform` is `Synced/Healthy`.
- `dev` and `staging` reach `Synced/Healthy` together while the node remains
  usable.
- `developer` remains dormant unless the team explicitly re-enables the legacy
  preview flow.
- Shared charts enforce default CPU and memory requests and limits.
- Committed secrets are represented through a hardened GitOps mechanism rather
  than plain-text desired state.
- Platform infrastructure pods for PostgreSQL, Redis, Kafka, Elasticsearch,
  and Keycloak are running and ready before `dev` and `staging` app health is
  accepted.
- Required `dev` and `staging` application pods show `2/2 Ready` after Istio
  injection, with one ready workload container and one ready `istio-proxy`
  sidecar.
- Mesh evidence covers `dev` and `staging` workloads with STRICT mTLS, retry,
  allow, deny, and Kiali topology. `mesh-demo` may provide supporting evidence
  but is no longer sufficient by itself.
- Jenkins jobs `developer_build`, `teardown_developer`, `deploy_dev`,
  `release_staging`, `rollback_environment`, and `cluster_smoke_check` are
  documented with clear inputs, outputs, and GitOps side effects.
- The validation workflow survives node reboot without triggering an
  uncontrolled three-environment startup storm.

## Boundaries

- Always: follow `AGENTS.md`, render manifests before GitOps commits, restrict
  admin access, and keep secrets out of Git.
- Ask first: changing the Java or Spring version decision, replacing Docker
  Hub, exposing admin UIs publicly, replacing `k3s`, or moving secrets into a
  managed external store that adds cloud-provider dependencies.
- Never: commit real secrets, deploy directly into ArgoCD-managed namespaces,
  treat all three application environments as always-on full-stack namespaces
  on this single node, or satisfy the NodePort requirement by exposing every
  individual backend service publicly.
