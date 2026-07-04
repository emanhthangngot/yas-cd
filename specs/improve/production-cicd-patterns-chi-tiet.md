# Production CI/CD Pattern Cho Microservices — Đào Sâu Áp Dụng Vào yas-cd

Tài liệu này mổ xẻ từng pattern production đã liệt kê trước đó, áp dụng cụ thể vào
kiến trúc hiện tại (`tzin1401/yas` + `emanhthangngot/yas-cd`, Jenkins + ArgoCD + K3s +
Kustomize). Mỗi mục có: bản chất pattern → vì sao repo hiện tại "cứng" ở điểm đó →
cách làm lại cụ thể (kèm YAML/code mẫu) → giới hạn thực tế cho scope đồ án (14 service
theo `deployment-services-cq.pdf`, 1 VM, deadline môn học).

---

## 0. Khung tham chiếu: vì sao pattern production tồn tại

Trước khi vào từng mục, cần hiểu **vấn đề gốc** mà mỗi pattern giải quyết, vì nếu chỉ
copy hình thức (VD: thêm ApplicationSet cho có) mà không hiểu vấn đề gốc, kết quả vẫn
"cứng" — chỉ là cứng theo cách khác.

Vấn đề gốc chung của mọi pattern dưới đây: **khi số service × số môi trường × số loại
trigger tăng lên, độ phức tạp không được tăng tuyến tính theo cách con người phải sửa
tay từng chỗ.** Production dùng amortization — đầu tư một lần vào cơ chế generic, sau
đó thêm service/env mới gần như miễn phí (chỉ thêm data, không thêm logic).

Repo `yas-cd` hiện tại chưa có amortization này: thêm 1 service mới đòi phải sửa
`services.yaml`, chạy `sync-gateway-routes.sh`, có thể phải sửa thêm overlay tay,
review PR — chi phí không giảm dần theo thời gian.

---

## 1. Per-service pipeline, không phải 1 pipeline khổng lồ if/else

### Bản chất pattern
Trong production thật, một tổ chức có N service thường có N pipeline definition —
nhưng **N pipeline không có nghĩa là N lần viết code**. Cách đạt được điều này:

- **Jenkins Shared Library**: logic build/test/push nằm trong 1 thư viện Groovy dùng
  chung (`vars/buildService.groovy`), mỗi service chỉ có 1 `Jenkinsfile` ngắn gọi vào
  thư viện đó với tham số riêng (tên service, Dockerfile path, test command).
- Routing môi trường (branch nào đi đâu) là **1 hàm thuần túy** (pure function) tách
  biệt hoàn toàn khỏi logic build — nhận input (branch name, tag name), trả về output
  (target environment), không side-effect, dễ unit test.

### Vì sao Jenkinsfile hiện tại của app repo "cứng"
Theo `implementation-progress.md`, app repo `tzin1401/yas` chỉ có **1 Jenkinsfile duy
nhất** dùng `TAG_NAME`, `BRANCH_NAME`, `DEPLOY_TO_DEVELOPER` để rẽ nhánh toàn bộ logic
build + push + update GitOps. Đây là monorepo build toàn bộ service trong 1 pipeline
run — khi 1 service đổi, logic if/else phải tự biết những gì cần build lại (dù đã có
"Monorepo Path Filter" từ Lab 1 để giới hạn phạm vi, đây vẫn là filter theo thư mục
thay đổi, không phải per-service pipeline độc lập).

### Cách làm lại cụ thể

**Bước 1 — Tách shared library:**

```groovy
// jenkins-shared-lib/vars/buildAndPushService.groovy
def call(Map config) {
    def serviceName = config.serviceName
    def dockerfilePath = config.dockerfilePath ?: "${serviceName}/Dockerfile"
    def imageTag = env.GIT_COMMIT.take(7)

    stage("Build ${serviceName}") {
        sh "docker build -t ${DOCKERHUB_USERNAME}/yas-${serviceName}:${imageTag} -f ${dockerfilePath} ."
    }
    stage("Push ${serviceName}") {
        sh "docker push ${DOCKERHUB_USERNAME}/yas-${serviceName}:${imageTag}"
    }
    return imageTag
}
```

