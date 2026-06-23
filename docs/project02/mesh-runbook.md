# Service Mesh Runbook

Install Istio and Kiali only after the basic CD path is stable on the GCP VM single-node cluster.

## Tool Gate

Run the shared cluster tool gate before installing or validating mesh behavior:

```bash
yq --version
helm version --short
kustomize version
kubectl version --client
argocd version --client
istioctl version --remote=false
```

Gate: do not continue until all six commands return a version.

## Requirements

- Namespace selected for mesh demo has sidecar injection enabled.
- Pods must show READY `2/2`.
- mTLS mode must be STRICT for the demo namespace.
- Istio IngressGateway uses NodePorts `30090/30490` for mesh demo traffic.
- Kiali UI is admin-only through SSH tunnel or GCP firewall allowlist.

## Access

Use a hosts file entry or Host header:

```text
<GCP_VM_EXTERNAL_IP> yas.mesh.local
```

Example:

```bash
curl -H "Host: yas.mesh.local" "http://${GCP_VM_EXTERNAL_IP}:30090/"
```

## Namespace Decision

Use `dev` first for the mesh demo because it represents the shared integration environment and should already be reconciled by ArgoCD. Use `developer` only as a fallback when `dev` is unavailable, unstable, or needed by another worker.

```bash
MESH_NAMESPACE=dev
kubectl get namespace "${MESH_NAMESPACE}" || MESH_NAMESPACE=developer
kubectl get namespace "${MESH_NAMESPACE}"
argocd app get "yas-${MESH_NAMESPACE}"
argocd app wait "yas-${MESH_NAMESPACE}" --health --sync --timeout 600
```

Gate: continue only when the selected namespace exists and the matching ArgoCD app is `Synced` and `Healthy`.

## Sidecar Injection

Enable sidecar injection through namespace labels, then restart deployments so pods are recreated with Envoy sidecars.

```bash
kubectl label namespace "${MESH_NAMESPACE}" istio-injection=enabled --overwrite
kubectl get namespace "${MESH_NAMESPACE}" --show-labels
kubectl rollout restart deployment -n "${MESH_NAMESPACE}"
kubectl rollout status deployment -n "${MESH_NAMESPACE}" --timeout=600s
kubectl get pods -n "${MESH_NAMESPACE}"
```

Gate: application pods in the selected namespace must show READY `2/2`. If a pod remains `1/1`, confirm it was restarted after the namespace label was applied.

## Authorization Policy

Policies must show both allow and deny evidence:

- Allow ingress gateway to call BFF/API.
- Allow expected service-to-service flows such as `order -> tax`, `order -> customer`, and `order -> payment`.
- Deny curl from a pod that is not authorized.

## Retry Evidence

Target route: `tax`.

- Configure retry attempts: `3`.
- Configure per-try timeout.
- Use 50% fault abort for lab evidence.
- Do not use 100% fault abort as the only retry proof.

Verify the route and retry configuration:

```bash
kubectl get virtualservice,destinationrule -n "${MESH_NAMESPACE}"
kubectl describe virtualservice -n "${MESH_NAMESPACE}" tax
kubectl logs -n "${MESH_NAMESPACE}" deploy/tax -c istio-proxy --tail=100
```

## Evidence

- Tool version gate output for `yq`, `helm`, `kustomize`, `kubectl`, `argocd`, and `istioctl`
- Mesh namespace decision showing `dev` first and `developer` fallback if used
- Namespace label command and `kubectl get namespace --show-labels`
- Deployment restart and rollout status output
- `kubectl get pods -n "${MESH_NAMESPACE}"` showing READY `2/2`
- `istioctl authn tls-check`
- curl allow logs
- curl deny logs
- retry curl logs
- Kiali topology screenshot
- GCP firewall or SSH tunnel evidence for Kiali access

## Production Reality Notes

- Lab sidecar injection by namespace label is acceptable for evidence. Production should use reviewed namespace ownership, revisioned Istio control planes, and controlled rollout windows.
- Lab Kiali and NodePort access are convenience paths. Production should protect observability endpoints with SSO, network policy, TLS, and least-privilege RBAC.
