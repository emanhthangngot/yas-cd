# Phân Tích Kiến Trúc 2 Repo Mẫu Và Áp Dụng Cải Thiện Cho yas-cd

Repo đã clone và đọc trực tiếp (không suy đoán từ mô tả):
- `com-suon-bi-cha/gitops-manifest-k8s` — GitOps repo mẫu (tương đương `yas-cd` của bạn).
- `com-suon-bi-cha/yas` — App repo mẫu (tương đương `tzin1401/yas`), phần liên quan:
  5 Jenkinsfile + `scripts/update-gitops-manifest.sh` + `scripts/deploy-developer-build.sh`.

Tài liệu này đọc **từng file, từng folder thật** của 2 repo trên, không phải diễn giải chung
chung. Mỗi mục có: nội dung file → phân tích ý đồ thiết kế → đối chiếu với `yas-cd`/`tzin1401/yas`
→ khuyến nghị áp dụng (có/không/áp dụng có sửa).

---

## PHẦN 1 — `gitops-manifest-k8s` (GitOps repo mẫu)

### Cấu trúc tổng thể

```
gitops-manifest-k8s/
├── README.md
├── argocd/
│   ├── yas-dev-app.yaml
│   └── yas-staging-app.yaml
├── base/
│   ├── kustomization.yaml
│   ├── _common/
│   │   ├── identity-service.yaml
│   │   └── namespace-default.yaml
│   ├── istio/
│   │   ├── gateway.yaml
│   │   └── virtualservice.yaml
│   └── <22 thư mục service>/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── serviceaccount.yaml
└── environments/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── istio/{mtls,retry,authorization}.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── developer-build/
        ├── kustomization.yaml
        ├── dev-infra-destinationrules.yaml
        └── patches/ (15 file)
```

Đây là kiến trúc **Kustomize base/overlay chuẩn**, cùng triết lý với `yas-cd` của bạn
(`base/`, `overlays/dev`, `overlays/staging`, `overlays/developer`) — khác biệt chính nằm ở
**cách chia nhỏ trách nhiệm trong từng file**, không phải khác biệt về mô hình tổng thể.

---

### 1.1. `README.md`

Nội dung: bảng liệt kê 19 service + port + tên image, lệnh validate
(`kubectl kustomize environments/dev | grep "kind: Deployment" | wc -l` phải ra đúng số),
hướng dẫn Jenkins update tag bằng `kustomize edit set image`, và quy trình 5 bước
"Add A New Service".

**Điểm hay đáng học:**
- Lệnh validate bằng cách **đếm resource kind** (`grep "kind: Deployment" | wc -l`) là cách
  kiểm tra nhanh, không cần script riêng, chạy được ngay trong README — rẻ hơn nhiều so với
  viết hẳn `scripts/validate-gitops.sh` cho việc đơn giản là "đếm đúng số Deployment mong đợi".
- Mục "Add A New Service" là **runbook 5 bước tường minh** — bất kỳ ai trong team cũng làm
  theo được mà không cần hỏi lại người viết gốc.

**Điểm yếu cần lưu ý (không nên copy y nguyên):**
- README ghi "19 services" và liệt kê đủ 19, nhưng thực tế `base/kustomization.yaml`
  (xem mục 1.3) chỉ wire 15 service — **README không khớp với kustomization.yaml thật**. Đây
  là lỗi tài liệu-thực-tế lệch nhau, đúng loại lỗi mà `yas-cd` của bạn cũng đang cố tránh
  bằng `scripts/validate-gitops.sh`.

**Khuyến nghị cho `yas-cd`:** giữ nguyên `validate-gitops.sh` (đã tốt hơn README thuần của
repo mẫu), nhưng bổ sung thêm đúng 4 dòng lệnh "đếm resource" kiểu README này vào cuối
`docs/project02/cluster-runbook.md` như 1 lớp kiểm tra nhanh bằng mắt, không thay thế script.

---

### 1.2. `argocd/` — chỉ có 2 file, không có file cho `developer-build`

**`yas-dev-app.yaml`:**
```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
→ `dev` auto-sync + self-heal đầy đủ, đúng kỳ vọng môi trường "luôn phản ánh main".

**`yas-staging-app.yaml`:**
```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```
→ **Không có block `automated`** — nghĩa là staging **sync thủ công** (phải bấm Sync trên
ArgoCD UI hoặc gọi `argocd app sync yas-staging`), không tự động, không self-heal.

**Đây là phát hiện quan trọng nhất của toàn bộ repo mẫu này.** Để staging sync thủ công là
1 **approval gate tự nhiên**: dù Jenkins đã commit tag mới vào `environments/staging`, cluster
không đổi cho tới khi có người bấm Sync. Đây chính là kiểu "gate trước khi lên môi trường
giống production" mà kế hoạch trước của bạn liệt vào nhóm "progressive delivery" (Argo
Rollouts, phần bạn đã quyết định bỏ qua vì đụng Prometheus) — nhưng ArgoCD **đã có sẵn** 1
cách làm gate rẻ hơn nhiều: chỉ cần **không bật `automated` sync** cho Application đó.

**So với `yas-cd` hiện tại:** theo `cluster-runbook.md`, cả `yas-dev`, `yas-staging`,
`yas-developer` đều được `argocd app wait --health --sync` như nhau, ngụ ý cả 3 đều auto-sync.
Không có gate nào giữa lúc Jenkins push commit và lúc staging thực sự đổi.

**Khuyến nghị cho `yas-cd` — làm ngay, chi phí gần bằng 0:**
```yaml
# argocd/apps/yas-staging.yaml — chỉ xoá block automated, giữ nguyên còn lại
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    # KHÔNG có automated: → cần argocd app sync yas-staging thủ công
```
Cập nhật kịch bản demo (mục 7 trong bản kế hoạch trước): sau khi push tag `vX.Y.Z`, thêm 1
bước "chạy `argocd app sync yas-staging`" — biến đây thành 1 hành động có chủ đích, đúng
tinh thần "release cần người xác nhận" mà không cần cài thêm bất kỳ công cụ nào.

**Vì sao không có `yas-developer-app.yaml`:** vì `developer-build` **không được ArgoCD quản
lý** trong repo mẫu — xem phân tích ở mục 1.4c và mục 2.3, Jenkins gọi `kubectl apply -k`
trực tiếp, bỏ qua ArgoCD hoàn toàn cho môi trường này.

---

### 1.3. `base/` — chia theo folder-per-service, 3 file cố định mỗi service

**`base/kustomization.yaml`:** file trung tâm, liệt kê thủ công từng file resource theo comment
phân nhóm (`# product`, `# order`...). Có 1 phát hiện quan trọng:

