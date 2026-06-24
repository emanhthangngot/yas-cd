# Hướng Dẫn Từng Bước Triển Khai Runtime YAS Lab 2 CD

Ngày cập nhật: 2026-06-24

File này hướng dẫn từng bước phần còn phải làm trên hạ tầng thật: Google Cloud VM, Jenkins,
K3s, ArgoCD, Docker Hub, Istio/Kiali và evidence báo cáo.

Trạng thái hiện tại:

- App repo branch `lab2/cd-platform` đã có Jenkins CD integration.
- CD repo branch `lab2/task/tri-xuan` đã có GitOps manifests, validation scripts, runbooks và
  progress report.
- Phần runtime evidence vẫn chưa có. Chỉ tick task runtime khi đã có output lệnh, screenshot,
  Jenkins log, ArgoCD output hoặc Git commit chứng minh.

## 0. Chuẩn Bị Biến Cần Dùng

Điền các giá trị này trước khi chạy lệnh:

```bash
export GCP_VM_EXTERNAL_IP="34.70.63.208" # IP Public của VM gcp-ci-cd-agent (Đã tự động phát hiện và điền)
export GCP_VM_INTERNAL_IP="10.128.0.2" # IP Private của VM gcp-ci-cd-agent (Đã tự động phát hiện và điền)
export ADMIN_SOURCE_CIDR="171.233.99.240/32" # IP máy local hiện tại của bạn (Đã tự động phát hiện và điền)
export GCP_VM_USER="xuantri" # Tên người dùng SSH VM (Đã tự động phát hiện và điền)
export DOCKERHUB_USERNAME="emanhthangngot" # Username Docker Hub của bạn (Đã tự động phát hiện và điền)
```

Repo cần dùng:

```text
App repo: git@github.com:tzin1401/yas.git
App branch: lab2/cd-platform

CD repo: git@github.com:emanhthangngot/yas-cd.git
CD branch đang làm: lab2/task/tri-xuan
Branch ArgoCD sync: main
```

Jenkins credential IDs bắt buộc:

```text
dockerhub-creds
github-gitops-ssh
sonarqube-token
snyk-token
```

Credential IDs tùy chọn cho smoke check:

```text
argocd-token
kubeconfig-readonly
```

## 1. Đồng Bộ Hai Repo Về Bản Mới Nhất

Chạy trên máy local:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas
git fetch origin
git checkout lab2/cd-platform
git pull --ff-only origin lab2/cd-platform
git log -3 --oneline
git status --short

cd /home/pearspringmind/Studying/Devops/Lab2/yas-cd
git fetch origin
git checkout lab2/task/tri-xuan
git pull --ff-only origin lab2/task/tri-xuan
git log -5 --oneline
git status --short
```

Kết quả mong đợi:

- App repo có commit `4719f8ad` hoặc mới hơn.
- CD repo có commit `791476a` hoặc mới hơn.
- Cả hai repo đều clean.

Evidence cần lưu:

- Output `git log`.
- Output `git status`.

Dừng lại nếu:

- Repo có thay đổi local chưa rõ nguồn gốc.
- Jenkinsfile app repo không có `gcp-build-agent`.
- CD repo validation không pass.

## 2. Validate CD Repo Trước Khi Đụng Hạ Tầng

Chạy:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas-cd
yq e '.services | length' services.yaml
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/dev >/tmp/yas-dev.yaml
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging >/tmp/yas-staging.yaml
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/developer >/tmp/yas-developer.yaml
scripts/validate-staging-immutable.sh
scripts/validate-gitops.sh
```

Kết quả mong đợi:

- `services.yaml` trả về `22`.
- Cả ba overlay render thành công.
- `validate-staging-immutable.sh` pass.
- `validate-gitops.sh` in `GitOps validation passed`.

Evidence cần lưu:

- Output terminal.
- Có thể lưu các file render trong `/tmp` nếu cần đính kèm báo cáo.

## 3. Kiểm Tra Hoặc Tạo Firewall Rules Trên GCP

Làm trên Google Cloud Console hoặc máy có `gcloud`.

Chính sách port cần có:

