# ArgoCD Troubleshooting Summary

Tài liệu này tóm tắt các vấn đề kỹ thuật phát sinh trong quá trình tích hợp ArgoCD (GitOps) cho YAS Lab 2 CD Project và các giải pháp đã được thực hiện để khắc phục.

## 1. Lỗi Kustomize thiếu Helm Integration (`must specify --enable-helm`)
- **Vấn đề**: Khi ArgoCD cố gắng dịch các file cấu hình `kustomization.yaml` có chứa `helmGlobals`, Kustomize báo lỗi không thể sử dụng `HelmChartInflationGenerator` vì thiếu cờ `--enable-helm`. Mặc định, ArgoCD tắt tính năng Helm trong Kustomize để bảo mật.
- **Giải pháp**: Patch ConfigMap `argocd-cm` để bổ sung cấu hình và khởi động lại Repo Server.
  ```bash
  kubectl patch configmap argocd-cm -n argocd -p '{"data": {"kustomize.buildOptions": "--enable-helm"}}'
  kubectl rollout restart deployment argocd-repo-server -n argocd
  ```

## 2. ArgoCD lưu Cache của trạng thái lỗi
- **Vấn đề**: Sau khi đã cập nhật ConfigMap, ArgoCD vẫn báo lỗi `ComparisonError (cached)`.
- **Giải pháp**: Buộc ArgoCD phải xóa cache và tải lại cấu hình bằng tính năng Hard Refresh thông qua CLI:
  ```bash
  argocd app get yas-dev --hard-refresh
  ```

## 3. Lỗi bảo mật Kustomize Load Restrictor
- **Vấn đề**: Kustomize báo lỗi `security; file '...' is not in or below '.../base'`. Do file Kustomize nằm trong `base/` nhưng lại trỏ tới các Helm charts ở `../charts` (nằm ngoài thư mục cấu hình gốc), tính năng Load Restrictor mặc định của Kustomize sẽ chặn quá trình này để đảm bảo an toàn.
- **Giải pháp**: Tiếp tục patch `argocd-cm` để bổ sung cờ `--load-restrictor=LoadRestrictionsNone`.
  ```bash
  kubectl patch configmap argocd-cm -n argocd -p '{"data": {"kustomize.buildOptions": "--enable-helm --load-restrictor=LoadRestrictionsNone"}}'
  kubectl rollout restart deployment argocd-repo-server -n argocd
  ```

## 4. Lỗi thiếu CRD `ServiceMonitor`
- **Vấn đề**: Mặc dù ArgoCD đã dịch thành công file Kustomize, quá trình Sync bị chặn bởi Kubernetes do không nhận diện được tài nguyên `ServiceMonitor`. Theo yêu cầu đồ án (phần nâng cao), Kiali cần được sử dụng để vẽ Topology (Kiali yêu cầu dữ liệu từ Prometheus). Thêm vào đó, source code mặc định của project YAS tự động sinh ra các cấu hình `ServiceMonitor`.
- **Giải pháp**: Cài đặt định nghĩa (CRD) của `ServiceMonitor` từ Prometheus Operator để K8s có thể cấp phát tài nguyên mà không làm ngắt quãng ArgoCD.
  ```bash
  kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
  ```

## 5. Lỗi Image Không Hợp Lệ (`InvalidImageName` / Pod Degraded)
- **Vấn đề**: Các Pod của ứng dụng YAS bị kẹt ở trạng thái `Degraded` với lỗi `couldn't parse image name "docker.io/${DOCKERHUB_USERNAME}/yas-promotion:main"`. Nguyên nhân là biến `${DOCKERHUB_USERNAME}` trong thư mục `base/` và `overlays/` trên Git repository vẫn là chữ thô (placeholder) chưa được thay thế bằng tên thật. Do đó, Docker không thể định dạng tên image.
- **Giải pháp**: Chạy lệnh `sed` để thay thế hàng loạt tên biến thành username Docker Hub (VD: `emanhthangngot`) trên máy tính local, sau đó commit và push/merge vào nhánh `main` để ArgoCD tự động nhận diện bản cập nhật.
  ```bash
  # Cập nhật mã nguồn local
  find base overlays -type f -name "*.yaml" -exec sed -i 's/${DOCKERHUB_USERNAME}/emanhthangngot/g' {} +

  # Đẩy lên Github
  git add .
  git commit -m "cd(lab2): replace DOCKERHUB_USERNAME placeholder in manifests"
  ```

