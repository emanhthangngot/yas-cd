# Agent Context — Lab 2 CD Cho YAS (Tổng Hợp Toàn Bộ Phiên Tư Vấn Kiến Trúc)

> File này tổng hợp toàn bộ kết luận, quyết định, và việc cần làm rút ra từ 1 phiên phân
> tích kiến trúc dài (đánh giá hiện trạng → kế hoạch hoàn thiện → so sánh production pattern
> → đọc chi tiết 2 repo mẫu). Mục đích: 1 agent (Claude Code/Codex) đọc file này là đủ ngữ
> cảnh để tiếp tục làm việc, không cần đọc lại toàn bộ lịch sử chat.
>
> Đặt file này tại: `docs/project02/agent-context-cd-improvement.md` trong `emanhthangngot/yas-cd`
> (hoặc `tzin1401/yas` nếu agent đang làm việc ở app repo). Đọc cùng với `context.md` và
> `current-handoff.md` đã có sẵn — file này KHÔNG thay thế 2 file đó, mà bổ sung phần
> "cải tiến kiến trúc" mà 2 file kia chưa có.

Cập nhật: 2026-07-05

---

## 0. Bối cảnh dự án (tóm tắt, xem đầy đủ ở `context.md`)

- Đồ án 2 môn DevOps (HCMUS), xây hệ thống CD cho microservices Java **YAS**.
- App/CI repo: `git@github.com:tzin1401/yas.git`. CD/GitOps repo:
  `git@github.com:emanhthangngot/yas-cd.git`.
- Hạ tầng: Jenkins Master trên AWS EC2 (`3.27.92.213`); 1 GCP VM (`gcp-ci-cd-agent`,
  32GB RAM) vừa làm Jenkins Agent vừa chạy K3s + ArgoCD + toàn bộ workload.
- 3 namespace: `dev` (auto), `staging` (release tag `vX.Y.Z`), `developer` (preview theo yêu
  cầu, hiện dormant theo policy).
- Scope service: 14 service theo `deployment-services-cq.pdf` (product, cart, order,
  customer, inventory, tax, media, search, storefront-bff/ui, backoffice-bff/ui, swagger-ui,
  sampledata) — các service khác của YAS gốc (delivery, location, payment-paypal, promotion,
  rating, recommendation, webhook) bị loại khỏi runtime demo để tiết kiệm tài nguyên VM đơn.
- Team: Trí Xuân (cluster/CD owner), Vinh Nhỏ (Jenkins/image owner), Vinh Bự (GitOps/
  security/report owner).

---

## 1. Nguồn tham chiếu đã dùng trong phiên phân tích này

1. Các file dự án gốc: `context.md`, `implementation-progress.md`,
   `platform-infrastructure.md`, `agent-task-assignment-prompt.md`, `cluster-runbook.md`,
   `final-plan-lab2-cd.md`, `Project02_HKII_25_26.md` (đề bài gốc), `deployment-services-cq.pdf`.
2. Đã clone và đọc trực tiếp 2 repo mẫu từ nhóm khác cùng làm đề tương tự:
   - `https://github.com/com-suon-bi-cha/gitops-manifest-k8s.git` — GitOps repo mẫu.
   - `https://github.com/com-suon-bi-cha/yas.git` — App repo mẫu (Jenkinsfile + scripts CD).
3. 3 tài liệu đã sinh ra trong phiên này (giữ lại làm chi tiết, file này chỉ tổng hợp):
   - `ke-hoach-hoan-thien-lab2-cd.md` — kế hoạch P0/P1/P2 tổng thể + timeline + evidence checklist.
   - `production-cicd-patterns-chi-tiet.md` — đào sâu 7 pattern CI/CD production, áp dụng cụ thể.
   - `phan-tich-repo-mau-va-cai-thien-yas-cd.md` — phân tích file-by-file 2 repo mẫu.

---

## 2. Nhận định kiến trúc tổng quát (đã chốt, không cần tranh luận lại)