**Bước 2 — Tách hàm resolve target environment (pure function, test được):**

```groovy
// jenkins-shared-lib/vars/resolveTargetEnv.groovy
def call(String branchName, String tagName) {
    if (tagName?.matches(/^v\d+\.\d+\.\d+$/)) {
        return 'staging'
    }
    if (branchName == 'main') {
        return 'dev'
    }
    return 'none'  // feature branch: chỉ build/push image, không update GitOps
}
```

Vì đây là 1 hàm thuần túy, có thể viết unit test độc lập (Groovy `JenkinsPipelineUnit`
hoặc đơn giản hơn là test bằng script Groovy chạy ngoài Jenkins):

```groovy
assert resolveTargetEnv('main', null) == 'dev'
assert resolveTargetEnv('dev_tax_service', null) == 'none'
assert resolveTargetEnv('main', 'v1.2.3') == 'staging'
```

**Bước 3 — Jenkinsfile chính chỉ còn là orchestration mỏng:**

```groovy
pipeline {
    agent { label 'gcp-build-agent' }
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('CI Gates') {
            steps {
                // giữ nguyên toàn bộ Lab 1: test, jacoco, gitleaks, sonar, snyk
            }
        }
        stage('Build & Push') {
            steps {
                script {
                    env.IMAGE_TAG = buildAndPushService(serviceName: env.CHANGED_SERVICE)
                    env.TARGET_ENV = resolveTargetEnv(env.BRANCH_NAME, env.TAG_NAME)
                }
            }
        }
        stage('Update GitOps') {
            when { expression { env.TARGET_ENV != 'none' } }
            steps {
                updateGitopsRepo(service: env.CHANGED_SERVICE, env: env.TARGET_ENV, tag: env.IMAGE_TAG)
            }
        }
    }
}
```

### Giới hạn cho đồ án
Viết Shared Library đầy đủ (repo riêng, versioning `@Library`) hơi nặng cho 4 người
làm trong thời gian có hạn. **Phương án rút gọn**: giữ 1 Jenkinsfile nhưng refactor
nội bộ theo đúng cấu trúc trên bằng Groovy method thường (`def buildAndPushService()`
định nghĩa ngay trong Jenkinsfile, không cần tách thư viện riêng). Vẫn đạt được tách
biệt logic, chưa cần hạ tầng thư viện riêng.

---

## 2. Trigger dựa trên convention, không dựa trên flag thủ công

### Bản chất pattern
Quy ước (convention) được **encode vào chính cấu trúc Git** (tên branch, tag format),
không phải vào biến người dùng tự gõ. Khi convention nằm trong Git, nó tự động đúng
100% số lần — không ai quên set flag, vì không có flag nào để quên.

Bảng convention chuẩn (đã có sẵn logic tương đương trong `implementation-progress.md`,
chỉ cần bỏ phần thủ công):

| Sự kiện Git | Hành động tự động | Không cần |
|---|---|---|
| Push bất kỳ branch nào khác `main` | Build + push image tag = commit id. Không deploy đâu cả | flag thủ công |
| Merge/push vào `main` | Build + push tag `main`, `latest`, commit id → update `overlays/dev` | flag thủ công |
| Push tag khớp `v\d+\.\d+\.\d+` | Build + push tag đó → update `overlays/staging` | branch riêng, PR riêng |
| **(Tuỳ chọn nâng cao)** PR mở với label `preview` | Tạo namespace tạm `pr-<số>`, deploy | `DEPLOY_TO_DEVELOPER=true` gõ tay |

