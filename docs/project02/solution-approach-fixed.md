# Đồ Án 02 - Hướng Giải Quyết GCP VM

File này thay thế plan cũ dùng Tailscale. Mục tiêu là giữ đủ yêu cầu Lab 2, nhưng triển khai trên một server Google Cloud 32 GB.

## 1. Architecture Chốt

```text
Developer
  -> GitHub branch/tag
  -> Jenkins Multibranch Pipeline
     -> Lab 1 CI gates
     -> Docker Hub image tags
     -> GitOps overlay commit
  -> ArgoCD sync
  -> GCP VM K3s single-node Kubernetes
     -> dev/staging/developer namespaces
     -> Nginx Ingress for basic demo
     -> Istio IngressGateway for mesh demo
```

Không dùng Tailscale. Không có master/worker riêng. VM duy nhất là Kubernetes control-plane và workload node.

## 2. GCP VM

Target:

```text
OS: Ubuntu 24.04 LTS
RAM: 32 GB
CPU: 4-8 vCPU recommended
Disk: 150 GB+ persistent disk
Kubernetes: K3s single-node
Storage: K3s bundled local-path provisioner
```

Record:

```text
GCP_VM_EXTERNAL_IP=<external-ip>
GCP_VM_INTERNAL_IP=<internal-ip>
ADMIN_SOURCE_CIDR=<your-public-ip>/32
```

Firewall:

```text
22/tcp      allow ADMIN_SOURCE_CIDR
30080/tcp   allow demo audience for Nginx HTTP
30081/tcp   allow demo audience if HTTPS demo is needed
30090/tcp   allow demo audience for Istio HTTP
30490/tcp   allow demo audience if Istio HTTPS demo is needed
8080/tcp    admin only or SSH tunnel
30444/tcp   admin only or SSH tunnel
30201/tcp   admin only or SSH tunnel
6443/tcp    restricted; do not expose broadly
```

Admin UI access should prefer SSH tunnel:

```bash
ssh -L 8080:127.0.0.1:8080 \
    -L 30444:127.0.0.1:30444 \
    -L 30201:127.0.0.1:30201 \
    <user>@${GCP_VM_EXTERNAL_IP}
```

## 3. Kubernetes Bootstrap

Use `docs/project02/cluster-runbook.md` as the command source.

Critical points:

- Install K3s with embedded containerd.
- Disable swap.
- Run K3s server install with internal and external IP as TLS SAN values.
- Disable bundled Traefik and ServiceLB so the lab can use explicit Nginx/Istio ingress setup.
- Verify the bundled Flannel network and local-path StorageClass.

Success evidence:

```bash
kubectl get nodes -o wide
kubectl describe node yas-gcp-single-node
kubectl get pods -A
kubectl get storageclass,pvc -A
```

## 4. Access And DNS

For app demo without real DNS, edit hosts on client machine:

```text
<GCP_VM_EXTERNAL_IP> yas.dev.local
<GCP_VM_EXTERNAL_IP> yas.staging.local
<GCP_VM_EXTERNAL_IP> yas.developer.local
<GCP_VM_EXTERNAL_IP> yas.mesh.local
```

Basic mode:

```bash
curl -H "Host: yas.dev.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
```

Mesh mode:

```bash
curl -H "Host: yas.mesh.local" "http://${GCP_VM_EXTERNAL_IP}:30090/"
```

## 5. GitOps Mode

Mode B remains the default:

```text
Jenkins build/push image
Jenkins update overlays/<env>
Jenkins commit/push yas-cd/main
ArgoCD syncs the environment
```

Rules:

- Jenkins must not `kubectl set image` in `dev`, `staging`, or `developer`.
- Jenkins must not `kubectl apply` app manifests directly to ArgoCD-managed namespaces.
- Staging uses immutable `vX.Y.Z` tags only.
- `services.yaml` is the service catalog source of truth.

## 6. Jenkins

Required jobs:

- `yas-ci-multibranch`
- `developer_build`
- `teardown_developer`
- `deploy_dev`
- `release_staging`
- `rollback_environment`
- `cluster_smoke_check`

Required credentials:

- `dockerhub-creds`
- `github-gitops-ssh`
- `argocd-token`
- `kubeconfig-readonly`
- `sonarqube-token`
- `snyk-token`

No secret content belongs in Git, docs screenshots, or build logs.

## 7. Service Mesh

Basic demo uses Nginx Ingress `30080`. Mesh demo uses Istio IngressGateway `30090`.

Mesh acceptance:

- Namespace has sidecar injection enabled.
- Pods show READY `2/2`.
- mTLS STRICT is enabled.
- AuthorizationPolicy has allow and deny evidence.
- Retry policy has curl evidence.
- Kiali screenshot shows traffic and security indicators.

## 8. Production Reality Check

This is a course lab deployment, not a production architecture. The report must say:

- Single-node Kubernetes has no node-level high availability.
- local-path storage is tied to one VM.
- NodePort and hosts file are acceptable for the assignment demo, but production should use DNS, TLS, and cloud LoadBalancer/Ingress.
- Jenkins Docker socket and broad kubeconfig access are lab shortcuts; production should use isolated builders and least-privilege service accounts.
- Admin UIs must not be public Internet surfaces.
