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