Kiến trúc hiện tại của `yas-cd` + `tzin1401/yas` **đúng hướng, không dở**: GitOps chuẩn
(Jenkins build → push image → update tag GitOps → ArgoCD pull & sync), Kustomize base/
overlay, tách CD repo khỏi app repo, immutable tag cho staging. Vấn đề không nằm ở mô hình
tổng thể mà ở **cách tổ chức logic cụ thể bị cứng theo tình huống lab** (flag thủ công,
if/else dồn 1 chỗ, thiếu amortization khi thêm service/env mới). Không cần đổi kiến trúc gốc,
chỉ cần refactor có mục tiêu.

**Nguyên tắc chỉ đạo xuyên suốt mọi quyết định dưới đây:**
1. Ưu tiên nộp đúng hạn, đạt điểm đề bài — không over-engineer (bỏ qua Argo Rollouts/Vault/
   Kyverno đầy đủ, vì chi phí hạ tầng thêm không tương xứng lợi ích cho 1 đồ án môn học và
   đề bài đã miễn trừ Prometheus/Grafana).
2. Mọi thay đổi CD repo qua PR + `scripts/validate-gitops.sh` +
   `scripts/validate-staging-immutable.sh` xanh trước khi merge.
3. Không `kubectl apply/set image/delete` trực tiếp vào `dev`/`staging`/`developer` — mọi
   thay đổi runtime đi qua Git commit.
4. Không copy mù quáng từ repo mẫu — repo mẫu cũng có lỗi thật (xem mục 5).

---

## 3. Danh sách nợ kỹ thuật ĐANG TREO — phải xử lý trước, mức độ blocking

| # | Vấn đề | File liên quan | Việc cần làm |
|---|---|---|---|
| 1 | `main` của `tzin1401/yas` vẫn còn hành vi cũ `DEPLOY_TO_DEVELOPER=true`, branch/PR tắt behavior này chưa merge | Jenkinsfile chính của `tzin1401/yas` | Merge branch tắt behavior; tách hẳn logic developer-preview ra khỏi Jenkinsfile chính, chuyển thành job riêng `developer_build` (xem mục 4.1 — đã có code mẫu tham khảo thật) |
| 2 | Chưa xác nhận Jenkins multibranch đã bật "Discover tags" cho push `vX.Y.Z` | Cấu hình Jenkins Master job, không phải file trong repo | Vào Manage Jenkins → job config → Branch Sources → bật Discover tags; test bằng 1 tag thật |
| 3 | ArgoCD hiển thị `Progressing` dù mọi pod required đã `2/2 Running` | ArgoCD Applications `yas-dev`/`yas-staging` | Chạy `argocd app get` tìm resource cụ thể gây lệch health; nếu không fix được, ghi rõ nguyên nhân + evidence functional test vào báo cáo, không im lặng bỏ qua |
| 4 | Chưa chạy smoke test từ máy ngoài VM (chỉ mới test nội bộ) | `scripts/smoke-runtime-storefront.sh` | Chạy từ máy cá nhân trỏ `/etc/hosts` vào `GCP_VM_EXTERNAL_IP`, mở tạm firewall nếu cần, nhớ đóng lại sau |
| 5 | Chưa capture đầy đủ evidence platform infra (Postgres DB list, PVC Bound...) | `platform-infrastructure.md` mục 5 | Chạy block lệnh có sẵn, lưu output vào thư mục evidence |

---

## 4. Cải tiến kiến trúc — đã đối chiếu với repo mẫu, sắp theo độ ưu tiên

### 4.1. Tách `developer_build` thành job Jenkins riêng (ưu tiên cao nhất, đã có ví dụ thật)

**Quyết định:** xoá hẳn nhánh logic `DEPLOY_TO_DEVELOPER` khỏi Jenkinsfile chính của
`tzin1401/yas`. Tạo 1 Jenkins Parameterized Job riêng tên `developer_build`.

**Tham khảo trực tiếp:** `Jenkinsfile.developer-build` trong repo mẫu
`com-suon-bi-cha/yas` — cấu trúc: mỗi service 1 tham số string (`media`, `product`, `order`...,
default `main`), dùng `git ls-remote origin refs/heads/<branch>` để lấy commit 7 ký tự của
branch được chỉ định cho từng service, service nào để mặc định `main` thì dùng tag `latest`
(không rebuild lại). Có thêm stage "Print Access Info" tự dò `WORKER_IP` qua
`kubectl get nodes` và liệt kê bảng `SERVICE / PORT / URL` cho từng NodePort — nên copy
nguyên ý tưởng này để dev không phải tự tra `kubectl get svc`.

