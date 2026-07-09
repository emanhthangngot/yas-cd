# CD Flows — Demo Run Summary (2026-07-06)

Cả 3 luồng CD theo yêu cầu đề bài đã chạy thật, có log/commit làm bằng chứng.

## 1. Dev — auto deploy (đề mục 6a)
- `main` thay đổi → Jenkins build image tag commit-SHA → tự commit vào `yas-cd` → ArgoCD auto-sync.
- Bằng chứng: chuỗi commit `jenkins-cd` "update dev image tags [skip ci]" trong lịch sử `yas-cd`.

## 2. Staging — release có duyệt (đề mục 6b)
- Tag `vX.Y.Z` trên `main` app repo → Jenkins promote image (build-once/promote-many, KHÔNG rebuild) → commit `yas-cd` → ArgoCD `yas-staging` là **manual-sync**, đứng chờ người duyệt → operator bấm SYNC.
- Hành trình 4 lần chạy (câu chuyện "release trưởng thành qua từng lần fail"):
  - `v0.1.0` → FAIL: gate GitOps chặn do tag đóng nhầm commit cũ (services.yaml 20 vs overlay 15). Evidence: `21_jenkins_v010_gate_blocked.txt`
  - `v0.1.1` (lần 1) → FAIL: agent thiếu `docker buildx`. Evidence: `21b_jenkins_v011_buildx_missing.txt`
  - `v0.1.1` (lần 2) → FAIL: promote đòi mọi service cùng 1 SHA nhưng dev trộn tag (13 SHA + 2 UI ở `main`). Evidence: `21c_jenkins_v011_mixed_tag_promote_fail.txt`
  - `v0.1.3` → **SUCCESS**: sau 2 cải tiến Jenkinsfile (promote theo tag dev-overlay từng service; skip test/scan trên tag build). Jenkins tag pipeline chạy thành công và staging nhận release tag `:v0.1.3`. Evidence: `21e_jenkins_v013_release_success.txt`, `latex-report/img/jenkins/release_v013_success.png`, `24_argocd_outofsync_diff.png`
- 2 cải tiến đã merge (PR trên `tzin1401/yas`):
  1. `promote release images from dev overlay tags, not tagged-commit SHA` — sửa gốc lỗi mixed-tag.
  2. `skip test/scan gates on release-tag builds (promote-only)` — release chỉ verify+promote+GitOps, gate CI được thừa kế từ build main đã publish image nguồn (provenance).

## 3. Developer — preview on-demand (đề mục 4 + 5)
- Job `developer_build` (tạo mới `Jenkinsfile.developer-build` trong `yas-cd`): parameter ACTION/APP_BRANCH/SERVICES/CONFIRM.
- `ACTION=preview APP_BRANCH=dev_tax_service SERVICES=tax`: build image branch → verify trên Docker Hub → GitOps commit đánh thức `developer` (tax = SHA branch `033fa258746b`, còn lại `main`), cho `staging` ngủ (policy active_limit=2). Evidence: `28_developer_build_console.txt`, `29_preview_commit.txt`, `31_developer_up_staging_down.txt`, `32_developer_reachable.png`
- `ACTION=teardown` (đề mục 5): trả về baseline (developer dormant, dev+staging active). Evidence: `33_teardown_console.txt`
- Xác nhận runtime: `kubectl top nodes` 49% CPU / 51% RAM khi dev+developer song song — chứng minh single-node đủ tải nhờ active_limit=2.

## Known issue (không thuộc luồng CD)
- Service `payment` crash khi staging restart: `liquibase ValidationFailedException` (checksum mismatch trong `staging_payment` DB do image cũ migrate trước đó). Đây là lỗi runtime/app-level, KHÔNG ảnh hưởng luồng CD — image `v0.1.3` vẫn pull & deploy đúng; storefront vẫn truy cập được. Production reality check: cần migration idempotent / cơ chế clear-checksums khi đổi image version trên DB bền.
