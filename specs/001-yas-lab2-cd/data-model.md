# Data Model: Single-Node Runtime Governance And Mesh Completion

## EnvironmentProfile

Represents one GitOps-managed application environment.

**Fields**
- `name`: `dev` | `staging` | `developer` | `mesh-demo`
- `kind`: `full-stack` | `mesh-slice`
- `default_state`: `active` | `dormant`
- `allowed_image_policy`: `main-family` | `release-only` | `branch-preview`
- `entrypoint_mode`: `ingress-nodeport` | `internal-curl-only`
- `argocd_app`: ArgoCD application name

**Validation**
- `dev`, `staging`, and `developer` must keep distinct overlay paths.
- `dev` and `staging` may both have `default_state=active` for the final demo
  baseline; `developer` must remain dormant unless explicitly re-enabled.
- `staging` must use `release-only`.

**State transitions**
- `dormant -> active`: triggered by Jenkins job or operator-approved GitOps
  promotion
- `active -> dormant`: triggered by teardown or post-validation demotion

## PlatformInfrastructureProfile

Represents the shared infrastructure that must be running before `dev` and
`staging` application health is accepted.

**Fields**
- `name`: `yas-platform`
- `argocd_app`: `yas-platform`
- `required_namespaces`: `postgres`, `redis`, `kafka`, `elasticsearch`,
  `keycloak`
- `required_services`: stable DNS endpoints consumed by app pods
- `stateful_components`: PostgreSQL, Kafka, Elasticsearch
- `stateless_components`: Redis, Keycloak, identity aliases, ingress NodePort
- `storage_class`: K3s `local-path`
- `dependency_consumers`: application services from `dev` and `staging`

**Required service endpoints**
- `postgresql.postgres.svc.cluster.local:5432`
- `redis-master.redis.svc.cluster.local:6379`
- `kafka-cluster-kafka-brokers.kafka.svc.cluster.local:9092`
- `elasticsearch-es-http.elasticsearch.svc.cluster.local:9200`
- `identity.keycloak.svc.cluster.local:80`
- `identity.dev.svc.cluster.local:80`
- `identity.staging.svc.cluster.local:80`

**Validation**
- `yas-platform` must be `Synced/Healthy` before accepting `yas-dev` or
  `yas-staging` health.
- Each required namespace must exist.
- Each required service must resolve inside the cluster and select or point to
  the intended backend.
- PostgreSQL, Kafka, and Elasticsearch must have bound PVCs.
- PostgreSQL must contain databases for all required CQ services and runtime
  dependencies.
- Redis, Kafka, Elasticsearch, PostgreSQL, and Keycloak pods must be ready.

## RuntimeBudget

Represents the cluster budget assumptions for the single-node lab.

**Fields**
- `node_class`: `gcp-ci-cd-agent`
- `cpu_budget_millicores`
- `memory_budget_mib`
- `backend_default_request_cpu`
- `backend_default_request_memory`
- `backend_default_limit_cpu`
- `backend_default_limit_memory`
- `ui_default_request_cpu`
- `ui_default_request_memory`
- `ui_default_limit_cpu`
- `ui_default_limit_memory`
- `namespace_guardrails`: `LimitRange`, optional `ResourceQuota`
- `sidecar_default_request_cpu`
- `sidecar_default_request_memory`
- `sidecar_default_limit_cpu`
- `sidecar_default_limit_memory`

**Validation**
- Requests must be lower than limits.
- Defaults must be present for shared charts.
- Budgets must fit the documented single-node target.
- Budgets must include the additional `istio-proxy` container added to every
  injected `dev` and `staging` pod.

## GitOpsOverlayState

Represents the desired state encoded in `base/`, `overlays/`, `platform/`, and
`argocd/`.

**Fields**
- `environment`: reference to `EnvironmentProfile`
- `image_tags`: per-service tag selection
- `replica_policy`: active or dormant replica behavior
- `ingress_host`
- `nodeport_entrypoint`
- `sync_order`
- `secret_source`: `sealed-secret` | `manual-cluster-secret`

**Validation**
- Overlays must render independently.
- `staging` tags must pass immutable tag validation.
- `replica_policy` must reflect the active/dormant environment rule.

## JenkinsJobContract

Represents an operational Jenkins interface.

**Fields**
- `job_name`
- `purpose`
- `parameters`
- `target_environment`
- `allowed_source_refs`
- `gitops_side_effects`
- `preconditions`
- `postconditions`

**Validation**
- Jobs must not mutate ArgoCD-managed namespaces directly.
- Jobs that activate an environment must specify what happens to other optional
  environments.

## MeshScenario

Represents service-mesh behavior for required application workloads.

**Fields**
- `namespaces`: `dev`, `staging`, optional `mesh-demo`
- `source_service`: default `tax`
- `target_service`: default `location`
- `traffic_type`: service-to-service HTTP
- `mtls_mode`: `STRICT`
- `retry_policy`
- `authorization_allow_rule`
- `authorization_deny_rule`
- `kiali_expectation`
- `evidence_commands`

**Validation**
- Must use real YAS services.
- Must be small enough to fit the runtime budget.
- Must produce both allow and deny evidence.
- Must include `dev` and `staging` evidence; `mesh-demo` evidence is
  supplementary only.

## SidecarReadinessPolicy

Represents the required Istio sidecar state for application pods.

**Fields**
- `target_namespaces`: `dev`, `staging`
- `injection_mode`: namespace label or pod-template annotation
- `included_workloads`: required CQ services and runtime dependencies rendered
  with replicas greater than zero
- `excluded_workloads`: dormant run-once pods or explicitly approved
  exceptions
- `expected_ready_count`: `2/2`
- `required_containers`: workload container and `istio-proxy`
- `rollout_strategy`: restart or ArgoCD sync after injection policy changes
- `resource_budget`: Istio proxy request and limit assumptions
- `evidence_commands`: pod readiness, container names, namespace labels,
  mTLS policy, and Kiali topology

**Validation**
- `dev` and `staging` namespaces must show Istio injection enabled or each
  included pod template must carry an explicit injection annotation.
- Every included running application pod must report `READY 2/2`.
- `kubectl get pod -o jsonpath` evidence must show an `istio-proxy` container.
- Exclusions must be listed with reason and approval evidence.
- Rollout must preserve `developer` as dormant.

## EvidenceArtifact

Represents a deliverable needed for grading or operational signoff.

**Fields**
- `name`
- `type`: `cli-output` | `screenshot` | `curl-log` | `git-log`
- `source_command`
- `success_signal`
- `retention_location`

**Validation**
- Must be reproducible from documented steps.
- Must not expose secrets.