## 6. Lỗi thiếu runtime config `yas.public.url`
- **Vấn đề**: Sau khi image `payment-paypal` chạy được dưới dạng Spring Boot app, service fail khi khởi động vì thiếu placeholder `${yas.public.url}` cho PayPal capture/cancel URL.
- **Giải pháp**: Bổ sung `yas.public.url` vào `base/yas-configuration.yaml` để ConfigMap chung cấp giá trị runtime cho các service.

## 7. Thiếu platform dependencies cho runtime
- **Vấn đề**: Sau khi image pull và Spring Boot packaging đã được xử lý, nhiều backend vẫn `CrashLoopBackOff` vì cluster chưa có PostgreSQL, Redis, Kafka, Elasticsearch và Keycloak/identity. Ví dụ: `cart` không kết nối được `postgresql.postgres:5432`, BFF không resolve được `identity`.
- **Giải pháp**: Bổ sung ArgoCD app `yas-platform` trỏ tới `platform/base`. App này tạo dependency stack lab-local và các service DNS đúng với cấu hình YAS: `postgresql.postgres`, `redis-master.redis`, `kafka-cluster-kafka-brokers.kafka`, `elasticsearch-es-http.elasticsearch`, và `identity`.

## 8. Backend khởi động chậm bị liveness probe restart
- **Vấn đề**: Trên single-node K3s lab, nhiều Spring Boot backend khởi động song song rất chậm vì cùng lúc chạy Liquibase, JPA và kết nối dependency. Pod bị kubelet restart với `Exit Code 137` trước khi actuator metric port sẵn sàng, dù log không có exception ứng dụng.
- **Giải pháp**: Bổ sung `startupProbe` cho backend chart. Startup probe cho service thêm thời gian mở `/actuator/health/liveness` lần đầu, sau đó liveness/readiness mới được dùng để giám sát bình thường.

## 9. Cluster reset làm mất app access NodePort
- **Vấn đề**: Sau khi GCP VM đổi IP/khởi động lại cluster, K3s Traefik tạo NodePort ngẫu nhiên thay vì port demo cố định `30080/30081`, và YAS chưa có Ingress route để truy cập bằng host lab.
- **Giải pháp**: Quản lý Traefik service NodePort qua GitOps trong `yas-platform`, đồng thời thêm Ingress route cho `yas.dev.local`, `yas.staging.local`, và `yas.developer.local` tới `storefront-ui`.

## 10. PostgreSQL hết connection khi nhiều backend khởi động cùng lúc
- **Vấn đề**: Trên lab single-node, nhiều Spring Boot service cùng chạy Liquibase/JPA và Hikari pool mặc định làm PostgreSQL báo `FATAL: sorry, too many clients already`.
- **Giải pháp**: Giới hạn Hikari pool trong ConfigMap chung ở mức lab-safe (`maximum-pool-size: 2`, `minimum-idle: 0`) để giảm số connection giữ đồng thời. Đồng thời tăng PostgreSQL `max_connections` lên 500 cho lab single-node để chịu được lúc nhiều môi trường cùng khởi động.

## 11. ArgoCD app kẹt `Progressing` vĩnh viễn do Ingress không có LoadBalancer address
- **Vấn đề**: 4 app (`yas-dev`, `yas-staging`, `yas-developer`, `yas-platform`) luôn hiển thị health `Progressing` dù toàn bộ Deployment đã sẵn sàng và không có pod lỗi; chỉ `yas-mesh-demo` (app duy nhất không chứa Ingress) là `Healthy`. Nguyên nhân: ArgoCD coi một `Ingress` là `Progressing` cho tới khi `status.loadBalancer.ingress` có địa chỉ. Controller `ingress-nginx` được cài với arg `--publish-service=$(POD_NAMESPACE)/ingress-nginx-controller`, tức là lấy địa chỉ từ Service LoadBalancer của chính nó — nhưng trên K3s single-node không có cloud load balancer nên Service này kẹt `<pending>` vĩnh viễn, mọi Ingress vì thế không bao giờ có address.
- **Giải pháp**: Đổi arg của controller từ `--publish-service=...` sang `--report-node-internal-ip-address` để controller tự publish IP node vào status các Ingress (không hardcode IP, chịu được việc VM đổi IP). Namespace `ingress-nginx` không do ArgoCD quản lý (cài tay bằng manifest) nên patch trực tiếp:
  ```bash
  sudo k3s kubectl patch deploy ingress-nginx-controller -n ingress-nginx --type=json \
    -p '[{"op":"replace","path":"/spec/template/spec/containers/0/args/1","value":"--report-node-internal-ip-address"}]'
  sudo k3s kubectl rollout status deploy/ingress-nginx-controller -n ingress-nginx
  ```
  Sau khi controller rollout xong, kiểm tra `kubectl get ingress -A` thấy cột ADDRESS có IP node, và các app ArgoCD chuyển sang `Healthy` trong vòng vài phút.

