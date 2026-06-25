# Quickstart: Validate The Remaining Lab 2 Completion Scope

## Prerequisites

- GCP VM `gcp-ci-cd-agent` is reachable by SSH
- `k3s` is running on the VM
- ArgoCD is installed and has access to `emanhthangngot/yas-cd`
- Jenkins controller and inbound agent are connected
- `sudo k3s kubectl` is available on the VM

## 1. Validate Platform Before App Recovery

Run on the GCP VM:

```bash
sudo k3s kubectl get applications -n argocd
sudo k3s kubectl get pods -A
sudo k3s kubectl top nodes
sudo k3s kubectl top pods -A --sort-by=cpu
```

Expected outcome:
- `yas-platform` is `Synced/Healthy`
- node remains reachable by SSH
- operator can identify the current active environment and top CPU consumers

## 2. Validate Single-Node Runtime Governance

Confirm dormant optional environments:

```bash
sudo k3s kubectl get pods -n staging
sudo k3s kubectl get pods -n developer
```

Expected outcome:
- optional environments are empty or intentionally dormant when not under test

Confirm the active environment:

```bash
sudo k3s kubectl get pods -n dev
sudo k3s kubectl top pods -n dev --sort-by=cpu
```

Expected outcome:
- only one full environment is consuming the bulk of app CPU
- the node remains usable while that environment converges

## 3. Validate Developer Preview Flow

From Jenkins or an operator-approved simulation:

1. trigger `developer_build` with one selected service branch
2. wait for the GitOps commit to `overlays/developer`
3. confirm only the developer namespace activates for preview

Runtime checks:

```bash
sudo k3s kubectl get applications -n argocd yas-developer
sudo k3s kubectl get pods -n developer
```

Expected outcome:
- `yas-developer` becomes active only during preview
- `dev` and `staging` remain within the exclusivity policy

## 4. Validate Staging Release Flow

Promote an immutable tag through `release_staging` and check:

```bash
sudo k3s kubectl get applications -n argocd yas-staging
sudo k3s kubectl get pods -n staging
```

Expected outcome:
- staging uses only `vX.Y.Z` tags
- staging can be activated and later returned to dormant state

## 5. Validate Mesh Demo

After `mesh-demo` manifests are applied and healthy:

```bash
sudo k3s kubectl get ns mesh-demo
sudo k3s kubectl get pods -n mesh-demo
sudo k3s kubectl get peerauthentication,destinationrule,virtualservice,authorizationpolicy -n mesh-demo
```

Generate evidence:

```bash
sudo k3s kubectl exec -n mesh-demo <allowed-client-pod> -- curl -sv http://location.mesh-demo:<port>
sudo k3s kubectl exec -n mesh-demo <denied-client-pod> -- curl -sv http://location.mesh-demo:<port>
```

Expected outcome:
- sidecar-enabled pods are ready
- STRICT mTLS is effective
- one authorized path succeeds
- one denied path is blocked
- retry behavior on 5xx is visible through logs or metrics

## 6. Validate External Access

From an external machine with `hosts` entries:

```bash
curl -I -H 'Host: yas.dev.local' http://<gcp-external-ip>:30080/
```

Expected outcome:
- external access works through ingress `NodePort`
- application services remain internal `ClusterIP` backends

## 7. Capture Deliverable Evidence

Collect and store:

- `kubectl get applications -n argocd`
- `kubectl get pods -A`
- `kubectl top nodes`
- Jenkins logs for deployment and teardown jobs
- Git history for GitOps commits
- mesh curl output and Kiali screenshot