### Vì sao `DEPLOY_TO_DEVELOPER` là điểm cứng nhất
Đây là **cờ do con người set**, không phải suy ra từ Git — đúng như file
`implementation-progress.md` đã tự ghi nhận: "branch/PR that disables developer preview
GitOps is not merged into app repo `main` yet" và "app `main` vẫn còn behavior
`DEPLOY_TO_DEVELOPER=true`". Đây chính xác là loại lỗi mà convention-based trigger
được sinh ra để loại bỏ: **một trạng thái ẩn (global flag) không nằm trong Git commit
nào cả, phải nhớ bằng đầu.**

### Cách làm lại cụ thể — đưa developer preview về đúng model của đề bài

Đọc lại đề bài gốc (`Project02_HKII_25_26.md` mục 4): developer preview **vốn dĩ đã
được thiết kế là 1 Jenkins job riêng** (`developer_build`) nhận parameter branch, KHÔNG
phải 1 nhánh logic trong pipeline chính:

> "Tạo Job CD cho developer làm việc với tên developer_build. Với job này developer có
> thể input parameter là branch muốn deploy."

Tức là bản thiết kế gốc của đề bài **đã đúng convention-based** — job riêng, tham số
tường minh, không lẫn vào pipeline chính. Vấn đề là app repo hiện tại đã lẫn logic này
vào Jenkinsfile chính qua flag `DEPLOY_TO_DEVELOPER`. Việc cần làm:

1. Xoá nhánh `DEPLOY_TO_DEVELOPER` khỏi Jenkinsfile chính hoàn toàn.
2. Tạo Jenkins **Parameterized Job** riêng tên `developer_build`:

```groovy
pipeline {
    agent { label 'gcp-build-agent' }
    parameters {
        string(name: 'TARGET_SERVICE', description: 'Service muốn deploy bản dev, VD: tax')
        string(name: 'SOURCE_BRANCH', description: 'Branch của service đó, VD: dev_tax_service')
    }
    stages {
        stage('Build target service from branch') {
            steps {
                script {
                    def tag = buildAndPushService(serviceName: params.TARGET_SERVICE, branch: params.SOURCE_BRANCH)
                    updateGitopsRepo(service: params.TARGET_SERVICE, env: 'developer', tag: tag)
                    // các service còn lại giữ nguyên tag main/latest — không build lại
                }
            }
        }
    }
}
```

Job này tồn tại **độc lập**, không đụng vào luồng `main`/tag. Đây chính là convention
đúng nghĩa: mỗi loại ý định (release, dev, developer-test) có 1 kênh trigger riêng biệt,
không dùng chung 1 pipeline với cờ rẽ nhánh.

3. Job xoá deployment (mục 5 đề bài) cũng làm tương tự — job riêng, không lẫn logic.

### Về preview môi trường tự động theo PR (nâng cao, không bắt buộc)
Nếu muốn đúng chuẩn production hơn nữa (không bắt buộc theo đề bài), ArgoCD
ApplicationSet hỗ trợ **Pull Request generator** — tự tạo Application mới mỗi khi có PR
mở, tự xoá khi PR đóng, không cần job Jenkins riêng:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: yas-pr-preview
  namespace: argocd
spec:
  generators:
    - pullRequest:
        github:
          owner: tzin1401
          repo: yas
          tokenRef:
            secretName: github-token
            key: token
        requeueAfterSeconds: 60
  template:
    metadata:
      name: 'yas-pr-{{number}}'
    spec:
      project: default
      source:
        repoURL: git@github.com:emanhthangngot/yas-cd.git
        targetRevision: main
        path: 'overlays/pr-template'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'pr-{{number}}'
