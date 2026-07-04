# Đồ Án 02 - Architecture Fix Notes

File này dùng khi review, chia task, hoặc viết phần "vấn đề gặp phải và cách khắc phục" trong báo cáo.

## Decisions

### ADR-001 - GitOps là source of truth

**Decision:** Mọi deploy `dev/staging/developer` đi qua GitOps repo.

**Reason:** ArgoCD chỉ hoạt động đúng khi Git là desired state. Jenkins deploy trực tiếp sẽ tạo drift.

**Consequence:** Jenkins có quyền push GitOps changes, nhưng không mutate namespace trực tiếp.

### ADR-002 - Chuyển network target từ Tailscale sang GCP VM

**Decision:** Không dùng Tailscale. Lab 2 dùng một Google Cloud Compute Engine VM 32 GB có external IP, GCP firewall, và SSH tunnel/admin-IP allowlist.

**Reason:** Nhóm sẽ thuê một server GCP để host Kubernetes thay vì nối nhiều máy qua private overlay network.

**Consequence:** Tất cả runbook/evidence dùng `GCP_VM_EXTERNAL_IP` và `GCP_VM_INTERNAL_IP`, không dùng biến IP master/worker của network cũ.

### ADR-003 - K3s single-node

**Decision:** Dùng `K3s` single-node trên Ubuntu 24.04 LTS; server node chạy luôn workload cho phạm vi lab.

**Reason:** K3s giảm số bước bootstrap so với hướng bootstrap thủ công cũ, có embedded containerd, Flannel và local-path nên phù hợp hơn với một VM 32 GB trong phạm vi đồ án.

**Consequence:** Evidence sẽ có một node Ready. Storage và capacity phải ghi rõ single-node lab limitation. Không cần bước chỉnh scheduling thủ công.

### ADR-004 - Storage single-node

**Decision:** Dùng K3s bundled local-path dynamic storage cho lab.

**Reason:** NFS master/worker không còn phù hợp khi chỉ có một VM.

**Consequence:** PVC bind được cho demo, nhưng storage không có replication/cross-node migration.

### ADR-005 - Tách Basic Ingress và Mesh Ingress

**Decision:** Basic CI/CD dùng Nginx Ingress; Service Mesh dùng Istio IngressGateway.

**Reason:** Nginx Ingress không có sidecar có thể bị chặn khi namespace bật `mTLS STRICT`.

**Consequence:** Báo cáo cần mô tả hai giai đoạn demo khác nhau.

### ADR-006 - ArgoCD/Kiali/Jenkins không public rộng

**Decision:** App/demo NodePorts có thể public theo nhu cầu demo; Jenkins, ArgoCD, Kiali chỉ qua SSH tunnel hoặc firewall allowlist admin IP.

**Reason:** Admin UI có quyền cao và không nên mở Internet rộng.

**Consequence:** Evidence cần có firewall rule hoặc SSH tunnel screenshot/command.

### ADR-007 - Dùng `services.yaml` làm service catalog

**Decision:** Jenkins, GitOps overlay và báo cáo đều đọc/đối chiếu từ `services.yaml`.

**Reason:** Repo YAS có nhiều module; hardcode danh sách service dễ thiếu service hoặc deploy sai folder.

**Consequence:** Trước demo phải chốt service nào in scope, service nào excluded và lý do.

## Final Flow Nên Demo

### Basic flow

```text
git push branch dev_tax_service
  -> Jenkins CI build image tag commit id
  -> DockerHub có yas-tax:<commit-id>

Manual developer_build
  -> chọn tax_branch=dev_tax_service
  -> Jenkins update overlays/developer
  -> ArgoCD sync
  -> browser/curl truy cập qua http://yas.developer.local:30846
```

### Dev flow

```text
git push main
  -> Jenkins build image
  -> push main/latest
  -> Jenkins commit overlays/dev
  -> ArgoCD yas-dev sync
```

### Staging flow

```text
git tag v0.1.0
git push origin v0.1.0
  -> Jenkins build image v0.1.0
  -> DockerHub có tag v0.1.0
  -> Jenkins commit overlays/staging
  -> ArgoCD yas-staging sync
```

### Mesh flow

```text
Browser/curl
  -> GCP VM external IP :30090
  -> Istio IngressGateway
  -> VirtualService
  -> service
  -> mTLS
  -> downstream service
```

## Task Split

| Thành viên | Task |
|---|---|
| A | GCP VM, firewall, K3s single-node, local-path, ingress |
| B | Jenkins custom image/agent, CI Jenkinsfile, DockerHub |
| C | GitOps repo, Kustomize, ArgoCD apps |
| D | Istio, Kiali, mTLS, AuthorizationPolicy, retry evidence |

## Review Checklist Trước Demo

```text
[ ] Không còn Tailscale trong runbook/spec hiện hành
[ ] GCP VM đúng 32 GB-class RAM
[ ] Firewall không mở admin UI rộng
[ ] SSH tunnel/admin-IP access cho Jenkins/ArgoCD/Kiali
[ ] Kubernetes single node Ready
[ ] K3s server node schedules workloads
[ ] StorageClass local-path available
[ ] ArgoCD app Synced/Healthy
[ ] Jenkins không kubectl set image vào namespace do ArgoCD quản lý
[ ] Base YAML không hardcode namespace
[ ] services.yaml khớp repo YAS và Jenkins/GitOps cùng dùng catalog này
[ ] DockerHub có tag commit id
[ ] DockerHub có tag main/latest
[ ] DockerHub có tag vX.Y.Z
[ ] developer_build update GitOps repo thành công
[ ] App truy cập được qua domain:port
[ ] Istio sidecar READY 2/2
[ ] mTLS STRICT verify được
[ ] AuthorizationPolicy có cả allow và deny evidence
[ ] Retry có evidence
[ ] Kiali graph có traffic và security badge
[ ] Báo cáo có production reality check cho NodePort, local-path storage, Jenkins Docker socket, secrets/RBAC
```
