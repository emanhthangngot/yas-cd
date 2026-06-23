# Đồ án 2 — Hệ thống CD cho YAS: Context

> File này lưu context & quyết định đã chốt cho Đồ án 2, để đi theo repo (chia sẻ
> được với đồng đội, dùng được ở máy/đường dẫn khác). Đề bài gốc:
> `docs/project02/Project02_HKII_25_26.md`.
>
> ⚠️ **Bảo mật:** KHÔNG commit token/secret/credential thật vào file này hay bất kỳ
> file nào trong repo. Secret của Jenkins agent chỉ nằm trong systemd unit trên VM.

## Tổng quan

- **Môn học:** DevOps (HCMUS, HK2 năm 3). Đồ án 2 = xây hệ thống **CD** cho app
  microservices Java **YAS (Yet Another Shop)**.
- **Nhóm:** 4 SV. Báo cáo `.docx` đặt tên theo `<MSSV…>` tăng dần.
- **Branch làm việc:** `lab2/cd-platform`.

## Lab 1 (đã xong)

CI phân tán Master–Agent trên **AWS**: Jenkins Master trên EC2 (Docker), 3 agent
local (Agent-Tri, Agent-QVinh, Agent-TVinh) qua JNLP. Pipeline 8 stage: Checkout,
Monorepo Path Filter, Test+JaCoCo, Build, Gitleaks, SonarQube, Snyk. Từng gặp lỗi
OOM Snyk exit -13 do thiếu RAM → lý do thuê GCP VM 32GB cho Lab 2.

## Hạ tầng thực tế (đã dựng, đang Online)

### Jenkins Controller (Master) — AWS

| Thông số | Giá trị |
|---|---|
| Nhà cung cấp | AWS EC2 |
| IP Public | `3.27.92.213` |
| Triển khai | Docker container, image `jenkins/jenkins:lts`, container name `jenkins` |
| Jenkins Core | `2.555.3` |
| Runtime | Java 21 (OpenJDK 21.0.11 / Temurin-21) |
| Cổng mở | `8080` (Web UI), `50000` (Inbound Agent — Fixed) |
| SonarQube | `http://3.27.92.213:9000` (dùng trong Jenkinsfile Lab 1) |

### Jenkins Agent (build chính) + Cụm K3s/ArgoCD — GCP

| Thông số | Giá trị |
|---|---|
| Nhà cung cấp | GCP VM |
| Instance | `gcp-ci-cd-agent` |
| Cấu hình | `e2-standard-8` (8 vCPU, 32 GB RAM) |
| OS | Ubuntu 24.04 LTS (Minimal) |
| Nhiệm vụ | Jenkins Agent (CI) **+** K3s Cluster & ArgoCD (CD) trên cùng 1 máy |

**Cấu hình Node trên Jenkins** (Manage Jenkins → Nodes → New Node):
- Name: `gcp-agent` · Executors: **4** · Remote root: `/home/vinhp1546/jenkins`
- **Label: `gcp-build-agent`** · Usage: Use as much as possible
- Launch: *Launch agent by connecting it to the controller* (inbound/JNLP qua cổng 50000)
- Availability: Keep online as much as possible
- Lý do 4 executors: VM gánh cả K3s/ArgoCD + microservices → giữ ~4 vCPU dự phòng cho
  cluster runtime, tránh nghẽn/sập Pod khi build song song.

**Kết nối agent:** chạy ngầm bằng systemd unit `/etc/systemd/system/jenkins-agent.service`
trên VM (`java -jar agent.jar -url http://3.27.92.213:8080/ -secret <SECRET> -name gcp-agent`).
Secret nằm trong file này trên VM — **KHÔNG commit vào repo**. Bỏ `-webSocket`, dùng cổng
tĩnh `50000`.

> 🔧 **Nhật ký gỡ lỗi quan trọng:** Agent ban đầu báo `UnsupportedClassVersionError` do
> chạy Java 17, không đọc được class Java 21 từ Master. Fix: gỡ `openjdk-17-jre-headless`,
> cài `openjdk-21-jre-headless`. **Java runtime của Agent phải khớp Master = Java 21.**

## Kiến trúc Lab 2 (đã CHỐT)

- **Cluster: K3s single-node** trên chính GCP VM `gcp-ci-cd-agent` (gộp control-plane +
  worker). ✅ Đã chốt **K3s** (KHÔNG dùng kubeadm — dù docs cũ viết theo kubeadm).