```text
22/tcp      chỉ cho ADMIN_SOURCE_CIDR
30080/tcp   cho audience demo Nginx HTTP
30081/tcp   cho audience demo Nginx HTTPS nếu cần
30090/tcp   cho audience demo Istio HTTP
30490/tcp   cho audience demo Istio HTTPS nếu cần
8080/tcp    admin only hoặc SSH tunnel
30444/tcp   admin only hoặc SSH tunnel
30201/tcp   admin only hoặc SSH tunnel
6443/tcp    hạn chế, không mở rộng rãi
```

Nếu dùng `gcloud`, lệnh mẫu:

```bash
gcloud compute firewall-rules list

gcloud compute firewall-rules create yas-ssh-admin \
  --allow tcp:22 \
  --source-ranges "$ADMIN_SOURCE_CIDR" \
  --target-tags yas-lab2

gcloud compute firewall-rules create yas-demo-nodeports \
  --allow tcp:30080,tcp:30081,tcp:30090,tcp:30490 \
  --source-ranges "0.0.0.0/0" \
  --target-tags yas-lab2
```

Với admin UI, ưu tiên SSH tunnel:

```bash
ssh -L 8080:127.0.0.1:8080 \
    -L 30444:127.0.0.1:30444 \
    -L 30201:127.0.0.1:30201 \
    "${GCP_VM_USER}@${GCP_VM_EXTERNAL_IP}"
```

Kết quả mong đợi:

- Port demo mở đúng phạm vi cần demo.
- Jenkins, ArgoCD, Kiali, Kubernetes API, database/admin console không mở public `0.0.0.0/0`.

Evidence cần lưu:

- Screenshot cấu hình VM.
- Screenshot hoặc CLI output firewall rules.

## 4. SSH Vào GCP VM

Chạy:

```bash
ssh "${GCP_VM_USER}@${GCP_VM_EXTERNAL_IP}"
```

Trên VM, ghi lại thông tin máy:

```bash
hostname
lsb_release -a || cat /etc/os-release
nproc
free -h
df -h
ip addr
```

Kết quả mong đợi:

- Host là `gcp-ci-cd-agent` hoặc map rõ về VM này.
- OS là Ubuntu 24.04 LTS.
- RAM khoảng 32 GB.
- Disk đủ lớn cho image và cluster data.

Evidence cần lưu:

- Output các lệnh trên.

## 5. Cài Base Tools Trên GCP VM

Chạy trên VM:

```bash
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  git \
  jq \
  unzip \
  apt-transport-https \
  software-properties-common
```

Cài Java 21:

```bash
sudo apt-get install -y openjdk-21-jre-headless
java -version
```

Kết quả mong đợi:

- `java -version` là Java 21.

Evidence cần lưu:

- Output `java -version`.

## 6. Cài Docker Trên GCP VM

Chạy trên VM:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
```

Đăng xuất SSH rồi đăng nhập lại, sau đó verify:

```bash
docker version
docker compose version
```

Kết quả mong đợi:

- Docker client/server chạy được.
- User hiện tại chạy Docker không cần `sudo`.

Evidence cần lưu:

- Output `docker version`.

## 7. Cài CLI Tools Trên GCP VM

Cài `yq`:

```bash
sudo wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
yq --version
```

Cài Helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version --short
```

Cài Kustomize:

```bash
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/kustomize
kustomize version
```

Cài ArgoCD CLI:

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
argocd version --client
```

Cài Istio CLI:

```bash
curl -L https://istio.io/downloadIstio | sh -
sudo install -m 555 istio-*/bin/istioctl /usr/local/bin/istioctl
istioctl version --remote=false
```

Evidence cần lưu:

```bash
yq --version
helm version --short
kustomize version
argocd version --client
istioctl version --remote=false
```

## 8. Cài K3s Trên GCP VM

Chạy trên VM:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-name gcp-ci-cd-agent \
  --tls-san ${GCP_VM_INTERNAL_IP} \
  --tls-san ${GCP_VM_EXTERNAL_IP} \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb" sh -

mkdir -p "$HOME/.kube"
sudo cp -i /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
```

Verify:

