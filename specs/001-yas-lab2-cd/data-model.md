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
- Only one `full-stack` environment may have `default_state=active`.
- `staging` must use `release-only`.

**State transitions**
- `dormant -> active`: triggered by Jenkins job or operator-approved GitOps
  promotion
- `active -> dormant`: triggered by teardown or post-validation demotion

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

**Validation**
- Requests must be lower than limits.
- Defaults must be present for shared charts.
- Budgets must fit the documented single-node target.

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

Represents the minimal service-mesh demo path.

**Fields**
- `namespace`: `mesh-demo`
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
