# Cluster Runbook - GCP VM Single-Node

## Target Topology

- One Google Cloud Compute Engine VM (`gcp-ci-cd-agent`) runs Jenkins Agent (CI), Kubernetes (K3s), ArgoCD, ingress, mesh, and YAS workloads.
- Jenkins Controller (Master) remains on the existing AWS EC2 CI server (`3.27.92.213`).
- Kubernetes distribution: `k3s` single-node.
- OS: Ubuntu 24.04 LTS.
- VM size: 32 GB RAM, recommended 4-8 vCPU, 150 GB+ persistent disk.
- Tailscale is not used.

## Access Model

- Public/demo access:
  - Traefik Ingress HTTP/HTTPS: `30080/30081`
  - Istio IngressGateway HTTP/HTTPS: `30090/30490`
- Admin access:
  - ArgoCD and Kiali must use SSH tunnel or GCP firewall allowlisting for the admin IP.
  - Do not open Jenkins, ArgoCD, Kiali, Kubernetes API, databases, or admin consoles to `0.0.0.0/0`.

## Bootstrap

Install host tools, Helm, `yq`, `kustomize`, `argocd`, and `istioctl`. K3s includes the Kubernetes server, kubelet, kubectl integration, embedded containerd, Flannel networking, and local-path storage.

Install K3s:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-name gcp-ci-cd-agent \
  --tls-san ${GCP_VM_INTERNAL_IP} \
  --tls-san ${GCP_VM_EXTERNAL_IP} \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb" sh -

mkdir -p "$HOME/.kube"
sudo cp -i /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
```

Verify K3s, the node, bundled Flannel networking, and bundled local-path storage. Then install Nginx Ingress, ArgoCD, Istio, and Kiali as documented in the team evidence flow.

## GitOps Readiness

ArgoCD owns the `dev`, `staging`, and `developer` namespaces. Jenkins updates this repo; ArgoCD reconciles the cluster.
Platform dependencies are also GitOps-managed by the `yas-platform` ArgoCD app from `platform/base`. It creates lab-local PostgreSQL, Redis, Kafka, Elasticsearch, Keycloak, and the in-namespace `identity` aliases required by the YAS workloads.

Render desired state before syncing:

```bash
kustomize build platform/base
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/dev
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/developer
scripts/validate-staging-immutable.sh
```

Install ArgoCD apps from this repo:

```bash
kubectl apply -f argocd/apps/
argocd app list
argocd app wait yas-platform --health --sync --timeout 900
argocd app wait yas-dev --health --sync --timeout 600
argocd app wait yas-staging --health --sync --timeout 600
argocd app wait yas-developer --health --sync --timeout 600
```

## Hosts File And App Access

```text
<GCP_VM_EXTERNAL_IP> yas.dev.local
<GCP_VM_EXTERNAL_IP> yas.staging.local
<GCP_VM_EXTERNAL_IP> yas.developer.local
<GCP_VM_EXTERNAL_IP> yas.mesh.local
```

Example checks:

```bash
curl -H "Host: yas.dev.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
curl -H "Host: yas.mesh.local" "http://${GCP_VM_EXTERNAL_IP}:30090/"
```

## Evidence

- GCP VM machine type, memory, disk, and OS version.
- GCP firewall rules proving admin access is restricted.
- SSH tunnel command or screenshot for admin UI access.
- `kubectl get nodes -o wide`
- `kubectl describe node gcp-ci-cd-agent`
- `kubectl get pods -A`
- `kubectl get storageclass,pvc -A`
- `systemctl status k3s --no-pager`
- ArgoCD apps `Synced/Healthy`
- GitOps diff in `yas-cd`
- App URL through hosts file/Host header and NodePort.