**KHÁC BIỆT QUAN TRỌNG CẦN GIỮ SO VỚI REPO MẪU:** repo mẫu bypass ArgoCD hoàn toàn cho
`developer-build` (`kubectl apply -k` trực tiếp trong `scripts/deploy-developer-build.sh`,
comment thẳng trong code: "bypass ArgoCD — faster for developer use"). **Quyết định: KHÔNG
copy phần bypass này.** Giữ `developer` dưới quyền ArgoCD như hiện tại
(`argocd/apps/yas-developer.yaml` đã tồn tại) — job `developer_build` chỉ nên commit thay đổi
vào `overlays/developer` trên `yas-cd`, để ArgoCD tự sync, không gọi `kubectl apply` trực
tiếp. Lý do: giữ nguyên tắc GitOps nhất quán cho cả 3 môi trường, đúng yêu cầu chấm điểm phần
ArgoCD nâng cao, và dễ giải thích khi bảo vệ đồ án hơn là phải giải thích 1 ngoại lệ.

**Job xoá deploy (mục 5 đề bài) theo cùng nguyên tắc:** không dùng `kubectl delete --all`
như `Jenkinsfile.cleanup` của repo mẫu. Thay bằng: commit thay đổi scale-to-0 hoặc xoá overlay
`developer` trên Git, để `argocd app sync yas-developer --prune` xử lý.

### 4.2. Staging chuyển sang sync thủ công trong ArgoCD (ưu tiên cao, chi phí gần 0)

**Phát hiện từ repo mẫu:** `argocd/yas-staging-app.yaml` của `gitops-manifest-k8s` **không
có** block `automated` trong `syncPolicy` — chỉ `dev` mới auto-sync + self-heal. Staging cần
`argocd app sync yas-staging` thủ công mới thực sự đổi cluster.

**Quyết định: áp dụng ngay.** Sửa `argocd/apps/yas-staging.yaml` trong `yas-cd`:
```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    # KHÔNG có automated: → cần chạy tay
```
**Lý do:** đây là 1 "release approval gate" gần như miễn phí (không cần Argo Rollouts,
không cần Prometheus, không vi phạm giới hạn đề bài) — dù đã push tag `vX.Y.Z` lên GitOps
repo, cluster staging không đổi cho tới khi có người chủ động xác nhận sync. Cập nhật kịch
bản demo cuối kỳ: thêm bước `argocd app sync yas-staging` sau khi push tag, biến đây thành
hành động có chủ đích khi trình bày.

### 4.3. Viết lại AuthorizationPolicy theo per-service SPIFFE principal (ưu tiên cao, đúng trọng tâm chấm điểm mesh)

**Phát hiện từ repo mẫu:** file `environments/dev/istio/authorization.yaml` định nghĩa 16
`AuthorizationPolicy`, mỗi service 1 policy riêng, dùng danh tính SPIFFE gắn ServiceAccount:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-to-product
spec:
  selector:
    matchLabels: { app: product }
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/dev/sa/storefront-bff
              - cluster.local/ns/dev/sa/backoffice-bff
              - cluster.local/ns/dev/sa/cart
              - cluster.local/ns/dev/sa/order
              - cluster.local/ns/dev/sa/inventory
              - cluster.local/ns/dev/sa/search
