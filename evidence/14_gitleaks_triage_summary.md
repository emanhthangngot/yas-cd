# Gitleaks Triage Summary (2026-07-05)

## Repo yas-cd (GitOps)
- Findings: 0 trong toàn bộ lịch sử Git (report: 12_gitleaks_yas_cd.json).

## Repo yas (app, fork từ nashtech-garage/yas)
- Findings: 124, quy về 11 chuỗi duy nhất, tất cả rule generic-api-key.
- Phân loại: 100% là credential GIẢ phục vụ test/demo, thừa kế từ lịch sử upstream
  (test-realm.json cho integration test Keycloak, realm-export.json, k8s-deployment mẫu).
- Tác giả các commit chứa finding: toàn bộ là contributor NashTech upstream,
  KHÔNG có commit nào của team (danh sách tác giả đầy đủ xem 13_gitleaks_yas_app_repo.json).
- Kết luận: không có secret thật bị lộ; không yêu cầu rotate.
- Ghi chú production reality check: nếu là dự án thật, nên thêm gitleaks vào CI gate
  và dùng .gitleaksignore cho các fixture test đã xác minh.

## Vấn đề secret còn mở (độc lập với gitleaks)
- base/yas-configuration.yaml (yas-cd) vẫn commit Secret plaintext (mật khẩu lab),
  trái runtime-governance.yaml secret_policy (committed_form: sealed-secret).
  Xử lý theo quyết định team: SealedSecret hoặc ghi nhận rủi ro. (mục B2)