```

Đây là điểm cộng P2 (đã ghi trong kế hoạch hoàn thiện trước) — không cần làm nếu không
dư thời gian, vì cần thêm `overlays/pr-template` parameterized và GitHub token permission
mới.

---

## 3. Build once, promote many lần

### Bản chất pattern
Image Docker được build **đúng 1 lần** tại thời điểm commit, sau đó **cùng 1 artifact
đó** (theo digest, không phải rebuild) được đẩy tuần tự qua dev → staging → prod. Lý
do: nếu build lại ở mỗi bước promote, có rủi ro codebase/dependency thay đổi giữa 2 lần
build (VD: base image `FROM node:20` tự động kéo bản vá mới) khiến artifact ở staging
khác artifact đã test ở dev — phá vỡ nguyên tắc "cái gì đã test thì cái đó lên prod".

### Vì sao cách hiện tại "build lại theo từng loại trigger" có vấn đề
Theo `implementation-progress.md`, mục "App Repo Jenkins State":

- Push tag `vX.Y.Z` → build lại từ đầu, tạo tag mới `vX.Y.Z` + commit-id mới.
- Merge `main` → build lại, tạo tag `main`, `latest`, commit-id.

Đây là 2 lần build riêng biệt cho cùng 1 dòng code (nếu tag `v1.2.3` được tạo ngay tại
commit vừa merge vào `main`), tốn thời gian CI gấp đôi, và về lý thuyết có rủi ro (dù
nhỏ) 2 lần build ra 2 image khác nhau bit-for-bit nếu build không hoàn toàn
reproducible (timestamp trong layer, cache Docker khác nhau giữa 2 lần build...).

### Cách làm lại cụ thể — retag thay vì rebuild

Dùng `docker buildx imagetools create` (hoặc `skopeo copy`) để **retag digest có sẵn**
thay vì `docker build` lại:

```groovy
// Khi merge vào main: build 1 lần, tag = commit-id
stage('Build on merge to main') {
    steps {
        sh "docker build -t ${REGISTRY}/yas-${SERVICE}:${COMMIT_ID} ."
        sh "docker push ${REGISTRY}/yas-${SERVICE}:${COMMIT_ID}"
    }
}

// Retag digest đó thành main/latest — KHÔNG build lại
stage('Promote commit-id -> main/latest') {
    steps {
        sh "docker buildx imagetools create -t ${REGISTRY}/yas-${SERVICE}:main ${REGISTRY}/yas-${SERVICE}:${COMMIT_ID}"
        sh "docker buildx imagetools create -t ${REGISTRY}/yas-${SERVICE}:latest ${REGISTRY}/yas-${SERVICE}:${COMMIT_ID}"
    }
}
```

Khi tạo tag release `vX.Y.Z` từ 1 commit đã từng chạy qua CI trên `main` trước đó (tức
image với tag = commit-id đó đã tồn tại trên Docker Hub), bước "release" chỉ cần retag,
**không cần checkout lại source, không cần chạy lại `mvn build`**:

```groovy
pipeline {
    agent { label 'gcp-build-agent' }
    stages {
        stage('Resolve source commit-id from tag') {
            steps {
                script {
                    env.SOURCE_COMMIT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                }
            }
        }
        stage('Promote existing image to staging tag') {
            steps {
                sh "docker buildx imagetools create -t ${REGISTRY}/yas-${SERVICE}:${TAG_NAME} ${REGISTRY}/yas-${SERVICE}:${SOURCE_COMMIT}"
            }
        }
        stage('Update GitOps staging') {
            steps { updateGitopsRepo(service: env.SERVICE, env: 'staging', tag: env.TAG_NAME) }
        }
    }
}
```

### Rủi ro cần lưu ý khi áp dụng
Cách này **chỉ đúng** nếu tag `vX.Y.Z` được tạo từ 1 commit đã từng build thành công
trên `main` (tức image với tag = short-commit-id đó chắc chắn tồn tại trên Docker Hub).
Nếu quy trình release của nhóm cho phép tạo tag từ 1 commit chưa từng qua CI (VD:
`rc_v1.2.3` branch riêng chưa merge `main`), thì bắt buộc phải build lại — đề bài gốc
cũng có gợi ý hướng "tách branch rc_v1.2.3" như 1 lựa chọn. Trong trường hợp đó, chấp
nhận build 2 lần là hợp lý, chỉ cần đảm bảo Dockerfile pin version cụ thể (không dùng
tag `latest` cho base image) để giảm rủi ro build không tái lập được.

### Giới hạn cho đồ án
Đổi từ rebuild sang retag là thay đổi nhỏ, rủi ro thấp, đáng làm nếu Vinh Nhỏ còn thời
gian sau khi xong các mục P0 trong kế hoạch trước — không tốn thêm hạ tầng, chỉ đổi vài
dòng Jenkinsfile.

---

## 4. GitOps: App-of-Apps / ApplicationSet thay vì liệt kê tay

### Bản chất pattern
Khi có 3 Application (`yas-dev`, `yas-staging`, `yas-developer`) như hiện tại, liệt kê
tay 3 file YAML không phải vấn đề lớn. Vấn đề phát sinh khi **số lượng scale theo chiều
nào đó không cố định** — VD: mỗi PR 1 Application, mỗi team 1 cluster, mỗi tenant 1 bộ
namespace. ApplicationSet giải quyết bằng cách sinh Application **từ 1 generator**
(list, git directory, cluster list, PR list...) thay vì viết tay từng cái.

### Vì sao 3 file `argocd/apps/yas-{dev,staging,developer}.yaml` hiện tại chưa thực sự "cứng"
Cần thành thật: với đúng 3 môi trường cố định (dev/staging/developer) theo đề bài, viết
tay 3 file **không phải vấn đề** — đây không phải trường hợp cần ApplicationSet. Áp
dụng ApplicationSet ở đây là "dùng dao mổ trâu giết gà" nếu không có nhu cầu scale thật
sự. Phần này chỉ đáng làm nếu nhóm muốn demo hiểu biết mở rộng (điểm cộng), không phải
vì 3 file YAML kia đang gây vấn đề thực tế.

### Nếu vẫn muốn làm (điểm cộng P2) — dùng List generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: yas-environments
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            targetRevision: main
            autoPrune: "true"
          - env: staging
            targetRevision: main
            autoPrune: "true"
          - env: developer
            targetRevision: main
            autoPrune: "false"
  template:
    metadata:
      name: 'yas-{{env}}'
    spec:
      project: default
      source:
        repoURL: git@github.com:emanhthangngot/yas-cd.git
        targetRevision: '{{targetRevision}}'
        path: 'overlays/{{env}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{env}}'
      syncPolicy:
        automated:
          prune: '{{autoPrune}}'
          selfHeal: true
```