- **GitOps split-repo:** tạo **GitOps Repo** riêng chứa YAML manifests, tách khỏi Source Repo.
- **Luồng CD:** code đổi ở Source Repo → Jenkins Master (AWS) điều phối xuống GCP Agent
  (`gcp-build-agent`) chạy CI → build image → push **Docker Hub** (tag = commit-id) →
  stage cuối script update tag image vào YAML trên GitOps Repo → **ArgoCD** (trong K3s)
  watch GitOps Repo → auto sync → K3s rolling update.
- **Service Mesh (nâng cao):** **Istio + Kiali** trên K3s — mTLS STRICT, retry khi service
  trả 500, AuthorizationPolicy (giới hạn service-to-service), Kiali topology.

## Quy ước viết Jenkinsfile (bắt buộc)

Pipeline phải khai báo đúng label để đẩy việc qua GCP agent:

```groovy
pipeline {
    agent { label 'gcp-build-agent' }   // bắt buộc đúng label này
    stages {
        stage('Checkout Code')          { steps { checkout scm } }
        stage('Build & Test Backend')   { steps { /* mvn clean package -DskipTests */ } }
        stage('Dockerize & Push Image') { steps { /* docker build + push Docker Hub */ } }
    }
}
```

> ⚠️ Jenkinsfile Lab 1 hiện dùng label `yas-build-worker` — cần thống nhất sang
> `gcp-build-agent` khi chuyển build sang GCP agent.

## Yêu cầu đề (điểm)

- **Cơ bản (6đ):** image tag main/latest mặc định (KHÔNG cần Grafana/Prometheus);
  K8s cluster (K3s OK); CI build image tag commit-id push Docker Hub mỗi branch;
  job `developer_build` (chọn branch/service để deploy, trả domain:port NodePort, dev tự
  thêm /etc/hosts trỏ worker node); job xóa deploy; (mục 6, bỏ qua nếu làm nâng cao)
  job dev (auto deploy main→ns dev) + staging (tag vX.Y.Z → ns staging).
- **Nâng cao:** ArgoCD handle dev/staging (2đ) + Service Mesh Istio/Kiali (2đ).

## Hiện trạng repo

**Đã có (scaffold/docs):**
- `services.yaml` — catalog service deployable (loại `common-library`, `delivery`);
  template image `docker.io/${DOCKERHUB_USERNAME}/yas-${service}:${tag}`; tag
  commit-sha / main+latest / vX.Y.Z.
- `k8s/charts/` — 27 Helm charts + platform deps trong `k8s/deploy/`.
- `deploy/gitops/` — skeleton base + overlays dev/staging/developer (đang RỖNG
  `resources: []`) + 3 ArgoCD App `argocd/apps/yas-{dev,staging,developer}.yaml`
  (auto-sync + prune, trỏ `lab2/cd-platform`).
- `Jenkinsfile` — CI Lab 1 (8 stage) + skip-CI cho commit docs/gitops/spec.
- Docs: `docs/project02/{jenkins-jobs,cluster-runbook,mesh-runbook,
  development-roadmap-fixed}.md`; spec/plan/tasks trong `specs/001-yas-lab2-cd/`.
- GitHub Actions hiện push image lên `ghcr.io:latest` (KHÁC yêu cầu: phải Docker Hub
  + tag commit-id).

**Còn thiếu (phần triển khai thực):**
- Jenkins CD stages: build+push Docker Hub theo tag commit-id; script update tag vào GitOps repo.
- Jenkins jobs: `developer_build`, `teardown_developer`, `deploy_dev`, `release_staging`,
  rollback, cluster smoke-check.
- Populate overlays (render charts + image override theo tag).
- Cài K3s + ArgoCD + ingress + storage trên VM `gcp-ci-cd-agent`.
- Triển khai Istio/Kiali + policies (mới có runbook).

## ⚠️ Lưu ý khi bắt đầu triển khai

- Docs `docs/project02/cluster-runbook.md` & liên quan hiện viết theo **kubeadm**
  (commit `190eb0a2`). Đã chốt **K3s** → cần cập nhật lại cho khớp.
- Label Jenkins agent: thống nhất `gcp-build-agent` (xem mục Quy ước Jenkinsfile).

## Roadmap milestone (development-roadmap-fixed.md)

- **M0** ✅ docs/spec foundation
- **M1** cluster (GCP VM + K3s + storage) — *VM đã dựng, agent Online*
- **M2** ingress + ArgoCD + 3 app synced
- **M3** Jenkins CD jobs + Docker Hub tags
- **M4** deploy evidence (developer/dev/staging)
- **M5** Istio/Kiali mesh evidence
- **M6** báo cáo