```bash
kubectl get nodes -o wide
kubectl describe node gcp-ci-cd-agent
kubectl get pods -A
kubectl get storageclass,pvc -A
kubectl describe storageclass local-path
systemctl status k3s --no-pager
```

Kết quả mong đợi:

- Node `gcp-ci-cd-agent` ở trạng thái `Ready`.
- Có StorageClass `local-path`.
- Service `k3s` active.

Evidence cần lưu:

- Toàn bộ output verify ở trên.

Dừng lại nếu:

- Node không `Ready`.
- CoreDNS không running.
- Không có `local-path` StorageClass.

## 9. Clone CD Repo Trên GCP VM

Chạy:

```bash
mkdir -p "$HOME/lab2"
cd "$HOME/lab2"
git clone git@github.com:emanhthangngot/yas-cd.git
cd yas-cd
git checkout lab2/task/tri-xuan
git pull --ff-only origin lab2/task/tri-xuan
scripts/validate-gitops.sh
```

Kết quả mong đợi:

- Clone thành công.
- Validation pass.

Nếu SSH clone lỗi:

- Thêm public SSH key của VM user vào GitHub hoặc dùng deploy key hợp lệ.
- Không copy private key vào repo.

Evidence cần lưu:

```bash
git log -3 --oneline
scripts/validate-gitops.sh
```

## 10. Cài Nginx Ingress

Tạo values file:

```bash
cat > /tmp/ingress-nginx-nodeport-values.yaml <<'EOF'
controller:
  service:
    type: NodePort
    nodePorts:
      http: 30080
      https: 30081
EOF
```

Cài:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f /tmp/ingress-nginx-nodeport-values.yaml
```

Verify:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

Kết quả mong đợi:

- Pod ingress controller running.
- Service expose NodePort `30080` và `30081`.

Evidence cần lưu:

- Output pod và service.

## 11. Cài ArgoCD

Chạy:

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=600s
```

Expose ArgoCD bằng NodePort admin-only:

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"protocol":"TCP","targetPort":8080,"nodePort":30444},{"name":"https","port":443,"protocol":"TCP","targetPort":8080,"nodePort":30445}]}}'
kubectl get svc -n argocd argocd-server
```

Lấy initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

Login qua SSH tunnel hoặc firewall admin-only:

```bash
argocd login "${GCP_VM_EXTERNAL_IP}:30444" --username admin --password "<password>" --insecure
argocd version
```

Kết quả mong đợi:

- ArgoCD pods running.
- ArgoCD CLI login thành công.

Evidence cần lưu:

```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
argocd version
```

Không commit:

- ArgoCD admin password.
- ArgoCD token.

## 12. Add CD Repo Credential Vào ArgoCD

Nên dùng deploy key cho repo `emanhthangngot/yas-cd`.

Ví dụ:

```bash
argocd repo add git@github.com:emanhthangngot/yas-cd.git \
  --ssh-private-key-path "$HOME/.ssh/yas-cd-deploy-key"

argocd repo list
```

Kết quả mong đợi:

- Repo connection thành công.

Evidence cần lưu:

- Output `argocd repo list`, che/redact thông tin nhạy cảm nếu cần.

## 13. Apply ArgoCD Applications

Từ CD repo trên VM:

```bash
cd "$HOME/lab2/yas-cd"
kubectl apply -f argocd/apps/
argocd app list
```

Chờ sync:

```bash
argocd app wait yas-dev --health --sync --timeout 600
argocd app wait yas-staging --health --sync --timeout 600
argocd app wait yas-developer --health --sync --timeout 600
```

Kết quả mong đợi:

- Có apps `yas-dev`, `yas-staging`, `yas-developer`.
- Apps đạt `Synced/Healthy`.

Nếu app fail:

```bash
argocd app get yas-dev
argocd app get yas-staging
argocd app get yas-developer
kubectl get pods -A
kubectl describe pod -n dev <pod-name>
```

Nguyên nhân thường gặp:

- Thiếu platform dependencies.
- Thiếu CRD như `ServiceMonitor`.
- Docker Hub image tag chưa tồn tại.
- ArgoCD chưa đọc được CD repo.
- Placeholder `${DOCKERHUB_USERNAME}` chưa được thay bằng username thật.

Evidence cần lưu:

- `argocd app list`.
- Output `argocd app wait`.
- Screenshot ArgoCD UI.

## 14. Cấu Hình Jenkins GCP Agent

Trên Jenkins Controller `http://3.27.92.213:8080`, tạo/verify node:

```text
Name: gcp-agent
Remote root directory: /home/vinhp1546/jenkins
Label: gcp-build-agent
Executors: 4
Usage: Use this node as much as possible
Launch method: Launch agent by connecting it to the controller
Availability: Keep this agent online as much as possible
```

Trên GCP VM, tạo systemd service chạy inbound agent theo command từ Jenkins UI.

Template:

```ini
[Unit]
Description=Jenkins inbound agent
After=network-online.target docker.service
Wants=network-online.target

[Service]
User=vinhp1546
WorkingDirectory=/home/vinhp1546/jenkins
ExecStart=/usr/bin/java -jar /home/vinhp1546/jenkins/agent.jar -url http://3.27.92.213:8080/ -secret <SECRET_FROM_JENKINS> -name gcp-agent -workDir /home/vinhp1546/jenkins
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Cài service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now jenkins-agent
sudo systemctl status jenkins-agent --no-pager
```

Kết quả mong đợi:

- Jenkins UI hiển thị `gcp-agent` online.
- Agent dùng Java 21.
- Agent có Docker, Git, yq, quyền clone app repo và CD repo.

Evidence cần lưu:

- Screenshot Jenkins node online.
- Output `systemctl status jenkins-agent --no-pager`.

Không commit:

- JNLP secret.
- Jenkins token.

## 15. Cấu Hình Jenkins Credentials

Trong Jenkins, tạo/verify:

```text
dockerhub-creds
github-gitops-ssh
sonarqube-token
snyk-token
```

Yêu cầu:

- `dockerhub-creds`: username/password credential, password là Docker Hub access token.
- `github-gitops-ssh`: SSH key có quyền push vào `emanhthangngot/yas-cd`.
- `sonarqube-token`: token Lab 1 hiện có.
- `snyk-token`: token Lab 1 hiện có.

Evidence cần lưu:

- Screenshot credential IDs, không lộ giá trị.

## 16. Chạy Jenkins App Repo Pipeline

Trong Jenkins multibranch job của `tzin1401/yas`, scan branch source hoặc trigger branch
`lab2/cd-platform`.

Pipeline kỳ vọng:

```text
Checkout
Detect Changed Modules
Gitleaks
Test
Coverage Gate
Build
SonarQube
Snyk
Docker Hub - Build & Push Images
GitOps - Update CD Repo
```

Cần quan sát:

- Build chạy trên node label `gcp-build-agent`.
- Docker login thành công.
- Docker build thành công cho changed deployable services.
- Docker Hub có commit SHA tags.
- Jenkins clone `git@github.com:emanhthangngot/yas-cd.git`.
- Jenkins chạy `scripts/update-image-tag.sh`.
- Jenkins push GitOps commit vào `yas-cd/main`.

Evidence cần lưu:

- Jenkins build log.
- Screenshot Docker Hub tag.
- URL GitOps commit hoặc output `git log` trong `yas-cd`.

Dừng lại nếu:

- Jenkins không chạy Docker/GitOps stage như kỳ vọng.
- Jenkins chạy trên label cũ `yas-build-worker`.
- Jenkins dùng `kubectl set image` hoặc `kubectl apply` trực tiếp vào namespace `dev`,
  `staging`, `developer`.

## 17. Verify Docker Hub Tags

Với mỗi service thay đổi, verify tags.

Feature branch:

```text
docker.io/<DOCKERHUB_USERNAME>/yas-<service>:<commit-sha>
```

Main branch:

```text
docker.io/<DOCKERHUB_USERNAME>/yas-<service>:<commit-sha>
docker.io/<DOCKERHUB_USERNAME>/yas-<service>:main
docker.io/<DOCKERHUB_USERNAME>/yas-<service>:latest
```

Release tag:

```text
docker.io/<DOCKERHUB_USERNAME>/yas-<service>:<commit-sha>
docker.io/<DOCKERHUB_USERNAME>/yas-<service>:vX.Y.Z
```

Evidence cần lưu:

- Screenshot Docker Hub.
- Jenkins log dòng `docker push`.

## 18. Verify GitOps Commit Trong CD Repo

Chạy local hoặc trên VM:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas-cd
git fetch origin
git checkout main
git pull --ff-only origin main
git log -5 --oneline
git show --stat HEAD
git diff HEAD~1..HEAD -- overlays services.yaml
scripts/validate-gitops.sh
```

Kết quả mong đợi:

- Commit mới có dạng `cd(lab2): update ... image tags [skip ci]`.
- Overlay image tags thay đổi.
- Validation pass.
- Nếu target là staging, không có mutable tag.

Evidence cần lưu:

- `git show --stat HEAD`.
- Overlay diff.
- Validation output.

## 19. Verify ArgoCD Sync Sau GitOps Commit

Chạy:

```bash
argocd app list
argocd app get yas-dev
argocd app get yas-staging
argocd app get yas-developer
```

Chờ app tương ứng:

```bash
argocd app wait yas-dev --health --sync --timeout 600
```

hoặc:

```bash
argocd app wait yas-staging --health --sync --timeout 600
```

hoặc:

```bash
argocd app wait yas-developer --health --sync --timeout 600
```

Verify Kubernetes:

```bash
kubectl get pods -n dev
kubectl get deploy -n dev -o wide
kubectl get pods -n staging
kubectl get deploy -n staging -o wide
kubectl get pods -n developer
kubectl get deploy -n developer -o wide
```

Kết quả mong đợi:

- App đạt `Synced/Healthy`.
- Workloads rollout sang image tag mới.

Evidence cần lưu:

- ArgoCD CLI output.
- Screenshot ArgoCD UI.
- Output pod/deployment.

## 20. Verify App Access

Trên máy local, thêm hosts entries:

```text
<GCP_VM_EXTERNAL_IP> yas.dev.local
<GCP_VM_EXTERNAL_IP> yas.staging.local
<GCP_VM_EXTERNAL_IP> yas.developer.local
<GCP_VM_EXTERNAL_IP> yas.mesh.local
```

Test:

```bash
curl -H "Host: yas.dev.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
curl -H "Host: yas.staging.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
curl -H "Host: yas.developer.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
```

Kết quả mong đợi:

- App trả response qua Nginx Ingress.

Nếu curl fail:

```bash
kubectl get ingress -A
kubectl get svc -A
kubectl get pods -A
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=100
```

Evidence cần lưu:

- Curl output.
- Screenshot browser nếu có.

## 21. Chạy Developer Build Flow

Trong Jenkins:

- Chạy branch feature hoặc job developer.
- Set `DEPLOY_TO_DEVELOPER=true`.
- Nên thay đổi một service deployable để demo tập trung.

Kết quả mong đợi:

- Jenkins build image service được chọn với commit SHA tag.
- Jenkins update `overlays/developer`.
- ArgoCD sync `yas-developer`.
- Service không được chọn vẫn dùng `main`.

Verify:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas-cd
git fetch origin
git log -5 --oneline origin/main
git show origin/main:overlays/developer/kustomization.yaml | sed -n '1,160p'

argocd app wait yas-developer --health --sync --timeout 600
curl -H "Host: yas.developer.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
```

Evidence cần lưu:

- Jenkins log.
- GitOps diff.
- ArgoCD output.
- Curl output.

## 22. Chạy Dev Flow

Khi sẵn sàng, merge hoặc push vào `main` trong app repo.

Kết quả mong đợi:

- Jenkins tag image với commit SHA, `main`, `latest`.
- Jenkins update `overlays/dev`.
- ArgoCD sync `yas-dev`.

Verify:

```bash
argocd app wait yas-dev --health --sync --timeout 600
curl -H "Host: yas.dev.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
```

Evidence cần lưu:

- Jenkins log.
- Docker Hub tags.
- GitOps diff.
- ArgoCD/curl output.

## 23. Chạy Staging Release Flow

