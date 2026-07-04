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
  worker). Đã chốt **K3s**; không dùng hướng bootstrap control-plane/worker cũ.
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

**Đã có trong CD repo (scaffold/docs/validation):**
- `services.yaml` — catalog service deployable (loại `common-library`, `delivery`);
  template image `docker.io/${DOCKERHUB_USERNAME}/yas-${service}:${tag}`; tag
  commit-sha / main+latest / vX.Y.Z.
- `charts/` — chart snapshot để CD repo render độc lập.
- `base/`, `overlays/dev`, `overlays/staging`, `overlays/developer` — Kustomize desired state
  đã render được bằng `kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone`.
- `argocd/apps/yas-{dev,staging,developer}.yaml` — auto-sync + prune, trỏ
  `git@github.com:emanhthangngot/yas-cd.git`, branch `main`.
- `scripts/update-image-tag.sh` — contract để Jenkins cập nhật image tag qua GitOps.
- `scripts/validate-gitops.sh` và `scripts/validate-staging-immutable.sh` — kiểm tra catalog,
  overlays, source cũ, tag staging immutable và secret-like pattern.
- Docs: `docs/project02/{jenkins-jobs,cluster-runbook,mesh-runbook,
  development-roadmap-fixed}.md`; spec/plan/tasks trong `specs/001-yas-lab2-cd/`.

**Còn thiếu (phần triển khai thực):**
- Jenkins CD stages trong app repo: build+push Docker Hub theo tag commit-id; clone/push GitOps repo.
- Jenkins jobs: `developer_build`, `teardown_developer`, `deploy_dev`, `release_staging`,
  rollback, cluster smoke-check.
- Cài và verify K3s + ArgoCD + ingress + storage trên VM `gcp-ci-cd-agent`.
- Apply ArgoCD apps vào cluster thật và chụp evidence `Synced/Healthy`.
- Triển khai Istio/Kiali + policies và chụp evidence mesh.

## ⚠️ Lưu ý khi bắt đầu triển khai

- Docs `docs/project02/cluster-runbook.md` đã đi theo hướng **K3s**. Khi cập nhật thêm,
  không đưa lại hướng bootstrap control-plane/worker cũ.
- Label Jenkins agent: thống nhất `gcp-build-agent` (xem mục Quy ước Jenkinsfile).

## Trạng thái hiện tại - 2026-07-04

File handoff ngắn cho chat mới: `docs/project02/current-handoff.md`.

**CD repo `main` đã có các thay đổi quan trọng:**

- PR #11: căn lại service scope theo PDF yêu cầu của thầy, chỉ chạy các service cần thiết
  cho demo CQ cộng dependency tối thiểu; `sampledata` để dormant.
- PR #12: bỏ runtime developer mặc định; `dev` và `staging` chạy song song, `developer`
  dormant.
- PR #13: throttle CPU staging để giảm áp lực trên single-node VM.
- PR #14: staging rollout dùng `maxSurge: 0`, `maxUnavailable: 1` để không nhân đôi pod
  Java trong lúc update.

**App repo `main` hiện tại:**

- Chỉ có 1 `Jenkinsfile`, không có 3 Jenkinsfile riêng.
- Jenkinsfile dùng `TAG_NAME`, `BRANCH_NAME`, và `DEPLOY_TO_DEVELOPER` để chọn luồng.
- Push feature branch build/push image tag commit-id.
- Merge/push `main` build/push commit-id, `main`, `latest`, rồi update `dev`.
- Push tag `vX.Y.Z` là case riêng cho `staging`, nhưng Jenkins multibranch phải bật
  discover/build tags thì mới tự chạy.
- App `main` vẫn còn behavior `DEPLOY_TO_DEVELOPER=true` update developer; branch/PR disable
  developer GitOps chưa merge vào app `main`.

**Runtime cần kiểm tra lại:**

- Sau PR #14, cần refresh/đợi ArgoCD rồi xác nhận `dev` và `staging` đều `1/1`,
  `developer` `0/0`, node CPU không còn bị peak do rollout surge.

## Roadmap milestone (development-roadmap-fixed.md)

- **M0** ✅ docs/spec foundation
- **M1** cluster (GCP VM + K3s + storage) — *VM đã dựng, agent Online*
- **M2** ingress + ArgoCD + 3 app synced
- **M3** Jenkins CD jobs + Docker Hub tags
- **M4** deploy evidence (developer/dev/staging)
- **M5** Istio/Kiali mesh evidence
- **M6** báo cáo