```
Folder tồn tại trong base/ (22 service): backoffice-bff, backoffice-ui, cart, customer,
  delivery, inventory, location, media, order, payment, payment-paypal, product, promotion,
  rating, recommendation, sampledata, search, storefront-bff, storefront-ui, swagger-ui, tax,
  webhook

Service THỰC SỰ được wire vào base/kustomization.yaml (15 service):
  media, product, order, inventory, payment, sampledata, customer, cart, tax, search,
  backoffice-bff, storefront-bff, storefront-ui, backoffice-ui, swagger-ui
```

Tức là **7 folder tồn tại nhưng chết** (`delivery`, `location`, `payment-paypal`, `promotion`,
`rating`, `recommendation`, `webhook`) — có đủ 3 file `deployment.yaml`/`service.yaml`/
`serviceaccount.yaml` nhưng không nằm trong resource list nào cả, không bao giờ được
`kustomize build` render ra. Đây **chính xác là cùng 1 quyết định "cắt scope demo"** mà nhóm
bạn đã làm ở CD repo PR #11 (`services.yaml` catalog giữ 14 service theo
`deployment-services-cq.pdf`) — 2 nhóm độc lập đi đến cùng 1 giải pháp cho cùng 1 ràng buộc
tài nguyên VM đơn. Điều này củng cố thêm là hướng cắt scope của nhóm bạn **đúng hướng**,
không phải "dở" — chỉ là cách nhóm bạn làm gọn hơn (xoá hẳn khỏi `services.yaml`, không để
folder chết).

**Khuyến nghị cho `yas-cd`:** giữ cách làm hiện tại của bạn (xoá khỏi `services.yaml`) — nó
sạch hơn repo mẫu này, vì repo mẫu để lại 7 folder chết không dọn, gây nhiễu khi người mới
đọc code (dễ tưởng nhầm 7 service đó có chạy).

**`base/_common/identity-service.yaml`:** 1 `Service` tên `identity`, `selector` trỏ vào
label chuẩn `app.kubernetes.io/name: keycloak` — đây là 1 **Service alias nội bộ trong cùng
namespace** (khác với `yas-cd` dùng `ExternalName` xuyên namespace). Nghĩa là repo mẫu này
**không tách Keycloak ra 1 namespace `platform` dùng chung** như `yas-cd` — mỗi namespace
(`dev`, `staging`, `developer-build`) có Keycloak **riêng của mình**, chỉ alias tên Service
cho gọn.

**Đối chiếu kiến trúc — đây là khác biệt quan trọng thứ 2 giữa 2 repo:**

| | `yas-cd` (của bạn) | `gitops-manifest-k8s` (mẫu) |
|---|---|---|
| Vị trí Keycloak/Postgres/Redis/Kafka/ES | 1 namespace `platform` dùng chung cho cả 3 env | Mỗi namespace tự có bản riêng (dev/staging), `developer-build` mới dùng chung của `dev` |
| Cách trỏ tên | `ExternalName` xuyên namespace (`identity.dev.svc` → `identity.keycloak.svc`) | Trong `dev`/`staging`: Service thường cùng namespace. Chỉ `developer-build` mới cần `ExternalName` trỏ sang `dev` |
| Tiết kiệm tài nguyên | Tối đa — chỉ 1 bản Postgres/Kafka/ES cho cả dev+staging | Kém hơn — dev và staging mỗi bên có Postgres/Kafka/ES riêng |
| Cô lập dữ liệu giữa dev/staging | Không cô lập (dùng chung DB instance, khác database name) | Cô lập hoàn toàn (khác instance) |

Đây là 1 trade-off thật, không phải ai đúng ai sai: `yas-cd` tối ưu tài nguyên tối đa (đúng
nhu cầu VM đơn 32GB đang chạy nhiều thứ), repo mẫu tối ưu cô lập dữ liệu (an toàn hơn nếu
staging cần test độc lập không ảnh hưởng dev) nhưng tốn RAM hơn — rủi ro OOM cao hơn trên
cùng cấu hình VM. **Giữ nguyên cách của `yas-cd`** — đúng với ràng buộc tài nguyên thực tế
bạn đang có, không cần đổi.

**`base/istio/gateway.yaml` + `virtualservice.yaml`:** đây là phát hiện kiến trúc quan trọng
thứ 3. Toàn bộ file `virtualservice.yaml` chỉ định tuyến theo **2 nhánh duy nhất dựa vào
Host header** (`authority` match `^backoffice(:18080)?$` → route vào `backoffice-bff`/
`backoffice-ui`; mọi request còn lại → `storefront-bff`/`storefront-ui`). Tầng mesh **không
biết** và **không cần biết** danh sách đầy đủ 14 backend service — nó chỉ route tới đúng 2
BFF, phần định tuyến `/api/product`, `/api/cart`... theo từng service **nằm hoàn toàn trong
Spring Cloud Gateway config của chính BFF** (xem `storefront-bff-config` ConfigMap ở mục 1.4c).

**So với `yas-cd`:** theo `implementation-progress.md`, bạn đang duy trì
`scripts/sync-gateway-routes.sh` sinh route **ở tầng GitOps/gateway** cho từng service
(product, location, inventory, cart, customer, media, rating, payment...) đọc từ
`services.yaml` — tức là route theo service nằm ở tầng hạ tầng (K8s/Gateway), phải đồng bộ
tay mỗi khi thêm/bớt service.

**Đây chính là cách giảm coupling triệt để hơn nữa** so với đề xuất "đồng bộ tay" ở tài liệu
trước — thay vì đồng bộ 2 nguồn sự thật (services.yaml ở app repo ↔ route YAML ở CD repo),
**chuyển hẳn trách nhiệm định tuyến per-service vào code của BFF** (đã sẵn có trong app repo
dưới dạng Spring Cloud Gateway `application.yml`), tầng Istio/K8s chỉ cần biết đúng 2 điểm
vào (2 BFF) và không đổi khi thêm bớt backend service.

**Khuyến nghị cho `yas-cd` (đáng làm, độ ưu tiên cao, chi phí thấp — sửa lại đánh giá ở tài
liệu trước):**
1. Kiểm tra `storefront-bff`/`backoffice-bff` trong `tzin1401/yas` đã có Spring Cloud Gateway
   route config theo từng service trong `application.yml`/`ConfigMap` hay chưa (khả năng cao
   là có sẵn, vì đây là kiến trúc chuẩn BFF của chính dự án YAS gốc).
2. Nếu có sẵn: đơn giản hoá `base/istio/virtualservice.yaml` của `yas-cd` xuống còn 1-2
   route theo Host/path prefix trỏ vào đúng 2 BFF, xoá các VirtualService per-backend-service
   hiện có.