```

Nguyên tắc: chỉ đúng những service thực sự gọi tới `product` mới được liệt kê trong
`principals`; mọi service khác trong cùng namespace, dù cùng mesh/cùng mTLS, đều bị chặn ở
tầng L7. Điều này đòi hỏi mỗi service phải có `serviceAccountName` riêng (không dùng chung
`default`).

**Việc cần làm:**
1. Kiểm tra `AuthorizationPolicy` hiện tại của `yas-cd` — nếu đang là 1 policy rộng theo
   namespace (không phân biệt caller), viết lại theo per-service như trên.
2. Bản đồ dependency giữa các service **đã có sẵn**, không cần suy luận lại — lấy từ cột
   "Consumers / Dependent Services" trong `platform-infrastructure.md` mục 1, và từ chính
   route table BFF (`scripts/sync-gateway-routes.sh` hoặc ConfigMap route của BFF, xem mục
   4.4).
3. Áp dụng cẩn thận: dùng `action: ALLOW` với danh sách principal đầy đủ trước, test kỹ,
   tránh tự khoá traffic hợp lệ giữa lúc demo.
4. Áp dụng đồng thời cho cả `staging`, không chỉ `dev` (xem mục 4.5 — đây là điểm giúp
   `yas-cd` làm tốt hơn repo mẫu, chứ không chỉ bắt kịp).

### 4.4. Đơn giản hoá routing tầng mesh — có thể xoá hẳn `sync-gateway-routes.sh` (cần kiểm tra trước khi làm)

**Phát hiện từ repo mẫu:** `base/istio/virtualservice.yaml` chỉ có **2 nhánh route** dựa
theo Host header (`authority` match `backoffice` → route vào `backoffice-bff`/`backoffice-ui`;
mọi request khác → `storefront-bff`/`storefront-ui`). Toàn bộ định tuyến chi tiết theo từng
service (`/api/product`, `/api/cart`...) nằm trong **Spring Cloud Gateway config của chính
BFF** (ConfigMap `storefront-bff-config`), không nằm ở tầng Istio/K8s.

**So với `yas-cd` hiện tại:** đang duy trì route theo từng backend service ở tầng GitOps
(sinh bởi `scripts/sync-gateway-routes.sh` đọc từ `services.yaml`) — nghĩa là mỗi khi thêm/
bớt service phải đồng bộ tay giữa `services.yaml` và route YAML.

**Việc cần làm (kiểm tra trước, chưa chắc áp dụng được ngay):**
1. Kiểm tra `storefront-bff`/`backoffice-bff` trong `tzin1401/yas` đã có sẵn Spring Cloud
   Gateway route theo từng service trong `application.yml`/ConfigMap hay chưa (khả năng cao
   là có sẵn vì đây là kiến trúc chuẩn của dự án YAS gốc).
2. **Nếu có sẵn:** đơn giản hoá `base/istio/virtualservice.yaml` xuống 1-2 route theo Host/
   path prefix trỏ vào đúng 2 BFF; xoá các VirtualService per-backend-service hiện có; **xoá
   hẳn `scripts/sync-gateway-routes.sh`** và phần check tương ứng trong
   `scripts/validate-gitops.sh`.
3. **Nếu chưa có:** không làm mục này — giữ nguyên cơ chế hiện tại, ghi nhận đây là hướng cải
   tiến khả thi nhưng cần sửa cả ở tầng BFF (app repo), không chỉ ở CD repo.

### 4.5. Áp dụng mesh (mTLS/retry/authorization) cho cả `staging`, không chỉ `dev`

**Phát hiện:** repo mẫu **không có** bất kỳ file Istio nào cho `staging` — đây là điểm yếu
thật của repo mẫu (không đối xứng, dev có mesh đầy đủ nhưng staging thì không).

**Quyết định: `yas-cd` nên làm tốt hơn ở điểm này** — copy các file
`overlays/dev/istio/{mtls,retry,authorization}.yaml` sang `overlays/staging/istio/`, đổi
`namespace: dev` → `staging` trong mọi SPIFFE principal và host FQDN. Không tốn thêm hạ tầng,
chỉ thêm YAML. Đây là câu trả lời tốt nếu giảng viên hỏi "mesh áp dụng cho môi trường nào".

### 4.6. Thu hẹp phạm vi retry policy theo critical path (ưu tiên trung bình)

**Phát hiện:** repo mẫu chỉ áp `retries` cho 6-7 service nằm trên luồng đặt hàng chính
(product/cart/order/tax/payment/inventory), không áp toàn bộ 14 service.

**Việc cần làm:** kiểm tra retry policy hiện tại của `yas-cd` có đang áp toàn bộ hay chọn lọc
— nếu áp toàn bộ, thu hẹp lại theo đúng luồng nghiệp vụ chính. Lý do kỹ thuật: retry lan tràn
có thể che giấu lỗi thật và gây retry storm khi service downstream quá tải; chọn lọc theo
critical path vừa đúng kỹ thuật hơn, vừa dễ giải thích trong báo cáo.

### 4.7. Gộp patch throttle staging thành 1-2 patch JSON6902 dùng regex (ưu tiên trung bình)

**Phát hiện:** repo mẫu dùng 1 patch duy nhất set `replicas: 1` cho **mọi** Deployment bằng
`target.name: .*` (regex khớp tất cả), thay vì N file/PR riêng cho N service.

**Đối chiếu:** `yas-cd` xử lý qua 2 PR riêng (PR #13 CPU throttle, PR #14 maxSurge/
maxUnavailable) — nếu các PR này sửa từng file overlay riêng theo service, nên gộp lại:

```yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/strategy/rollingUpdate/maxSurge
        value: 0
      - op: replace
        path: /spec/strategy/rollingUpdate/maxUnavailable
        value: 1
    target:
      kind: Deployment
      name: .*
  - patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/cpu
        value: "250m"
    target:
      kind: Deployment
      name: .*
