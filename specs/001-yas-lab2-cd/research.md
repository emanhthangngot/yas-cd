# Research: Single-Node Runtime Governance And Mesh Completion

## Decision 1: Use a dev-plus-staging baseline and keep developer dormant

**Decision**: Treat `dev` and `staging` as the active final-demo baseline. Keep
`developer` dormant by default and do not run a third full environment on the
single-node VM.

**Rationale**: The current single-node `k3s` runtime cannot safely boot three
full Java-heavy environments at once. The live cluster evidence showed CPU
saturation and unstable SSH during concurrent environment startup. The final
demo still benefits from `dev` and `staging` running side by side, so staging
is kept active but resource-throttled and rollout-capped. `developer` remains
dormant to avoid the third full-stack workload.

**Alternatives considered**:
- Keep all three environments always-on: rejected because the node already hits
  sustained `99%` CPU and falls over after reboot or sync churn.
- Run only `dev` and keep `staging` dormant: rejected because the user wants to
  observe `dev` and `staging` in parallel for the final demo.
- Remove `developer` entirely: rejected because the overlay and ArgoCD app are
  still useful for evidence and rollback policy, but desired replicas stay `0`.

## Decision 2: Add resource defaults before any autoscaling

**Decision**: Add conservative default CPU and memory requests and limits to
the shared backend and UI charts, and back them with namespace guardrails such
as `LimitRange`.

**Rationale**: The current `resources: {}` default in the generic charts gives
Kubernetes no scheduling budget and lets many JVMs compete unchecked on the
same node. Stabilizing requests and limits is a prerequisite for reliable
rollout, fair scheduling, and future scaling decisions.

**Alternatives considered**:
- Enable HPA first: rejected because HPA without meaningful requests creates
  poor metrics and can amplify node pressure on a single node.
- Tune each service independently from day one: rejected because the repo
  already relies on a shared chart and needs a safe baseline first.

## Decision 3: Use Sealed Secrets for committed desired state

**Decision**: Replace plain committed secret payloads with Bitnami Sealed
Secrets for GitOps-managed secret material, while still allowing out-of-band
bootstrap for cluster-only admin credentials when needed.

**Rationale**: The current committed `stringData` placeholders are tolerable as
obvious fake values, but they reinforce a bad pattern and do not move the repo
toward safe GitOps practice. Sealed Secrets work well in a single-cluster lab
without requiring an external cloud secret manager.

**Alternatives considered**:
- Keep plain-text placeholders forever: rejected because it normalizes unsafe
  behavior.
- External Secrets Operator with cloud secret manager: rejected for now because
  it adds cloud integration complexity that is not required to finish the lab.

## Decision 4: Use a dedicated minimal `mesh-demo` namespace

**Status update 2026-07-04**: superseded as the final acceptance path by the
expanded sidecar-readiness requirement for `dev` and `staging`. `mesh-demo`
may still be used as supporting evidence or a focused policy test bed, but it
is not sufficient for final mesh acceptance.

**Decision**: Deliver Service Mesh requirements in a dedicated namespace
`mesh-demo` instead of enabling Istio sidecars across `dev`, `staging`, and
`developer`.

**Rationale**: Full-mesh enablement across all environments would add sidecars
to too many pods and worsen the single-node resource problem. A minimal
namespace keeps the assignment evidence achievable while respecting the lab
hardware boundary.

**Alternatives considered**:
- Enable sidecar injection in all app namespaces: rejected because it adds too
  much CPU and memory pressure.
- Skip mesh and accept the lost points: rejected because the user explicitly
  wants to finish the missing deliverables.

## Decision 5: Use `tax -> location` as the default mesh scenario

**Decision**: The default mesh evidence path will be the direct service
dependency `tax -> location`.

**Rationale**: This pair gives real YAS service-to-service traffic with a much
smaller runtime footprint than flows such as `order`, which depend on many more
services. It is enough to demonstrate retry, mTLS, allow, deny, and Kiali
topology.

**Alternatives considered**:
- `order`-centric flow: rejected because it pulls in too many dependencies.
- `product -> media`: rejected because it is heavier than `tax -> location`
  while not adding stronger proof for the assignment.

## Decision 6: Keep NodePort at the ingress layer, not per app service

**Decision**: Keep application services as `ClusterIP` and satisfy the
assignment's external access requirement through ingress exposed via fixed
NodePorts.

**Rationale**: The assignment asks for developer access by `domain:port`, but
the repo already implements that more cleanly through ingress plus `hosts`
entries. Turning every backend or BFF service into a direct `NodePort` would
increase public exposure and operational sprawl without adding value.

**Alternatives considered**:
- Patch app services to direct `NodePort`: rejected because ingress already
  satisfies the requirement with less exposure.

## Decision 7: Align Jenkins jobs with runtime exclusivity

**Decision**: Define Jenkins deployment jobs so they activate only the specific
environment needed, respect dormant-state rules for the others, and always
perform changes through GitOps commits.

**Rationale**: The current repo already enforces GitOps for app rollout. The
remaining gap is operational discipline: jobs must not wake multiple
environments simultaneously on this node.

**Alternatives considered**:
- Leave runtime exclusivity as a manual operator responsibility: rejected
  because the assignment requires repeatable CD behavior, not tribal knowledge.