3. `scripts/sync-gateway-routes.sh` khi đó **không cần tồn tại nữa** — xoá hẳn, không phải
   chỉ "giảm coupling" như đề xuất trước, mà **loại bỏ hoàn toàn nguồn đồng bộ tay này**.
4. Đây là thay đổi có giá trị kiến trúc thật (giảm 1 script + 1 nguồn lỗi tiềm ẩn), nên nâng
   độ ưu tiên của mục "route generation" từ P1 lên gần P0 trong kế hoạch tổng.

**`base/<service>/deployment.yaml` (ví dụ `product`):** cấu trúc 3 file chuẩn
(`deployment.yaml`, `service.yaml`, `serviceaccount.yaml`) — giống hệt cách `yas-cd` tổ chức
theo service. Điểm đáng chú ý (và **là 1 lỗi bảo mật thật** trong repo mẫu, không nên copy):

```yaml
env:
  - name: SPRING_DATASOURCE_PASSWORD
    value: "password"        # ← plaintext trong Deployment YAML, commit thẳng vào Git
```

Đây đúng là loại vấn đề mục "Secret management" trong tài liệu trước đã cảnh báo (Sealed
Secrets/ExternalSecret) — repo mẫu này **không áp dụng khuyến nghị đó**, để lộ rõ hậu quả cụ
thể: password Postgres nằm trần trong Git history mãi mãi cho ai đọc repo cũng thấy.
**Không copy chi tiết này** — nếu `yas-cd` hiện đang làm tương tự (đặt password trực tiếp
trong Deployment env, dù đã có `scripts/validate-gitops.sh` kiểm tra "secret-like pattern"
theo `context.md`), đây là bằng chứng cụ thể nên ưu tiên áp dụng Sealed Secrets sớm hơn dự
kiến, ít nhất cho biến này.

Điểm khác đáng học: `serviceAccountName: product` có **comment giải thích lý do ngay tại chỗ**
(`# BẮT BUỘC — TV4 dùng cho AuthorizationPolicy`) — 1 dòng comment nhỏ nhưng giúp người đọc
sau này không lỡ tay xoá field tưởng thừa. **Nên áp dụng**: thêm comment tương tự vào
`base/<service>/deployment.yaml` của `yas-cd` ở field `serviceAccountName`.

---

### 1.4. `environments/` — đây là phần khác biệt lớn nhất, đáng học nhiều nhất

#### 1.4a. `environments/dev/kustomization.yaml`

```yaml
namespace: dev
resources:
- ../../base
- istio/mtls.yaml
- istio/retry.yaml
- istio/authorization.yaml
labels:
- includeSelectors: true
  pairs:
    environment: dev
images:
- name: bingsu1103/product
  newTag: latest
...
```

Hai điểm kỹ thuật Kustomize đáng chú ý:

1. **`labels` với `includeSelectors: true`** (Kustomize field hiện đại, thay cho
   `commonLabels` cũ đã deprecated) — tự động thêm `environment: dev` vào **cả**
   `metadata.labels`, `spec.selector.matchLabels`, và `spec.template.metadata.labels` của
   mọi resource, đảm bảo Service vẫn chọn đúng Pod sau khi gắn thêm label, không cần sửa tay
   từng nơi. Nếu `yas-cd` đang dùng `commonLabels` (cú pháp cũ) trong overlay, nên chuyển
   sang `labels` + `includeSelectors: true` — cú pháp cũ vẫn chạy được ở Kustomize hiện tại
   nhưng đã deprecated, cú pháp mới an toàn hơn khi cả selector và label cùng cần đồng bộ.

2. **`images:` transformer để set tag mỗi service** — đây là cơ chế mà Jenkins gọi
   `kustomize edit set image <image>=<image>:<tag>` để sửa **đúng 1 dòng** trong file này mỗi
   lần deploy, không phải sửa trực tiếp `deployment.yaml` trong `base/`. Đây to hơn 1 chi tiết
   kỹ thuật — nó là **cơ chế tách "cái gì chạy" (base) khỏi "phiên bản nào đang chạy" (overlay
   images list)**, để Jenkins chỉ cần biết sửa 1 dòng, không cần hiểu cấu trúc YAML phức tạp
   của Deployment.

**Đối chiếu với `yas-cd`:** cần kiểm tra lại `overlays/dev/kustomization.yaml` thật của bạn —
nếu đã dùng đúng `images:` transformer (nhiều khả năng có, vì `scripts/update-image-tag.sh`
được mô tả là "contract để Jenkins cập nhật image tag qua GitOps" trong `context.md`), thì
cơ chế tương đương đã tồn tại, chỉ cần xác nhận có dùng cú pháp `images:` chuẩn của Kustomize
hay đang tự chế bằng `sed`/`yq` chỉnh trực tiếp — nếu là tự chế, nên chuyển sang
`kustomize edit set image` chuẩn (an toàn hơn, ít lỗi parse YAML hơn tự viết `sed`).

#### 1.4b. `environments/dev/istio/{mtls,retry,authorization}.yaml`

**`mtls.yaml`:** 1 `PeerAuthentication` STRICT namespace-wide + 14 `DestinationRule` (mỗi
service 1 cái, tất cả set `tls.mode: ISTIO_MUTUAL`). Về mặt kỹ thuật, khi `PeerAuthentication`
đã STRICT namespace-wide, `DestinationRule` per-service với `ISTIO_MUTUAL` **thường là dư
thừa** (Istio tự áp `ISTIO_MUTUAL` cho traffic trong mesh khi STRICT mTLS đã bật) — 14 file
DestinationRule này giống như "khai báo lại cho chắc" hơn là bắt buộc về mặt kỹ thuật. Không
sai, nhưng hơi thừa dòng code — **có thể là chủ đích để mỗi service có 1 file evidence riêng
dễ chụp khi báo cáo**, nếu vậy thì hợp lý cho mục tiêu "trình bày", không phải best practice
kỹ thuật thuần tuý.