Tạo release tag trong app repo:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas
git checkout lab2/cd-platform
git pull --ff-only origin lab2/cd-platform
git tag v0.1.0
git push origin v0.1.0
```

Kết quả mong đợi:

- Jenkins chạy tag build.
- Docker Hub có tag `v0.1.0`.
- Jenkins update `overlays/staging` bằng `v0.1.0`.
- `scripts/validate-staging-immutable.sh` pass.
- ArgoCD sync `yas-staging`.

Verify:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas-cd
git fetch origin
git show origin/main:overlays/staging/kustomization.yaml | grep 'newTag:'
scripts/validate-staging-immutable.sh

argocd app wait yas-staging --health --sync --timeout 600
curl -H "Host: yas.staging.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
```

Evidence cần lưu:

- Git tag URL.
- Jenkins tag build log.
- Screenshot Docker Hub `v0.1.0`.
- Staging overlay diff.
- ArgoCD/curl output.

## 24. Rollback Flow

Rollback bằng cách revert GitOps commit hoặc set lại image tag cũ.

Cách khuyến nghị:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas-cd
git checkout main
git pull --ff-only origin main
git revert <bad-gitops-commit>
scripts/validate-gitops.sh
git push origin main
```

Verify:

```bash
argocd app wait yas-dev --health --sync --timeout 600
argocd app get yas-dev
```

Evidence cần lưu:

- Revert commit.
- ArgoCD sync output.
- Curl output sau rollback.

## 25. Developer Teardown Flow

Cách làm đúng:

- Xóa hoặc disable desired state developer qua GitOps.
- Để ArgoCD prune.
- Không tự tay xóa resource do ArgoCD quản lý, trừ khi emergency cleanup.

Verify:

```bash
argocd app get yas-developer
kubectl get all -n developer
```

Evidence cần lưu:

- Jenkins teardown log hoặc GitOps commit.
- ArgoCD prune evidence.
- Output resource namespace developer.

## 26. Cài Istio

Chỉ làm sau khi GitOps deployment cơ bản đã chạy ổn.

Chạy:

```bash
istioctl install --set profile=demo -y
kubectl get pods -n istio-system
```

Expose Istio ingress gateway qua NodePort `30090` và `30490`.

Inspect service:

```bash
kubectl get svc -n istio-system istio-ingressgateway -o yaml
```

Nếu cần patch NodePorts:

```bash
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"NodePort","ports":[{"name":"status-port","port":15021,"protocol":"TCP","targetPort":15021},{"name":"http2","port":80,"protocol":"TCP","targetPort":8080,"nodePort":30090},{"name":"https","port":443,"protocol":"TCP","targetPort":8443,"nodePort":30490}]}}'
```

Kết quả mong đợi:

- Istio control plane pods running.
- Istio ingress gateway expose đúng NodePorts.

Evidence cần lưu:

```bash
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

## 27. Bật Sidecar Injection

Bắt đầu với namespace `dev`:

```bash
kubectl label namespace dev istio-injection=enabled --overwrite
kubectl get namespace dev --show-labels
kubectl rollout restart deployment -n dev
kubectl rollout status deployment -n dev --timeout=600s
kubectl get pods -n dev
```

Kết quả mong đợi:

- Pods sau restart hiển thị READY `2/2`.

Evidence cần lưu:

- Namespace labels.
- Rollout output.
- Output pods READY `2/2`.

## 28. Cấu Hình mTLS STRICT

Tạo policy:

```bash
cat > /tmp/dev-peer-authentication.yaml <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: dev
spec:
  mtls:
    mode: STRICT
EOF

kubectl apply -f /tmp/dev-peer-authentication.yaml
kubectl get peerauthentication -n dev -o yaml
```

Kết quả mong đợi:

- Có `mode: STRICT`.

Evidence cần lưu:

- Output YAML policy.

## 29. AuthorizationPolicy Demo

Tạo deny policy cho một path/workload test, sau đó tạo allow policy cho caller hợp lệ.

Trước tiên lấy service account và service thật:

```bash
kubectl get serviceaccounts -n dev
kubectl get services -n dev
```

Sau đó viết policy theo tên service/service account thật. Không tự bịa tên.

