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
sudo k3s kubectl get pods -n postgres
sudo k3s kubectl get pods -n redis
sudo k3s kubectl get pods -n kafka
sudo k3s kubectl get pods -n elasticsearch
sudo k3s kubectl get pods -n keycloak
sudo k3s kubectl get svc -n postgres
sudo k3s kubectl get svc -n redis
sudo k3s kubectl get svc -n kafka
sudo k3s kubectl get svc -n elasticsearch
sudo k3s kubectl get svc -n keycloak
sudo k3s kubectl get pvc -n postgres
sudo k3s kubectl get pvc -n kafka
sudo k3s kubectl get pvc -n elasticsearch
sudo k3s kubectl top nodes
sudo k3s kubectl top pods -A --sort-by=cpu
```

Expected outcome:
- `yas-platform` is `Synced/Healthy`
- PostgreSQL, Redis, Kafka, Elasticsearch, and Keycloak pods are ready
- PostgreSQL, Kafka, and Elasticsearch PVCs are `Bound`
- required internal service endpoints exist for app pods
- node remains reachable by SSH
- operator can identify the current active environment and top CPU consumers

Confirm required PostgreSQL databases exist:

```bash
sudo k3s kubectl exec -n postgres statefulset/postgresql -- \
  psql -U lab-postgres-user -d postgres -c '\l'
```

Expected outcome:
- databases exist for CQ services and runtime dependencies, including
  `cart`, `customer`, `inventory`, `keycloak`, `location`, `media`, `order`,
  `payment`, `payment-paypal`, `product`, `search`, and `tax`

## 2. Validate Single-Node Runtime Governance

Confirm the current baseline runtime:

```bash
sudo k3s kubectl get pods -n dev
sudo k3s kubectl get pods -n staging
sudo k3s kubectl get pods -n developer
```

Expected outcome:
- `dev` is active
- `staging` is active
- `developer` is dormant

Confirm the node is still usable while `dev` and `staging` run together:

```bash
sudo k3s kubectl top nodes
sudo k3s kubectl top pods -A --sort-by=cpu | head -30
```

Expected outcome:
- staging services are CPU-capped
- staging rollouts do not surge extra pods
- Jenkins jobs are accounted for separately from Kubernetes workload pressure

## 3. Validate Developer Policy

Developer preview is currently disabled at the CD policy level.

Run locally in the CD repo:

```bash
scripts/prepare-developer-preview.sh tax=9f2c4a1
```

Expected outcome:
- the script exits with a policy message
- `developer` remains dormant

Runtime check:

```bash
sudo k3s kubectl get applications -n argocd yas-developer
sudo k3s kubectl get pods -n developer
```

Expected outcome:
- `yas-developer` is synced to the dormant desired state
- all developer deployments are `0/0`

Important app-repo check:
- app repo `main` still has `DEPLOY_TO_DEVELOPER`
- merge or revise the app-side Jenkinsfile before relying on this policy end-to-end

## 4. Validate Staging Release Flow

Promote an immutable tag through a Jenkins tag build or local GitOps simulation:

```bash
scripts/promote-staging-release.sh v1.2.3
scripts/validate-gitops.sh
scripts/validate-staging-immutable.sh
```

Then check the cluster:

```bash
sudo k3s kubectl get applications -n argocd yas-staging
sudo k3s kubectl get pods -n staging
```

Expected outcome:
- staging uses only `vX.Y.Z` tags
- staging remains active beside dev
- developer remains dormant
- staging rollouts use `maxSurge: 0` and `maxUnavailable: 1`

## 5. Validate Istio Sidecars For Dev And Staging

Check injection policy:

```bash
sudo k3s kubectl get namespace dev staging --show-labels
```

Expected outcome:
- `dev` and `staging` show `istio-injection=enabled`, or every included
  workload template has an explicit sidecar injection annotation

Restart or sync affected workloads after enabling injection, then verify pod
readiness:

```bash
sudo k3s kubectl get pods -n dev
sudo k3s kubectl get pods -n staging
```

Expected outcome:
- every required running application pod in `dev` shows `READY 2/2`
- every required running application pod in `staging` shows `READY 2/2`
- dormant run-once pods such as `sampledata` may remain `0/0`

Confirm representative pods contain both containers:

```bash
sudo k3s kubectl get pod -n dev <pod> -o jsonpath='{.spec.containers[*].name}{"\n"}'
sudo k3s kubectl get pod -n staging <pod> -o jsonpath='{.spec.containers[*].name}{"\n"}'
```

Expected outcome:
- output includes the application container and `istio-proxy`

Validate mesh policy resources:

```bash
sudo k3s kubectl get peerauthentication,destinationrule,virtualservice,authorizationpolicy -n dev
sudo k3s kubectl get peerauthentication,destinationrule,virtualservice,authorizationpolicy -n staging
```

Expected outcome:
- STRICT mTLS is configured
- retry policy is configured
- authorization allow and deny behavior can be captured through curl logs
- Kiali shows traffic edges for `dev` and `staging` workloads

## 6. Validate Mesh Demo

`mesh-demo` remains useful as a focused policy test bed, but it is supporting
evidence only. After `mesh-demo` manifests are applied and healthy:

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

## 7. Validate External Access

From an external machine with `hosts` entries:

```bash
curl -I -H 'Host: yas.dev.local' http://<gcp-external-ip>:30080/
```

Expected outcome:
- external access works through ingress `NodePort`
- application services remain internal `ClusterIP` backends

## 8. Capture Deliverable Evidence

Collect and store:

- `kubectl get applications -n argocd`
- `kubectl get pods -A`
- `kubectl top nodes`
- `kubectl top pods -A --sort-by=cpu`
- Jenkins logs for deployment and teardown jobs
- Git history for GitOps commits
- platform infrastructure readiness output
- `dev` and `staging` pod readiness output showing `2/2`
- `dev` and `staging` container-name output showing `istio-proxy`
- mesh curl output and Kiali screenshot