Ưu điểm thực tế duy nhất so với 3 file riêng: thêm môi trường thứ 4 chỉ cần thêm 1
phần tử trong `elements`, không cần copy-paste cả khối YAML Application. Với đúng 3 môi
trường cố định suốt vòng đời đồ án, lợi ích này gần như bằng 0 — nên xếp việc này ở ưu
tiên thấp nhất trong toàn bộ danh sách cải tiến.

---

## 5. Progressive delivery: canary/blue-green qua Argo Rollouts

### Bản chất pattern
Thay vì rolling update đổi hết pod cùng lúc (dù có `maxSurge`/`maxUnavailable` để giới
hạn tốc độ), canary release đổi **một phần nhỏ traffic** sang phiên bản mới trước, theo
dõi metric (error rate, latency qua Prometheus), tự động tiếp tục tăng dần traffic nếu
metric ổn, hoặc tự động rollback nếu metric xấu đi — không cần con người can thiệp giữa
chừng.

### Vì sao `maxSurge: 0` (PR #14 trong `implementation-progress.md`) không phải progressive delivery
PR #14 giải quyết vấn đề **tài nguyên** (tránh nhân đôi pod Java trên VM 1 node), không
giải quyết vấn đề **rủi ro release**. Đây là 2 vấn đề khác nhau dễ nhầm lẫn:

- `maxSurge: 0, maxUnavailable: 1`: đảm bảo không vượt quá N pod cùng lúc — mục tiêu là
  tiết kiệm RAM/CPU trên VM đơn.
- Canary: đảm bảo nếu bản mới có bug, chỉ 5-10% traffic bị ảnh hưởng, phát hiện tự động
  qua metric, rollback tự động — mục tiêu là giảm blast radius khi release lỗi.