## 12. Toàn bộ `/api/**` qua ingress trả `403 RBAC: access denied` trên dev và staging (PR #15)
- **Vấn đề**: Sau khi siết AuthorizationPolicy theo per-service SPIFFE principal, mọi request `/api/**` đi qua NodePort/ingress đều bị `403 RBAC: access denied` (chữ ký của Envoy), làm fail bước product API của `scripts/smoke-runtime-storefront.sh` và storefront không load được dữ liệu. Truy vết bằng Envoy RBAC debug log trên sidecar của `product` cho thấy caller thực tế mang danh tính `spiffe://cluster.local/ns/dev/sa/default` từ pod `nginx-api-gateway` — không phải `storefront-bff` như thiết kế. Nguyên nhân gốc: image BFF (profile `prod`) chạy Spring Cloud Gateway phiên bản mới, chỉ đọc route từ key `spring.cloud.gateway.server.webflux.routes`; ConfigMap `yas-gateway-routes-config` khai báo 11 route trỏ thẳng service dưới key cũ `spring.cloud.gateway.routes` nên bị bỏ qua âm thầm. BFF rơi về route đóng gói sẵn trong image (`/api/** -> http://nginx`), khiến traffic vòng qua `nginx-api-gateway` chạy bằng ServiceAccount `default` — đúng đối tượng mà AuthorizationPolicy phải chặn.
- **Giải pháp** (PR #15): Sửa `scripts/sync-gateway-routes.sh` sinh route dưới key `server.webflux` (giữ `TokenRelay=` và route `ui` qua `${UI_HOST}`), regenerate `base/yas-configuration.yaml` + `charts/yas-configuration/values.yaml`, cập nhật assertion trong `scripts/validate-gitops.sh`. Sau khi merge và ArgoCD sync, phải `kubectl rollout restart deploy/storefront-bff deploy/backoffice-bff -n <ns>` vì pod chỉ đọc ConfigMap lúc khởi động. Kết quả trên dev: product API/featured/media/search trả 200, login redirect và UI không đổi; `/api/tax/tax-classes` trả 401 là hành vi đúng (endpoint cần đăng nhập). Staging nhận fix ở lần `argocd app sync yas-staging` thủ công kế tiếp (nhớ restart 2 BFF tương tự). Bài học: khi mesh chặn một luồng "đang chạy được", kiểm tra xem luồng đó có đang đi đúng đường thiết kế không — per-service authorization đã phát hiện đúng một đường gọi không khai báo.

  **Ghi chú sau khi áp dụng**: `yas-dev`, `yas-staging`, `yas-platform` chuyển `Healthy` ngay sau patch. Riêng `yas-developer` vẫn `Progressing` — nhưng đây là hành vi đúng, không phải lỗi: PVC `media-images` trong namespace `developer` ở trạng thái `Pending` vì mọi Deployment đang scale 0 theo policy dormant, mà StorageClass `local-path` dùng `WaitForFirstConsumer` (chỉ bind volume khi có pod thực sự mount). Khi job `developer_build` kích hoạt preview (scale các Deployment lên), PVC sẽ bind và app tự chuyển `Healthy`. Ghi nhận trạng thái này vào báo cáo thay vì "sửa", vì mọi cách ép Healthy (custom health check coi Pending là Healthy) sẽ che mất lỗi PVC thật ở các môi trường active.