```

**Lợi ích:** thêm service mới vào staging tự động thừa hưởng đúng chính sách throttle, không
cần nhớ thêm patch riêng.

### 4.8. Build once, retag nhiều lần thay vì rebuild theo từng loại trigger (ưu tiên trung bình — vượt qua cả repo mẫu)

**Lưu ý quan trọng:** cả `yas-cd`/`tzin1401/yas` **và** repo mẫu đều chưa làm đúng pattern
này — `Jenkinsfile.ci` của repo mẫu vẫn rebuild toàn bộ khi phát hiện tag release
(`buildAllImages = GIT_TAG_MATCH || GLOBAL_IMPACT`). Đây là điểm mà `yas-cd` có thể **vượt
qua** chất lượng của repo mẫu, không chỉ bắt kịp.

**Việc cần làm:** khi tạo tag `vX.Y.Z` từ 1 commit đã từng build thành công trên `main`
(image tag = short-commit-id đã tồn tại trên Docker Hub), dùng
`docker buildx imagetools create -t <registry>/<service>:<tag> <registry>/<service>:<commit-id>`
để retag thay vì `docker build` lại từ đầu. Chỉ áp dụng nếu quy trình release luôn tạo tag từ
commit đã qua CI trên `main` — nếu team cho phép tạo tag từ nhánh riêng chưa merge, giữ
rebuild là hợp lý.

### 4.9. Cơ chế dự phòng phát hiện tag bằng chính Git (bổ sung, không thay thế việc bật Discover Tags)

**Phát hiện từ repo mẫu:** `Jenkinsfile.ci` không chỉ dựa vào `env.TAG_NAME` (biến Jenkins
set khi multibranch phát hiện tag), mà còn tự chạy
`git tag --points-at HEAD | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+'` ngay trong pipeline để xác
nhận độc lập. Đây là lớp phòng thủ kép hữu ích, nên thêm vào hàm `resolveTargetEnv` (xem mục
4.1) làm cơ chế dự phòng — không thay thế việc phải bật đúng "Discover tags" ở cấu hình
Jenkins multibranch (mục 3, dòng #2).

---

## 5. Danh sách "ĐÃ QUYẾT ĐỊNH GIỮ NGUYÊN — không bắt chước repo mẫu"

Repo mẫu không phải chuẩn mực tuyệt đối — có những chỗ `yas-cd` đang làm **tốt hơn**, hoặc có
những trade-off của repo mẫu không phù hợp với mục tiêu chấm điểm của đồ án này:

1. **Không bypass ArgoCD cho `developer`** (xem mục 4.1) — giữ nguyên tắc GitOps nhất quán.
2. **Giữ `services.yaml` làm nguồn sự thật duy nhất cho danh sách service** — repo mẫu rải
   danh sách service ở 4 chỗ không hoàn toàn khớp nhau (README liệt kê 19, `base/
   kustomization.yaml` chỉ wire 15, `developer-build/kustomization.yaml` liệt kê tag cho cả
   19 kể cả 5 service không tồn tại trong base, và `scripts/update-gitops-manifest.sh` có
   1 mảng bash riêng khai cứng 14 service) — đây là "nhiều nguồn sự thật" đúng loại vấn đề
   `yas-cd` đang tránh bằng `services.yaml` + `validate-gitops.sh`.
3. **Giữ kiến trúc `platform` namespace dùng chung cho cả 3 môi trường** (Postgres/Redis/
   Kafka/ES/Keycloak 1 bản duy nhất) — repo mẫu tách riêng Postgres/Kafka/ES cho mỗi
   `dev`/`staging` (chỉ `developer-build` mới dùng chung của `dev`), tốn RAM hơn đáng kể trên
   cùng cấu hình VM đơn. Kiến trúc của `yas-cd` tối ưu tài nguyên tốt hơn, đúng ràng buộc thực
   tế.
4. **Không copy plaintext password trong Deployment YAML** — `base/product/deployment.yaml`
   của repo mẫu có `SPRING_DATASOURCE_PASSWORD: "password"` viết thẳng, đây là lỗi bảo mật
   thật. `yas-cd` đã có `validate-gitops.sh` kiểm tra "secret-like pattern" — cần xác nhận
   không có trường hợp tương tự lọt qua, không học theo cách làm này.
5. **Không dọn kiểu "để lại folder/file chết"** — repo mẫu có 7 folder service không được
   wire vào `base/kustomization.yaml` (`delivery`, `location`, `payment-paypal`, `promotion`,
   `rating`, `recommendation`, `webhook`) và 1 file patch thừa
   (`environments/developer-build/patches/use-dev-infra.yaml`) không được tham chiếu ở đâu cả
   — gây nhiễu khi đọc code. `yas-cd` xoá thẳng khỏi `services.yaml` khi cắt scope (PR #11),
   sạch hơn — tiếp tục giữ thói quen này, rà soát không để sót file/overlay chết sau mỗi lần
   refactor.

---

## 6. Kế hoạch hành động tổng hợp theo thứ tự ưu tiên

### P0 — Bắt buộc, blocking, làm trước
1. Merge branch tắt `DEPLOY_TO_DEVELOPER` vào `main` của `tzin1401/yas` (mục 3.1).
2. Xác nhận Jenkins multibranch bật "Discover tags", test bằng 1 tag thật (mục 3.2).
3. Điều tra + xử lý/ghi nhận nguyên nhân ArgoCD `Progressing` (mục 3.3).
4. Chạy smoke test từ máy ngoài VM (mục 3.4).
5. Capture đầy đủ evidence platform infra (mục 3.5).

### P1 — Refactor kiến trúc, chi phí thấp, giá trị cao (làm sau P0)
6. Tách `developer_build` thành job riêng, tham khảo cấu trúc tham số từ
   `Jenkinsfile.developer-build` của repo mẫu, **nhưng giữ ArgoCD** thay vì bypass (mục 4.1).
7. Staging chuyển sang sync thủ công trong ArgoCD (mục 4.2).
8. Viết lại AuthorizationPolicy theo per-service SPIFFE principal (mục 4.3).
9. Mở rộng mesh (mTLS/retry/authorization) sang `staging` (mục 4.5).
10. Gộp patch throttle staging thành patch regex dùng chung (mục 4.7).

### P2 — Cần kiểm tra trước, làm nếu điều kiện đúng và còn thời gian
11. Kiểm tra BFF đã có Spring Cloud Gateway route sẵn chưa → nếu có, đơn giản hoá routing
    mesh và xoá `sync-gateway-routes.sh` (mục 4.4).
12. Kiểm tra "Monorepo Path Filter" của Lab 1 có tính thay đổi ở `pom.xml`/`common-library`
    hay chỉ path trực tiếp từng service — vá nếu thiếu (rủi ro bug âm thầm).
13. Thu hẹp retry policy theo critical path nếu hiện đang áp toàn bộ (mục 4.6).
14. Build once + retag qua `imagetools create` thay vì rebuild khi release tag (mục 4.8).
15. Thêm cơ chế dự phòng phát hiện tag bằng `git tag --points-at HEAD` (mục 4.9).

### Việc đã có trong kế hoạch trước, không lặp lại chi tiết (xem `ke-hoach-hoan-thien-lab2-cd.md`)
- Toàn bộ checklist evidence cuối kỳ, kịch bản demo, bảng rủi ro/phương án dự phòng.
- Rollback job, teardown job (P2 trong kế hoạch gốc).
- Việc **không làm**: Argo Rollouts/canary, ApplicationSet (giá trị thấp với đúng 3 env cố
  định), Vault/Sealed Secrets đầy đủ, Kyverno admission control đầy đủ — chỉ nêu trong báo
  cáo như hướng mở rộng, không code.

---

## 7. Câu hỏi/tình huống cần chuẩn bị khi bảo vệ đồ án

1. **"Vì sao không bypass ArgoCD cho developer như 1 số nhóm khác?"** → Giữ nguyên tắc GitOps
   nhất quán cho cả 3 môi trường là lựa chọn có chủ đích, đánh đổi vài chục giây tốc độ lấy
   tính nhất quán + khả năng self-heal, đúng yêu cầu đề bài về ArgoCD quản lý `dev`/`staging`/
   `developer`.
2. **"AuthorizationPolicy của nhóm bạn chi tiết tới mức nào?"** → sau khi làm mục 4.3: "áp
   dụng least-privilege theo từng cặp service dùng SPIFFE identity, dựa trên bản đồ
   dependency đã định nghĩa trong `platform-infrastructure.md`".
3. **"Mesh có áp dụng cho staging không?"** → sau khi làm mục 4.5: "có, đồng nhất cho cả dev
   và staging" — đây là điểm làm tốt hơn 1 số repo tham khảo khác chỉ áp mesh cho dev.
4. **"Staging có gate gì trước khi release không?"** → sau khi làm mục 4.2: "staging dùng
   ArgoCD sync thủ công thay vì auto-sync, nên dù Jenkins đã cập nhật tag, cluster chỉ đổi khi
   có người xác nhận sync — đóng vai trò approval gate tối thiểu mà không cần thêm hạ tầng
   progressive delivery".

---

## 8. File/thư mục cụ thể sẽ bị động tới (tra cứu nhanh cho agent)

**Trong `emanhthangngot/yas-cd`:**
- `argocd/apps/yas-staging.yaml` — xoá block `automated` (mục 4.2).
- `argocd/apps/yas-developer.yaml` — giữ nguyên, không xoá, không thêm bypass.
- `overlays/dev/istio/` (hoặc tương đương) — nguồn để copy sang staging (mục 4.5).
- `overlays/staging/istio/` — tạo mới nếu chưa có (mục 4.5).
- File mesh policy AuthorizationPolicy — viết lại chi tiết theo per-service (mục 4.3).
- Overlay patch throttle staging (liên quan PR #13, #14) — gộp lại (mục 4.7).
- `scripts/sync-gateway-routes.sh`, `scripts/validate-gitops.sh` — khả năng xoá bớt phần
  check route nếu mục 4.4 được xác nhận khả thi.
- `docs/project02/cluster-runbook.md` — thêm lệnh "đếm resource" nhanh kiểu README repo mẫu.

**Trong `tzin1401/yas`:**
- Jenkinsfile chính — xoá `DEPLOY_TO_DEVELOPER`, refactor theo `resolveTargetEnv` (mục 3.1,
  4.1).
- Job Jenkins mới `developer_build` (Parameterized Job, không phải file trong repo — cấu hình
  trực tiếp trên Jenkins, có thể lưu bản sao Jenkinsfile tham khảo trong repo dạng
  `Jenkinsfile.developer-build` giống repo mẫu để dễ review).
- `storefront-bff`/`backoffice-bff` — kiểm tra route config Spring Cloud Gateway (mục 4.4,
  cần làm trước khi quyết định có xoá `sync-gateway-routes.sh` hay không).
- Logic "Monorepo Path Filter" của Lab 1 — kiểm tra có tính `pom.xml`/`common-library` không
  (mục P2 #12).
- Stage Docker Build & Push trong Jenkinsfile chính — thêm logic retag qua
  `docker buildx imagetools create` cho luồng release tag (mục 4.8).