**`retry.yaml`:** đúng 7 `VirtualService` (product/cart/order/tax/payment/inventory) mỗi cái
định nghĩa `retries: attempts: 3, retryOn: 5xx,reset,connect-failure,retriable-4xx`. Đáng chú
ý: **không phải toàn bộ 14 service đều có retry** — chỉ 6 service nằm trên đường flow đặt
hàng chính (product → cart → order → tax/payment/inventory). Đây là chọn lọc có chủ đích:
retry không miễn phí (tăng latency khi service downstream thật sự lỗi), chỉ áp cho service
nằm trên critical path đáng được bảo vệ. **Khuyến nghị**: nếu `yas-cd` đang áp retry đồng
loạt cho mọi service, cân nhắc thu hẹp lại theo đúng critical path như repo mẫu — vừa đúng
kỹ thuật hơn (retry lan tràn có thể che giấu lỗi thật, gây retry storm khi service downstream
quá tải), vừa dễ giải thích trong báo cáo ("chúng tôi chọn lọc theo critical path, không phải
áp bừa").

**`authorization.yaml`:** đây là file **giá trị kỹ thuật cao nhất** trong toàn bộ repo mẫu.
Thay vì 1 `AuthorizationPolicy` chung chung theo namespace, file này định nghĩa **least-
privilege theo từng cặp service gọi nhau**, dùng SPIFFE principal gắn với đúng
`ServiceAccount`:

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

Điều này nghĩa là: **chỉ đúng 6 service được liệt kê mới gọi được `product`**, mọi service
khác trong cùng namespace (dù cùng mesh, cùng mTLS) đều bị Istio chặn ở tầng L7 nếu cố gọi
`product`. Đây là lý do vì sao `serviceAccountName: <tên-service>` trong `deployment.yaml`
"BẮT BUỘC" — principal SPIFFE được suy ra trực tiếp từ ServiceAccount, không có ServiceAccount
riêng, không thể viết policy least-privilege kiểu này.

Có 16 `AuthorizationPolicy` trong file — mỗi service quan trọng 1 policy riêng, cộng thêm
chính sách cho hạ tầng dùng chung (`allow-to-keycloak`, `allow-to-postgres`, `allow-to-redis`,
`allow-to-kafka`, `allow-to-elasticsearch`) chỉ cho phép namespace `dev`+`developer-build`
truy cập (staging bị chặn truy cập platform của dev, hợp lý vì staging phải có platform
riêng theo mục 1.3).

**Đối chiếu với `yas-cd`:** `implementation-progress.md` ghi mesh "Done — STRICT mTLS, retry,
và AuthorizationPolicy đã verify hoạt động", nhưng **không rõ mức độ chi tiết** —cần bạn tự
kiểm tra lại `overlays/dev` (hoặc file mesh runbook) xem `AuthorizationPolicy` hiện tại là
1 policy rộng theo namespace, hay đã chi tiết per-service-pair như repo mẫu này.

**Khuyến nghị cụ thể — đây là điểm nâng cấp giá trị điểm số cao nhất tìm được trong toàn bộ
phân tích này:**
1. Nếu `AuthorizationPolicy` hiện tại của `yas-cd` là namespace-wide/coarse-grained, hãy
   viết lại theo per-service dùng SPIFFE principal như file mẫu này — đây chính xác là điều
   giảng viên chấm phần "nâng cao ArgoCD + Service Mesh" (2đ) muốn thấy: hiểu và áp dụng
   đúng least-privilege bằng danh tính mesh, không chỉ "bật STRICT mTLS cho có".
2. Việc này không cần hạ tầng mới, chỉ cần viết thêm YAML — có thể làm ngay, không ảnh hưởng
   runtime đang chạy nếu áp dụng cẩn thận (test từng policy 1, dùng `action: ALLOW` mặc định
   deny-all chỉ khi đã chắc chắn liệt kê đủ caller hợp lệ, tránh tự khoá luôn traffic hợp lệ
   giữa giờ demo).
3. Tài liệu hoá lại đúng luồng gọi giữa các service (product ← cart/order/inventory/search/
   storefront-bff/backoffice-bff, tương tự) — bạn đã có sẵn thông tin service dependency trong
   `platform-infrastructure.md` mục 1 ("Consumers / Dependent Services"), chỉ cần map từ đó
   sang các policy YAML.

#### 1.4c. `environments/staging/kustomization.yaml`

```yaml
namespace: staging
resources:
- ../../base
labels:
- includeSelectors: true
  pairs: { environment: staging }
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 1
  target:
    kind: Deployment
    name: .*        # ← regex khớp MỌI Deployment
images:
- ... (14 dòng, tag v1.0.1)
```

**Phát hiện kỹ thuật đáng học nhất trong file này:** patch JSON6902 dùng `target.name: .*`
(regex) để set `replicas: 1` cho **tất cả** Deployment cùng lúc bằng **1 patch duy nhất**,
thay vì phải viết N file patch riêng cho N service.

**Đối chiếu trực tiếp:** theo `context.md`, `yas-cd` xử lý việc throttle tài nguyên staging
qua **2 PR riêng biệt** (PR #13 "throttle CPU staging" set CPU limit `250m`, PR #14
"maxSurge:0/maxUnavailable:1") — nếu các PR này sửa **từng file overlay riêng cho từng
service** (nhiều khả năng, dựa theo cấu trúc `overlays/staging` gồm nhiều service con), đây
chính là chỗ có thể gộp lại bằng **1 patch regex `name: .*`** giống file mẫu này, cho cả 3
thông số cùng lúc (`replicas`, `resources.limits.cpu`, `strategy.rollingUpdate.maxSurge`):

```yaml
# ví dụ gộp 3 patch riêng lẻ hiện có của yas-cd thành 1 patch duy nhất
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

**Lợi ích cụ thể nếu áp dụng:** thêm 1 service mới vào staging tự động thừa hưởng đúng chính
sách throttle mà không cần nhớ thêm patch riêng cho service đó — đúng tinh thần "giảm chi phí
biên khi thêm service mới" đã nêu ở mục 0 của tài liệu cải tiến trước, và lần này có ví dụ
thật chứng minh nó khả thi, không phải lý thuyết suông.

**Điểm yếu của repo mẫu ở đây (không nên copy):** `environments/staging/` **không có bất kỳ
file Istio nào** — không mTLS, không retry, không AuthorizationPolicy cho staging. Nếu giảng
viên hỏi "mesh có áp dụng cho staging không", câu trả lời sẽ là "không", đây là 1 lỗ hổng
thật của repo mẫu. **`yas-cd` nên làm tốt hơn ở điểm này**: áp policy Istio cho cả `staging`,
không chỉ `dev` — chi phí thêm là copy các file `istio/*.yaml` từ `dev` sang `staging`
(đổi `namespace: dev` → `staging` trong các SPIFFE principal), không tốn thêm hạ tầng.

#### 1.4d. `environments/developer-build/` — phần phức tạp nhất, nhiều bài học nhất

**`kustomization.yaml`:** namespace `developer-build`, có `patches:` trỏ tới 15 file trong
`patches/`, và **`images:` liệt kê đủ 19 service** (kể cả 5 service không tồn tại trong
`base/kustomization.yaml`: `promotion`, `rating`, `delivery`, `recommendation`, `location`,
`webhook` — những dòng ảnh chết theo phân tích mục 1.3, không gây lỗi khi build vì Kustomize
bỏ qua image entry không khớp resource nào, nhưng là rác thừa nên dọn).

**`patches/nodeport-patch.yaml`** (áp cho mọi Service trừ `identity`, dùng
`labelSelector: "app!=identity"`):
```yaml
- op: replace
  path: /spec/type
  value: NodePort
```
Cùng kỹ thuật "1 patch, nhiều target qua labelSelector" như staging — expose toàn bộ Service
thành NodePort để developer truy cập trực tiếp bằng IP:port, không cần Ingress/DNS riêng cho
môi trường tạm thời này. Hợp lý cho 1 môi trường sống ngắn hạn.

**`patches/identity-dev-externalname.yaml`:**
```yaml
- op: replace
  path: /spec/type
  value: ExternalName
- op: remove
  path: /spec/selector
- op: add
  path: /spec/externalName
  value: identity.dev.svc.cluster.local
```
Đây chính là kỹ thuật tương đương `identity-aliases.yaml` của `yas-cd`, nhưng áp dụng bằng
JSON6902 patch lên chính `base/_common/identity-service.yaml` thay vì tạo file `ExternalName`
riêng — cả 2 cách đều hợp lệ, cách của `yas-cd` (file riêng) rõ ràng hơn khi đọc, cách của
repo mẫu (patch) ít file hơn. Không cần đổi, đây là khác biệt về gu, không phải đúng/sai.

**`patches/use-dev-infra-<service>.yaml`** (13 file riêng, mỗi service 1 file) — patch
`SPRING_DATASOURCE_URL`/`ELASTICSEARCH_URL`/`SPRING_DATA_REDIS_HOST` trỏ sang
`<service>.dev.svc.cluster.local` thay vì bản riêng trong `developer-build`. Đây là bằng
chứng cụ thể: **`developer-build` không tự deploy Postgres/Redis/ES riêng**, mà tái sử dụng
toàn bộ platform của `dev` — đúng tinh thần tiết kiệm tài nguyên mà `yas-cd` cũng theo đuổi,
chỉ khác cách trỏ (patch từng biến môi trường thay vì 1 alias Service DNS chung).

**Phát hiện dọn dẹp:** `patches/use-dev-infra.yaml` (không có hậu tố tên service) là **file
thừa/chết** — nội dung của nó là **gộp lại đúng 12/13 patch** đã có trong các file riêng
(`use-dev-infra-media.yaml`, `use-dev-infra-product.yaml`...), nhưng `kustomization.yaml`
**không tham chiếu tới file gộp này** (chỉ tham chiếu từng file riêng). Đây gần như chắc chắn
là bản nháp cũ bị bỏ quên khi refactor sang patch riêng từng file, chưa xoá. Bài học: dọn
file thừa sau refactor — kiểm tra lại `yas-cd` xem có file overlay nào tương tự còn sót từ các
PR #11-#14 hay không (VD: file patch cũ trước khi tách CPU-throttle riêng biệt).

**`patches/use-dev-infra-storefront-bff.yaml` và `-storefront-bff-config.yaml`:** đáng chú ý
nhất — `storefront-bff` khi chạy trong `developer-build` vẫn dùng **Keycloak issuer URL trỏ
thẳng ra IP ngoài cố định** (`http://35.247.165.74:31096/realms/Yas`) cho phần
`authorization-uri` (trình duyệt người dùng redirect tới), nhưng dùng **DNS nội bộ**
(`identity.dev.svc.cluster.local`) cho phần `token-uri`/`jwk-set-uri` (service-to-service, gọi
từ trong cluster). Đây là pattern chuẩn cho OAuth2 khi có 2 "khán giả" khác nhau: trình duyệt
người dùng (ở ngoài cluster, cần địa chỉ public) và service backend (ở trong cluster, dùng
DNS nội bộ nhanh hơn, không qua NAT/Ingress). **Điểm yếu:** IP `35.247.165.74:31096` là
**hardcode cứng trong file YAML**, không phải biến — nếu VM đổi IP hoặc NodePort đổi, phải
sửa tay file này. So với `yas-cd`, theo `implementation-progress.md` bạn cũng đang hardcode
`http://yas.<env>.local:30846/realms/...` — cùng loại hạn chế, không phải vấn đề mới, nhưng
đáng ghi chú thêm 1 dòng trong docs của `yas-cd`: "địa chỉ NodePort/IP là hardcode theo hạ
tầng VM hiện tại, đổi VM phải cập nhật tay các file X, Y, Z" — để người kế nhiệm/đồng đội biết
chỗ cần sửa khi đổi hạ tầng.

**`dev-infra-destinationrules.yaml`:** 6 `DestinationRule` set `ISTIO_MUTUAL` cho các Service
platform ở namespace `dev` (`identity`, `postgres-postgresql`, `redis-master`, `elasticsearch`,
`kafka`, kể cả headless Service `*.kafka-controller-headless...`) — cần thiết vì
`developer-build` gọi cross-namespace sang `dev`, phải khai báo DestinationRule cho đúng
target đó (khác với DestinationRule trong `dev/istio/mtls.yaml` vốn chỉ khai cho Service
trong cùng namespace `dev`). Nếu `yas-cd` cũng cho `developer` namespace gọi cross-namespace
sang `platform`, cần rà lại xem đã có DestinationRule tương ứng theo đúng FQDN
`*.platform.svc.cluster.local` hay chưa — thiếu chỗ này sẽ khiến mTLS STRICT chặn nhầm traffic
hợp lệ giữa `developer`↔`platform`.

---

## PHẦN 2 — Phần CD trong app repo `com-suon-bi-cha/yas`

Đây là phát hiện lớn nhất về mặt **tổ chức pipeline**: thay vì 1 Jenkinsfile duy nhất như
`tzin1401/yas`, repo mẫu có **5 Jenkinsfile riêng biệt theo mục đích**, đúng pattern "per-
purpose pipeline, không nhồi if/else" mà tài liệu trước đã đề xuất — và ở đây **đã có ví dụ
thật, chạy được**, không chỉ là lý thuyết.

### 2.1. `Jenkinsfile` (165 dòng) — PR quality gate

Stages: Pre-check → Check Skip (so sánh `git diff` với `origin/main` để phát hiện commit
chỉ đổi docs) → Secret Scanning (Gitleaks) → Monorepo Execution (loop qua danh sách service,
chỉ `mvn test`/`package` cho service có file đổi) → Code Quality (Sonar) → Quality Gate →
Coverage Report (JaCoCo, ngưỡng 70%) → Dependency Scan (Snyk).

**Điểm đáng học:** biến `DOCS_ONLY` tính bằng cách kiểm tra **toàn bộ file đổi** có match
`docs/`, `.md`, `.pdf`, hoặc `Jenkinsfile` hay không — nếu đúng, **skip toàn bộ stage sau**
bằng `when { expression { env.DOCS_ONLY == 'false' } }` lặp lại ở mỗi stage. Đây là tối ưu
CI time hợp lý: PR chỉ sửa docs không cần chạy `mvn test`/Sonar/Snyk tốn vài phút.

**Đối chiếu:** `tzin1401/yas` hiện tại (theo `context.md`) đã có "Monorepo Path Filter" từ
Lab 1 — tương tự về ý tưởng (chỉ build phần đổi), nhưng chưa rõ có tối ưu riêng cho case
"chỉ đổi docs" hay không. Đây là bổ sung nhỏ, rẻ, đáng thêm.

### 2.2. `Jenkinsfile.ci` (324 dòng) — pipeline chính build + push + update GitOps

Đây là pipeline tương đương Jenkinsfile hiện tại của `tzin1401/yas`, nhưng có 1 số khác biệt
kỹ thuật đáng chú ý:

**a) Phát hiện tag bằng chính Git, không phụ thuộc hoàn toàn vào biến môi trường Jenkins:**
```groovy
def gitTag = sh(script: '''
    git tag --points-at HEAD 2>/dev/null \
        | grep -E '^v[0-9]+\\.[0-9]+\\.[0-9]+' \
        | head -n 1 || true
''', returnStdout: true).trim()
env.GIT_TAG_MATCH = gitTag ? 'true' : 'false'
```
Thay vì chỉ dựa vào `env.TAG_NAME` (biến Jenkins tự set khi multibranch phát hiện tag —
đúng cơ chế đang cần verify ở mục P0 phần "Jenkins tag discovery" trong kế hoạch trước),
pipeline này **tự truy vấn Git tại đúng commit HEAD** để tìm tag khớp regex semver. Lợi ích:
không phụ thuộc hoàn toàn vào việc multibranch job đã cấu hình đúng "Discover tags" hay chưa
— dù `env.TAG_NAME` không được set đúng vì lý do cấu hình Jenkins, logic `git tag
--points-at HEAD` vẫn tự phát hiện được nếu build được trigger bằng cách khác (webhook build
theo branch chứa đúng commit đã gắn tag). **Đây là lớp phòng thủ kép hữu ích** — khuyến nghị
thêm logic tương tự vào `resolveTargetEnv` (đề xuất ở tài liệu trước) làm cơ chế dự phòng,
không thay thế hoàn toàn việc bật đúng "Discover tags" (vẫn cần bật để tự trigger job).

**b) `GLOBAL_IMPACT`:** phát hiện nếu file đổi thuộc `pom.xml`, `mvnw`, `.mvn/`, hoặc
`common-library/` → coi như ảnh hưởng toàn bộ service, build lại **tất cả** thay vì chỉ
service có path đổi trực tiếp. Đây là điểm mà "Monorepo Path Filter" của Lab 1 (theo
`context.md`) **cần có nhưng tài liệu hiện tại chưa xác nhận đã xử lý** — nếu path filter của
bạn chỉ check `startsWith("${service}/")` mà không tính tới thay đổi ở `pom.xml` gốc hay
`common-library` dùng chung, sẽ bỏ sót rebuild cho các service phụ thuộc gián tiếp, gây bug
"service chạy code cũ dù dependency chung đã đổi". **Khuyến nghị kiểm tra lại ngay** — đây là
rủi ro âm thầm, khó phát hiện qua test thủ công vì hầu hết thời gian dependency chung không
đổi.

**c) `Docker Build & Push` build lại toàn bộ khi có tag** (`buildAllImages = GIT_TAG_MATCH ||
GLOBAL_IMPACT`) — xác nhận đúng như phân tích ở tài liệu trước: repo mẫu này **cũng chưa áp
dụng "build once, promote many"**, vẫn rebuild khi tạo tag release. Đây không phải điểm nên
học theo — giữ nguyên khuyến nghị trước đó (dùng `docker buildx imagetools create` để retag
thay vì rebuild) như 1 cải tiến vượt qua cả repo mẫu, không chỉ bắt kịp.

**d) Gọi `scripts/update-gitops-manifest.sh <env> [tag]`** thay vì viết logic update GitOps
trực tiếp trong Jenkinsfile — xem phân tích script này ở mục 2.6.

### 2.3. `Jenkinsfile.developer-build` (130 dòng) + `scripts/deploy-developer-build.sh`

Đây là ví dụ **thực tế, chạy được** của job `developer_build` mà đề bài
(`Project02_HKII_25_26.md`) yêu cầu — và nó khớp gần như chính xác với khuyến nghị "Hướng A"
đã đề xuất ở tài liệu trước (job riêng, tham số tường minh, tách khỏi pipeline chính):

```groovy
parameters {
    string(name: 'media', defaultValue: 'main', ...)
    string(name: 'product', defaultValue: 'main', ...)
    // ... 1 tham số branch riêng cho MỖI service
}
```

Mỗi lần chạy, job tra cứu commit mới nhất của branch được chỉ định cho **từng service** qua
`git ls-remote origin refs/heads/<branch>`, dùng commit đó làm tag (hoặc `latest` nếu để mặc
định `main`), rồi gọi `scripts/deploy-developer-build.sh` để cập nhật tag + **`kubectl apply -k`
trực tiếp, bypass ArgoCD hoàn toàn** (comment ngay trong script: `# Apply trực tiếp (bypass
ArgoCD — faster for developer use)`).

**Đây là quyết định kiến trúc quan trọng cần bạn cân nhắc rõ ràng, không nên copy mù quáng:**
bypass ArgoCD nghĩa là `developer-build` **không tự phục hồi trạng thái** nếu ai đó lỡ tay
`kubectl edit`/`kubectl delete` trực tiếp — vi phạm đúng nguyên tắc GitOps "Git là nguồn sự
thật duy nhất" mà chính đề bài (`agent-task-assignment-prompt.md`) yêu cầu cho `dev`/
`staging`/`developer`. Repo mẫu chấp nhận đánh đổi này **có chủ đích** (tốc độ demo nhanh hơn
so với chờ ArgoCD reconcile ~vài chục giây tới vài phút), và vì `developer-build` là môi
trường sống ngắn, thử nghiệm, rủi ro drift không quan trọng bằng tốc độ lặp code khi debug.

**Khuyến nghị cho `yas-cd`:** đây là điểm cần **quyết định tường minh, ghi rõ trong docs**,
không để ngầm định:
- Nếu giữ `developer` dưới quyền ArgoCD (như hiện tại theo `argocd/apps/yas-developer.yaml`
  đã tồn tại) → chấp nhận độ trễ vài chục giây mỗi lần dev muốn xem kết quả, đổi lại giữ đúng
  nguyên tắc GitOps xuyên suốt cả 3 môi trường, không cần giải thích ngoại lệ khi bảo vệ đồ án.
- Nếu muốn nhanh như repo mẫu → phải nói rõ trong báo cáo đây là ngoại lệ có chủ đích cho
  đúng 1 namespace `developer`, không áp dụng cho `dev`/`staging`, và note rõ rủi ro drift.
- **Khuyến nghị của mình: giữ nguyên cách hiện tại của `yas-cd` (developer vẫn qua ArgoCD)** —
  vì đề bài chấm điểm "nâng cao ArgoCD" (2đ) dựa trên việc ArgoCD quản lý đúng theo mô tả, có
  1 namespace ngoại lệ bypass sẽ khó giải thích gọn trong buổi bảo vệ, trong khi lợi ích tốc
  độ (nhanh hơn vài chục giây) không đáng giá bằng rủi ro bị hỏi xoáy "vậy GitOps ở đây có
  đúng nghĩa không".

**Điểm hay đáng học dù không đổi kiến trúc ArgoCD:** phần "Print Access Info" — tự động dò
`WORKER_IP` từ `kubectl get nodes` và liệt kê từng Service kèm NodePort, in ra URL truy cập
sẵn. So với cách hiện tại của `yas-cd`/đề bài gốc ("trả domain:port NodePort, dev tự thêm
/etc/hosts") — việc **tự động in ra bảng URL** thay vì bắt người dùng tự tra `kubectl get svc`
là 1 cải thiện UX nhỏ, rẻ, nên thêm vào job `developer_build` của `tzin1401/yas` dù có giữ
ArgoCD hay không.

### 2.4. `Jenkinsfile.cleanup` (45 dòng) — job xoá deploy

Rất đơn giản: `kubectl delete deployments/services/configmaps/replicasets/pods --all -n
developer-build`, giữ lại namespace. Đây tương ứng đúng job "xóa deploy" mà đề bài yêu cầu ở
mục 5. Vì `developer-build` bị bypass ArgoCD (mục 2.3), xoá tay bằng `kubectl delete` ở đây
là nhất quán với quyết định đó — **nếu `yas-cd` giữ `developer` dưới ArgoCD (khuyến nghị ở
trên), job xoá deploy tương ứng nên là `argocd app sync yas-developer --prune` sau khi commit
xoá overlay, hoặc scale replicas về 0 qua Git commit, không phải `kubectl delete` trực tiếp**
— để nhất quán với nguyên tắc GitOps xuyên suốt.

### 2.5. `Jenkinsfile.ui-image-sync` (71 dòng) — mirror image UI từ upstream

Job kéo image `storefront`/`backoffice` UI có sẵn từ registry gốc của dự án YAS open-source
(`ghcr.io/nashtech-garage/yas-storefront`) rồi đẩy lại vào Docker Hub riêng của nhóm
(`bingsu1103/storefront`). Đây là giải pháp thực dụng cho tình huống: nhóm không tự build lại
2 service UI (Next.js/React) từ source, chỉ mượn image build sẵn từ upstream để tiết kiệm thời
gian, và rollout lại `dev` sau khi mirror xong.

**Không áp dụng trực tiếp cho `yas-cd`** trừ khi bạn cũng đang gặp đúng tình huống "không có
thời gian build lại UI service từ source" — nhưng đáng ghi nhận như 1 pattern hợp lệ nếu team
gặp giới hạn thời gian tương tự với 1 service cụ thể nào đó (build once từ upstream, mirror
sang registry riêng, không tự build).

### 2.6. `scripts/update-gitops-manifest.sh`

Logic đáng học nhất: xác định `UPDATE_ALL` — nếu gọi với tham số thứ 2 (tag) và env là
`staging`, coi như "staging release" → cập nhật **toàn bộ** service scoped, bỏ qua việc diff
file đổi. Ngược lại (env `dev`, không có tag) → chỉ cập nhật đúng service có file thay đổi
theo `git diff`. Đây là cách hợp lý xử lý 2 ngữ cảnh khác nhau bằng 1 script dùng chung (thay
vì 2 script riêng) — đúng tinh thần "logic chọn lọc tách biệt khỏi cơ chế build" đã đề xuất.

**Điểm cần lưu ý khi áp dụng:** script này lấy tất cả service khai trong 1 `declare -A
SERVICE_PATHS` viết cứng ngay trong script (14 dòng) — đây lại là **1 nguồn sự thật thứ 3**
về danh sách service (cạnh `services.yaml` và `base/kustomization.yaml`) nếu áp dụng y
nguyên vào `yas-cd`. Bạn đã có `services.yaml` làm nguồn sự thật duy nhất — nếu viết lại
script tương tự, **nên đọc danh sách service từ chính `services.yaml`** (dùng `yq`) thay vì
khai cứng thêm 1 mảng riêng trong bash, tránh lặp lại đúng vấn đề "3 nguồn sự thật" mà tài
liệu trước đã cảnh báo ở mục "giảm coupling `services.yaml` ↔ route generation".

---

## PHẦN 3 — Bảng đối chiếu tổng hợp

| Khía cạnh | `yas-cd` (hiện tại) | Repo mẫu | Khuyến nghị |
|---|---|---|---|
| Sync policy staging | Auto-sync giống dev (suy luận từ `cluster-runbook.md`) | **Sync thủ công**, không `automated` | **Áp dụng ngay** — thêm gate rẻ tiền |
| Routing per-service ở tầng mesh | VirtualService/route riêng theo từng backend, sinh bởi script | Chỉ 2 route theo Host header vào 2 BFF, phần còn lại nằm trong Spring Gateway của BFF | **Áp dụng nếu BFF đã có Gateway route sẵn** — bỏ hẳn `sync-gateway-routes.sh` |
| AuthorizationPolicy | Chưa rõ mức chi tiết, cần tự kiểm tra | Per-service, SPIFFE principal, least-privilege rõ ràng | **Áp dụng, độ ưu tiên cao** — đúng trọng tâm chấm điểm mesh nâng cao |
| Retry policy phạm vi | Chưa rõ có áp toàn bộ hay chọn lọc | Chỉ 6 service trên critical path đặt hàng | Thu hẹp lại nếu đang áp toàn bộ |
| Mesh cho staging | Chưa rõ | **Không có** (điểm yếu của repo mẫu) | `yas-cd` nên làm **tốt hơn** repo mẫu: áp mesh cho cả staging |
| Patch throttle staging | Nhiều PR/file riêng theo service (PR #13, #14) | 1 patch JSON6902 regex `name: .*` cho mọi Deployment | Gộp lại thành 1-2 patch dùng regex |
| `developer` có qua ArgoCD? | Có (đúng nguyên tắc GitOps) | **Không** — bypass, `kubectl apply -k` trực tiếp | **Giữ nguyên cách của `yas-cd`**, không bắt chước bypass |
| Job xoá deploy | Cần làm (remaining work) | `kubectl delete --all`, hợp lý vì đã bypass ArgoCD | Nếu giữ ArgoCD cho developer: xoá qua Git commit + `argocd app sync --prune`, không `kubectl delete` |
| Danh sách service | 1 nguồn sự thật: `services.yaml` | Rải rác ở README, `base/kustomization.yaml`, `kustomization.yaml` per-env images, và script bash riêng — **4 nguồn không khớp nhau hoàn toàn** | `yas-cd` đã làm tốt hơn ở điểm này — giữ nguyên, không học theo |
| Secret trong Deployment | Có kiểm tra "secret-like pattern" qua `validate-gitops.sh` | Plaintext password trực tiếp trong YAML | `yas-cd` đã có phòng thủ tốt hơn — nhưng nên xác nhận thực tế không còn plaintext nào lọt qua |
| Build once vs rebuild theo tag | Rebuild theo từng loại trigger | Cũng rebuild khi tag — chưa tối ưu | Cả 2 repo đều nên cải thiện — giữ nguyên khuyến nghị "retag qua `imagetools create`" từ tài liệu trước |

---

## PHẦN 4 — Danh sách việc cụ thể, sắp theo thứ tự làm

Tích hợp vào kế hoạch tổng đã có trước đó (không thay thế, bổ sung thêm dựa trên phát hiện
từ 2 repo mẫu):

### Làm ngay (chi phí thấp, giá trị cao, không rủi ro runtime)
1. **Staging sync thủ công**: xoá block `automated` khỏi `argocd/apps/yas-staging.yaml`,
   cập nhật kịch bản demo thêm bước `argocd app sync yas-staging`.
2. **Viết lại `AuthorizationPolicy` theo per-service SPIFFE principal** thay vì (nếu đang)
   namespace-wide — dựa theo bảng "Consumers / Dependent Services" đã có sẵn trong
   `platform-infrastructure.md` mục 1.
3. **Mở rộng mesh policy (mTLS, retry, authorization) sang cả `staging`**, không chỉ `dev` —
   copy các file từ `overlays/dev/istio/` sang `overlays/staging/istio/`, đổi
   namespace/principal cho đúng.
4. **Gộp các patch throttle staging (PR #13, #14) thành 1-2 patch JSON6902 dùng
   `target.name: .*`** thay vì rải theo từng service.
5. Thêm comment giải thích tại field `serviceAccountName` trong mỗi `deployment.yaml`
   (lý do: cần cho AuthorizationPolicy).

### Cần kiểm tra trước khi quyết định (không tự tin áp dụng ngay vì chưa xác nhận thực trạng)
6. Kiểm tra `storefront-bff`/`backoffice-bff` trong `tzin1401/yas` đã có Spring Cloud Gateway
   route theo từng service (`application.yml`/ConfigMap) hay chưa. Nếu có → đơn giản hoá
   `virtualservice.yaml` xuống 2 route theo Host, **xoá hẳn `sync-gateway-routes.sh`**.
7. Kiểm tra retry policy hiện tại của `yas-cd` áp cho toàn bộ hay chọn lọc theo critical path
   — nếu toàn bộ, thu hẹp lại theo luồng đặt hàng chính.
8. Kiểm tra "Monorepo Path Filter" của Lab 1 có tính tới thay đổi ở `pom.xml`/module dùng
   chung (tương đương `common-library`) hay chỉ check path trực tiếp của từng service — nếu
   thiếu, đây là bug âm thầm cần vá trước khi nộp.

### Việc đã quyết định giữ nguyên (không bắt chước repo mẫu)
9. Giữ `developer` dưới quyền ArgoCD, **không** bypass bằng `kubectl apply -k` trực tiếp —
   khác biệt có chủ đích so với repo mẫu, ghi rõ lý do này trong báo cáo nếu giảng viên hỏi
   sao không làm nhanh như "cách phổ biến khác".
10. Giữ `services.yaml` làm nguồn sự thật duy nhất cho danh sách service — không rải thêm
    danh sách cứng trong script bash riêng như repo mẫu đang làm.
11. Giữ kiến trúc `platform` namespace dùng chung (không tách Postgres/Kafka/ES riêng theo
    từng env) — đúng với ràng buộc tài nguyên VM đơn của bạn, tốt hơn cách repo mẫu.

### Việc thuộc phạm vi kế hoạch trước, không lặp lại chi tiết ở đây
12. Bỏ `DEPLOY_TO_DEVELOPER` khỏi Jenkinsfile chính, tách thành job `developer_build` riêng —
    **giờ đã có ví dụ thật để tham khảo trực tiếp cấu trúc tham số**: xem `Jenkinsfile.developer-
    build` mục 2.3 (mỗi service 1 tham số branch, dùng `git ls-remote` để lấy commit tương ứng).
13. Retag thay vì rebuild khi release tag — cả 2 repo mẫu lẫn `yas-cd` đều chưa làm, đây là
    điểm giúp `yas-cd` **vượt qua** chất lượng của repo mẫu, không chỉ bắt kịp.

---

## PHẦN 5 — Lưu ý khi trình bày trong báo cáo/bảo vệ đồ án

Nếu giảng viên biết hoặc hỏi về repo mẫu này (khả năng có, vì cùng dự án YAS phổ biến trong
môn học), nên chuẩn bị trả lời được 3 câu hỏi:

1. **"Tại sao không bypass ArgoCD cho developer như nhóm kia?"** → trả lời: giữ nguyên tắc
   GitOps nhất quán cho cả 3 môi trường là lựa chọn có chủ đích, đánh đổi lấy vài chục giây
   tốc độ để giữ tính nhất quán và khả năng self-heal, đúng tinh thần đề bài yêu cầu ArgoCD
   quản lý namespace `dev`/`staging`/`developer`.
2. **"Tại sao AuthorizationPolicy của nhóm bạn chi tiết/không chi tiết bằng nhóm kia?"** →
   sau khi áp dụng mục 2 ở Phần 4, câu trả lời sẽ là "chúng tôi áp dụng least-privilege theo
   từng cặp service dùng SPIFFE identity, dựa trên bản đồ dependency đã định nghĩa trong
   `platform-infrastructure.md`" — có tài liệu hỗ trợ, không chỉ nói suông.
3. **"Vì sao mesh của staging khác dev?"** → nếu áp dụng mục 3 ở Phần 4 (mở rộng mesh sang
   staging), câu trả lời là "áp dụng đồng nhất cho cả 2 môi trường, đây là điểm chúng tôi làm
   đầy đủ hơn so với 1 số repo tham khảo khác chỉ áp mesh cho dev".