Verify allow/deny bằng curl từ pod:

```bash
kubectl run curl-test -n dev --image=curlimages/curl:8.8.0 --restart=Never -- sleep 3600
kubectl exec -n dev curl-test -- curl -i http://<service-name>.<namespace>.svc.cluster.local/<path>
```

Kết quả mong đợi:

- Request bị deny trả `403` hoặc response deny tương ứng.
- Request được allow thành công.

Evidence cần lưu:

- AuthorizationPolicy YAML.
- Curl output allow.
- Curl output deny.

## 30. Retry Demo

Tạo hoặc cập nhật Istio `VirtualService` có retry policy cho service được chọn.

Mẫu:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: retry-demo
  namespace: dev
spec:
  hosts:
    - <service-name>
  http:
    - route:
        - destination:
            host: <service-name>
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx
```

Verify bằng curl và service logs.

Evidence cần lưu:

- VirtualService YAML.
- Curl output.
- Service logs thể hiện retry nếu có.

## 31. Cài Kiali

Chạy:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/addons/kiali.yaml
kubectl rollout status deployment/kiali -n istio-system --timeout=600s
kubectl get svc -n istio-system kiali
```

Truy cập bằng port-forward hoặc NodePort admin-only:

```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001
```

Mở:

```text
http://127.0.0.1:20001
```

Tạo traffic:

```bash
for i in $(seq 1 20); do
  curl -H "Host: yas.dev.local" "http://${GCP_VM_EXTERNAL_IP}:30080/" || true
done
```

Kết quả mong đợi:

- Kiali graph hiển thị traffic.
- Security indicators thể hiện mTLS nếu đã cấu hình đúng.

Evidence cần lưu:

- Screenshot Kiali topology.

## 32. Cập Nhật Evidence Checklist

Sau khi thu output/screenshot, cập nhật:

```text
/home/pearspringmind/Studying/Devops/Lab2/yas-cd/.agents/evidence/README.md
/home/pearspringmind/Studying/Devops/Lab2/yas-cd/docs/project02/implementation-progress.md
/home/pearspringmind/Studying/Devops/Lab2/yas-cd/specs/001-yas-lab2-cd/tasks.md
```

Chỉ tick task khi có một trong các bằng chứng:

- CLI output.
- Screenshot.
- Jenkins log.
- Git commit.
- ArgoCD output.
- Docker Hub evidence.

## 33. Final Validation Trước Khi Viết Báo Cáo

Trong CD repo:

```bash
cd /home/pearspringmind/Studying/Devops/Lab2/yas-cd
git status --short
yq e '.services | length' services.yaml
scripts/validate-gitops.sh
scripts/validate-staging-immutable.sh
```

Against cluster:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass,pvc -A
argocd app list
```

Kết quả mong đợi:

- Repo validation pass.
- Cluster healthy.
- ArgoCD apps `Synced/Healthy`.
- App URLs truy cập được.

## 34. Nội Dung Cần Nói Rõ Là Chưa Production-Ready

Đưa vào báo cáo cuối:

- K3s single-node không có high availability ở mức node.
- Local-path storage gắn với một VM, chỉ phù hợp lab.
- NodePort và hosts-file DNS phù hợp demo môn học, không phải production.
- Production nên dùng DNS, TLS, managed LoadBalancer/Ingress, RBAC least privilege và external
  secret management.
- Jenkins Docker access là shortcut cho lab; production nên dùng isolated builders.
- Admin UIs không được public rộng rãi.

## 35. Điều Kiện Dừng Lại Để Debug

Dừng lại nếu gặp một trong các trường hợp:

- Repo có thay đổi local không rõ nguồn gốc.
- `scripts/validate-gitops.sh` fail.
- Jenkins không chạy được trên `gcp-build-agent`.
- Docker Hub push fail.
- Jenkins không push được vào `yas-cd/main`.
- ArgoCD không đọc được CD repo.
- ArgoCD app không `Synced/Healthy`.
- Pods bị `ImagePullBackOff`, `CrashLoopBackOff`, hoặc `Pending`.
- Có secret value xuất hiện trong terminal output định dùng cho screenshot hoặc commit.
