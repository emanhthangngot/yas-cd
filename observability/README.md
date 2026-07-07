# Observability stack (GitOps)

IaC cho stack LGTM của YAS. Nguồn sự thật = thư mục này; ArgoCD (app-of-apps
`argocd/apps/yas-observability.yaml`) triển khai. Values đều lấy từ bản LIVE
(đã gộp các `--set` fix), không dùng file cũ bị drift.

## Thành phần
| Release | Nguồn | Ghi chú fix |
|---|---|---|
| kube-prometheus-stack 87.10.1 | helm prometheus-community | Grafana `sqlite3` (postgres/SSL gãy); `enableRemoteWriteReceiver`; `*SelectorNilUsesHelmValues=false` |
| loki 7.0.0 | helm grafana | `useTestSchema=true`; ingestion limits nới |
| tempo 1.24.4 | helm grafana | metricsGenerator remoteWrite; query port 3200 |
| promtail 6.17.1 | helm grafana | bắn thẳng `loki-gateway` |
| grafana (custom) | `charts/grafana` | Grafana external→prometheus-grafana; datasource Loki/Tempo; **dashboard observability provision sẵn (P2)** |
| opentelemetry (custom) | `charts/opentelemetry` | Collector image **contrib 0.153.0**; pipeline traces→Tempo, metrics→Prometheus |

## Prerequisite (giữ cài tay — KHÔNG quản qua app-of-apps này)
`cert-manager`, `grafana-operator`, `otel-operator`, `opentelemetry-operator`
(Instrumentation auto-inject) — chúng cài CRD, adopt CRD rủi ro nên để nguyên.

## Quy trình "nhận nuôi" (adopt) stack đang chạy — sync TAY, an toàn trước
Các Application để **manual sync** + `ServerSideApply`. Làm theo thứ tự rủi ro tăng dần:

1. **Custom charts (an toàn nhất, giá trị cao — provision dashboard):**
   ```bash
   helm uninstall grafana-yas -n observability   # gỡ helm release cũ (Grafana là external, KHÔNG mất UI)
   helm uninstall opentelemetry -n observability # collector dừng vài giây
   argocd app sync yas-observability-grafana yas-observability-otel-collector
   ```
2. **promtail, tempo** (không có PVC quan trọng): `argocd app sync yas-observability-promtail yas-observability-tempo`
3. **loki, prometheus** (CÓ StatefulSet + PVC — dừng lại kiểm tra trước):
   `helm uninstall` rồi `argocd app sync` từng cái, xác nhận PVC giữ nguyên, data còn.

> Nếu chưa chắc bước 3, cứ dừng ở bước 1–2 (đã đạt reproducible cho phần cấu hình
> mình tự tinh chỉnh). Prometheus/Loki giữ helm cũ vẫn chạy bình thường.

## Rollback
`argocd app delete <app> --cascade=false` (giữ resource) rồi `helm install` lại từ values ở đây.