Rollout hiện tại của yas-staging vẫn là **all-or-nothing về mặt rủi ro**: nếu image mới
có bug logic (không phải vấn đề tài nguyên), toàn bộ traffic vẫn chuyển sang bản lỗi
ngay khi rollout xong, chỉ là tốc độ chuyển chậm hơn do giới hạn surge.

### Ví dụ minh hoạ cho 1 service (nếu làm, chỉ nên chọn 1 service ít rủi ro, VD `product`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: product
  namespace: staging
spec:
  replicas: 2
  strategy:
    canary:
      steps:
        - setWeight: 25
        - pause: { duration: 60 }
        - analysis:
            templates:
              - templateName: error-rate-check
        - setWeight: 50
        - pause: { duration: 60 }
        - setWeight: 100
  selector:
    matchLabels:
      app: product
  template:
    metadata:
      labels:
        app: product
    spec:
      containers:
        - name: product
          image: docker.io/${DOCKERHUB_USERNAME}/yas-product:${TAG}
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate-check
  namespace: staging
spec:
  metrics:
    - name: error-rate
      interval: 30s
      successCondition: result < 0.05
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc:9090
          query: |
            sum(rate(http_requests_total{app="product",status=~"5.."}[1m]))
            /
            sum(rate(http_requests_total{app="product"}[1m]))
```

### Vì sao mục này nên xếp cuối danh sách ưu tiên
Đề bài yêu cầu Istio + Kiali cho phần nâng cao mesh (retry, mTLS, authorization policy),
**không yêu cầu** progressive delivery. Thêm Argo Rollouts đòi hỏi:

1. Cài thêm controller Argo Rollouts trên K3s (thêm workload chạy trên VM vốn đã căng
   tài nguyên theo `implementation-progress.md`).
2. Cài Prometheus để AnalysisTemplate có dữ liệu — nhưng đề bài mục 1 nói rõ **không
   cần triển khai Prometheus/Grafana** trong đồ án này. Làm mục này sẽ mâu thuẫn trực
   tiếp với phạm vi đề bài đã miễn trừ.

**Kết luận: bỏ qua mục này hoàn toàn cho đồ án**, chỉ nêu trong báo cáo như 1 phần
"hướng mở rộng nếu triển khai production thật" — không cần code, chỉ cần 1-2 đoạn phân
tích trong báo cáo để thể hiện hiểu biết.

---

## 6. Secret management: Sealed Secrets / External Secrets Operator

### Bản chất pattern
Repo GitOps public/semi-public không bao giờ chứa secret dạng plaintext, kể cả đã
base64 (base64 không phải mã hoá). Hai hướng phổ biến:

- **Sealed Secrets** (Bitnami): secret được mã hoá bằng public key của controller chạy
  trong cluster, chỉ cluster đó giải mã được. Commit `SealedSecret` (đã mã hoá) vào Git
  là an toàn.
- **External Secrets Operator**: secret thật nằm ngoài cluster (Vault, AWS Secrets
  Manager, GCP Secret Manager), Git chỉ chứa 1 `ExternalSecret` object tham chiếu tên
  secret, controller tự đồng bộ giá trị thật vào cluster.

### Đối chiếu với hiện trạng yas-cd
Theo `agent-task-assignment-prompt.md`, quy tắc hiện tại là "Do not commit real secrets,
tokens, kubeconfigs..." — đây là kỷ luật **quy trình** (con người tự giác không commit),
không phải kỷ luật **kỹ thuật** (hệ thống tự động chặn/mã hoá). Sự khác biệt quan trọng:
kỷ luật quy trình có thể bị phá vỡ bởi 1 lần sơ suất của bất kỳ ai trong 4 người; kỷ
luật kỹ thuật thì không.

### Cách làm tối thiểu phù hợp scope đồ án — Sealed Secrets

Đây là lựa chọn nhẹ nhất trong 2 hướng vì không cần thêm dịch vụ ngoài (Vault) — chỉ
thêm 1 controller nhỏ trong cluster:

```bash
# Cài controller (1 lần, trên GCP VM)
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.0/controller.yaml

# Mỗi khi cần thêm secret mới (VD: Keycloak admin password cho platform)
echo -n "supersecret" | kubectl create secret generic keycloak-admin \
  --dry-run=client --from-file=password=/dev/stdin -o yaml \
  | kubeseal --format yaml > platform/base/keycloak-admin-sealed.yaml

# Commit platform/base/keycloak-admin-sealed.yaml vào yas-cd — an toàn vì đã mã hoá
git add platform/base/keycloak-admin-sealed.yaml
git commit -m "cd(lab2): add sealed secret for keycloak admin"
```

File `keycloak-admin-sealed.yaml` chứa ciphertext, commit vào Git công khai vẫn an
toàn — chỉ controller trên đúng cluster GCP VM đó giải mã được.

### Giới hạn cho đồ án
Team đã ghi rõ trong `platform-infrastructure.md` rằng Keycloak/Postgres hiện tại là
"lab-local" — tức đây không phải hệ thống chứa dữ liệu thật cần bảo vệ dài hạn, chỉ
tồn tại trong vòng đời đồ án. Đầu tư Sealed Secrets **có giá trị demo tốt** (dễ trình
bày, kỹ thuật gọn) nhưng **giá trị bảo mật thực tế thấp** cho ngữ cảnh này. Xếp vào
P2 — làm nếu còn thời gian, có thể chỉ áp dụng cho 1-2 secret minh hoạ (không cần làm
toàn bộ) để có evidence trong báo cáo.

---

## 7. Policy as code: admission controller thay vì script chạy tay

### Bản chất pattern
`scripts/validate-staging-immutable.sh` hiện tại là **kiểm tra tại thời điểm commit**
(pre-commit/CI) — nếu ai đó bỏ qua bước này (quên chạy, hoặc `git commit --no-verify`),
hoặc nếu có thao tác `kubectl apply` trực tiếp vào cluster bỏ qua Git hoàn toàn, quy tắc
"staging chỉ dùng immutable tag" không còn được đảm bảo. Policy as code
(Kyverno/OPA Gatekeeper) kiểm tra **tại thời điểm apply vào cluster** — không thể bỏ
qua bằng bất kỳ cách nào, kể cả `kubectl apply` tay.

### Vì sao đây là lớp phòng thủ bổ sung quan trọng nhất trong toàn bộ danh sách
Nhìn lại `agent-task-assignment-prompt.md` mục "Hard Rules":

> "Do not use `kubectl set image`, `kubectl apply`, or `kubectl delete` directly in
> namespaces managed by ArgoCD: `dev`, `staging`, `developer`."

Đây lại là 1 quy tắc **dựa vào con người tự giác không làm sai**, không có gì ở tầng hạ
tầng chặn việc đó xảy ra. Nếu 1 trong 4 người, giữa lúc gấp deadline, chạy nhầm
`kubectl set image` để fix nhanh một lỗi ở staging, không có cơ chế nào ngăn — và điều
này sẽ khiến trạng thái cluster lệch khỏi Git (declared state drift), thứ mà toàn bộ
triết lý GitOps của đồ án dựa vào để hoạt động đúng.

### Cách làm tối thiểu — Kyverno policy chặn admission

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: staging-immutable-tag-only
spec:
  validationFailureAction: Enforce
  rules:
    - name: block-mutable-tag-in-staging
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["staging"]
      validate:
        message: "Staging namespace chỉ chấp nhận image tag dạng vX.Y.Z, không dùng main/latest/branch name."
        pattern:
          spec:
            containers:
              - image: "*:v?[0-9]*.[0-9]*.[0-9]*"
```

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-direct-kubectl-in-managed-namespaces
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-argocd-tracking-label
      match:
        any:
          - resources:
              kinds: ["Deployment"]
              namespaces: ["dev", "staging", "developer"]
      validate:
        message: "Resource trong namespace do ArgoCD quản lý phải có label app.kubernetes.io/instance — không được apply tay ngoài GitOps."
        pattern:
          metadata:
            labels:
              app.kubernetes.io/instance: "?*"
```

Policy thứ 2 tận dụng việc ArgoCD tự gắn label `app.kubernetes.io/instance` cho mọi
resource nó quản lý — resource nào thiếu label này (tức được apply tay, không qua
ArgoCD) sẽ bị admission controller chặn ngay từ đầu.

### Giới hạn cho đồ án
Cài Kyverno tốn thêm 1 controller chạy trên VM vốn đã căng tài nguyên (tương tự vấn đề
đã nêu ở mục Argo Rollouts). **Phương án rút gọn phù hợp hơn**: giữ nguyên
`validate-staging-immutable.sh`, nhưng nâng cấp từ "chạy tay trước khi commit" lên
"chạy tự động trong GitHub Action mỗi khi có PR vào `yas-cd`" — đây là bước rẻ hơn
nhiều (không tốn tài nguyên cluster) nhưng vẫn giải quyết được rủi ro lớn nhất: quên
chạy script trước khi commit.

```yaml
# .github/workflows/validate-gitops.yml (trong yas-cd)
name: Validate GitOps
on:
  pull_request:
    branches: [main]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install kustomize + yq
        run: |
          curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
          sudo mv kustomize /usr/local/bin/
      - run: scripts/validate-gitops.sh
      - run: scripts/validate-staging-immutable.sh
```

Việc này **không chặn được** `kubectl apply` tay trực tiếp vào cluster (chỉ Kyverno mới
làm được điều đó), nhưng chặn được lỗi phổ biến hơn nhiều trong ngữ cảnh 4 người cùng
sửa GitOps repo: quên chạy validate script trước khi merge PR.

---

## 8. Tổng kết mức độ ưu tiên áp dụng cho đồ án

| # | Pattern | Chi phí thêm | Giá trị cho đồ án | Khuyến nghị |
|---|---|---|---|---|
| 1 | Tách logic build/routing trong Jenkinsfile | Thấp | Cao — sửa đúng nợ kỹ thuật đang treo | **Làm** |
| 2 | Convention-based trigger, bỏ `DEPLOY_TO_DEVELOPER` | Thấp | Cao — đây là bug thật đang tồn tại | **Làm, ưu tiên cao nhất** |
| 3 | Build once, retag nhiều lần | Thấp | Trung bình — tối ưu tốc độ CI | Làm nếu dư thời gian |
| 4 | ApplicationSet thay 3 file YAML | Thấp | Thấp — 3 file cố định không phải vấn đề thật | Bỏ qua hoặc làm cho vui |
| 5 | Argo Rollouts canary | Cao (thêm controller + mâu thuẫn với việc đề bài miễn trừ Prometheus) | Thấp cho scope đồ án | **Bỏ qua**, chỉ viết phân tích trong báo cáo |
| 6 | Sealed Secrets | Trung bình | Trung bình — demo tốt, giá trị bảo mật thực tế thấp cho lab | Làm minh hoạ 1-2 secret nếu dư thời gian |
| 7 | GitHub Action chạy validate script tự động | Rất thấp | Cao — chặn lỗi con người quên chạy tay | **Làm** |
| 7b | Kyverno admission control đầy đủ | Cao (thêm controller) | Trung bình | Chỉ nêu trong báo cáo như hướng mở rộng |

Ba việc nên làm ngay (mục 1, 2, 7) đều là chi phí thấp và giải quyết đúng vấn đề thật
đang tồn tại trong repo — không phải thêm công cụ mới cho có, mà là sửa cách tổ chức
logic hiện có. Các mục còn lại nên dừng ở mức phân tích trong báo cáo, vì chi phí hạ
tầng thêm vào (đặc biệt là chạy thêm controller trên VM đơn 32GB đã căng theo ghi nhận
trong `implementation-progress.md`) không tương xứng với lợi ích cho 1 đồ án môn học.
