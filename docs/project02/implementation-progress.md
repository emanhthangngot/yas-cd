# Lab 2 CD Implementation Progress

Date: 2026-06-24
Branch checked: `lab2/task/tri-xuan`
CD repo: `git@github.com:emanhthangngot/yas-cd.git`
App repo: `git@github.com:tzin1401/yas.git`

This report separates verified local CD-repo work from work that must still be
performed on Jenkins, Google Cloud, Docker Hub, and the Kubernetes cluster.

## Current Status Summary

| Area | Status | Evidence Status |
|---|---|---|
| CD repo split | Done | Verified from repository layout and task checklist |
| GitOps manifests | Done locally | `dev`, `staging`, `developer` overlays render locally |
| ArgoCD app manifests | Done locally | Apps point to `yas-cd/main` |
| Staging immutable tag gate | Done locally | `scripts/validate-staging-immutable.sh` passes |
| Jenkins app-repo integration | Implemented in app repo commit `8001bbd4` | Requires Jenkins runtime verification |
| GCP VM / K3s / ArgoCD runtime | Not verified from this repo | Requires cloud/cluster evidence |
| Istio/Kiali mesh | Not verified from this repo | Requires cluster installation and screenshots/logs |

## 1. CD Repo Validation Fix

Status: implemented in this repo.

What was changed:

- Updated `docs/project02/context.md` so stale Kubernetes bootstrap wording no longer trips
  the GitOps validation script.
- Updated the same context file to reflect the current CD repo layout:
  `base/`, `overlays/`, `argocd/`, `charts/`, and `scripts/`.
- Clarified that Jenkins and cluster runtime work are still implementation tasks, not verified
  CD-repo state.

Setup already present:

- `scripts/validate-gitops.sh` validates service catalog, image lists, overlay rendering,
  staging immutable tags, stale source references, stale cluster bootstrap references, and
  secret-like patterns.
- `scripts/validate-staging-immutable.sh` enforces release-style tags for staging.
- `scripts/update-image-tag.sh` provides the Jenkins contract for updating image tags through
  GitOps.

Commands to verify:

```bash
scripts/validate-gitops.sh
scripts/validate-staging-immutable.sh
git status --short
```

Expected result:

- `GitOps validation passed`
- `staging immutability check passed: all staging image tags are release tags`
- Only intentional documentation changes should appear in `git status --short`.

## 2. GitOps Desired State

Status: implemented locally in this repo.

What is set up:

- `base/` contains shared Kubernetes desired state.
- `overlays/dev/` renders the dev namespace desired state.
- `overlays/staging/` renders the staging namespace desired state.
- `overlays/developer/` renders the developer namespace desired state.
- `charts/` contains the chart snapshot used by Kustomize/Helm rendering.
- `services.yaml` is the deployable service catalog snapshot.

Image tag policy:

- `dev` currently uses `main` tags.
- `developer` currently uses `main` tags until Jenkins updates selected services to branch
  commit tags.
- `staging` currently uses `v0.0.0` placeholder release tags and rejects mutable tags such as
  `latest`, `main`, or branch names.

Commands already used for local verification:

```bash
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/dev
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/developer
scripts/validate-staging-immutable.sh
```

Observed result:

- All three overlays rendered locally.
- Staging immutable-tag check passed.

Remaining work:

- Replace placeholder image tags with real Docker Hub tags produced by Jenkins.
- Confirm rendered manifests apply successfully to the real K3s cluster.
- Confirm platform dependencies required by YAS are installed or included before app sync.

## 3. ArgoCD Application Setup

Status: manifests implemented locally; cluster runtime not yet verified.

What is set up in this repo:

- `argocd/apps/yas-dev.yaml`
- `argocd/apps/yas-staging.yaml`
- `argocd/apps/yas-developer.yaml`

Configured source:

```text
repoURL: git@github.com:emanhthangngot/yas-cd.git
targetRevision: main
path: overlays/<environment>
```

Sync behavior:

- Automated sync is enabled.
- Prune is enabled.
- Self-heal is enabled.
- `CreateNamespace=true` is enabled.

Commands to run on the cluster:

```bash
kubectl apply -f argocd/apps/
argocd app list
argocd app wait yas-dev --health --sync --timeout 600
argocd app wait yas-staging --health --sync --timeout 600
argocd app wait yas-developer --health --sync --timeout 600
```

Evidence required after running:

- Screenshot or CLI output showing the three apps exist.
- `yas-dev`, `yas-staging`, and `yas-developer` are `Synced/Healthy`.
- GitOps source shown as `yas-cd`, branch `main`.

Remaining work:

- Install/configure ArgoCD in the K3s cluster.
- Add repo credentials for SSH access to the CD repo.
- Apply the app manifests and capture sync evidence.

## 4. App Repo Jenkins Integration

Status: implemented in app repo commit `8001bbd4`; not yet verified by a real Jenkins run.

What was implemented:

- Changed the app repo Jenkins agent label from `yas-build-worker` to `gcp-build-agent`.
- Added Jenkins parameter `DEPLOY_TO_DEVELOPER` for feature-branch developer overlay updates.
- Added Docker Hub image build/push stage after the existing Lab 1 gates.
- Added GitOps update stage that clones `git@github.com:emanhthangngot/yas-cd.git`,
  runs `scripts/update-image-tag.sh`, runs CD repo validation through that script, commits,
  rebases, and pushes to `yas-cd/main`.
- Updated `docs/project02/jenkins-jobs.md` in the app repo to describe the split-repo flow.

What was intentionally preserved:

- Changed-module detection.
- Gitleaks.
- Test and JaCoCo report.
- Coverage gate.
- Maven build.
- SonarQube analysis and quality gate wait.
- Snyk dependency scan.

Required Jenkins controller/agent setup:

- Jenkins Controller remains on AWS EC2 `3.27.92.213`.
- GCP VM `gcp-ci-cd-agent` acts as inbound Jenkins Agent.
- Jenkins node name should be `gcp-agent`.
- Jenkins node label must be `gcp-build-agent`.
- Recommended executors: `4`.
- Java runtime on the agent must be Java 21 to match Jenkins Controller.

Required Jenkins credentials:

- `dockerhub-creds`: Docker Hub username and access token.
- `github-gitops-ssh`: deploy key or SSH key with push access to `yas-cd`.
- `sonarqube-token`: existing Lab 1 credential.
- `snyk-token`: existing Lab 1 credential.
- Optional for smoke checks: `argocd-token`, `kubeconfig-readonly`.

Required Jenkinsfile behavior:

- Keep Lab 1 gates: changed-module detection, tests, JaCoCo, coverage gate, build, Gitleaks,
  SonarQube, and Snyk.
- Build/push Docker Hub images for deployable changed services.
- Feature branch image tags: commit SHA.
- `main` image tags: commit SHA, `main`, and `latest`.
- release tag image tags: commit SHA and `vX.Y.Z`.
- Clone `git@github.com:emanhthangngot/yas-cd.git`.
- Run `scripts/update-image-tag.sh "$TARGET_ENV" "$SERVICE_NAME" "$IMAGE_TAG"`.
- Run `scripts/validate-gitops.sh`.
- Commit and push only GitOps desired-state changes to `yas-cd/main`.

Commands Jenkins should effectively perform inside the GitOps repo:

```bash
git clone "$GITOPS_REPO" yas-cd
cd yas-cd
git checkout "$GITOPS_BRANCH"
scripts/update-image-tag.sh "$TARGET_ENV" "$SERVICE_NAME" "$IMAGE_TAG"
git status --short
git add services.yaml overlays
git commit -m "cd(lab2): update ${TARGET_ENV} image tags [skip ci]"
git pull --rebase origin "$GITOPS_BRANCH"
git push origin "$GITOPS_BRANCH"
```

Evidence required:

- Jenkins build log showing the job used node label `gcp-build-agent`.
- Jenkins log showing Docker Hub push for commit SHA tags.
- Jenkins log showing GitOps clone/update/validate/commit/push.
- Git commit in `yas-cd/main` updating `overlays/<env>/kustomization.yaml`.

Remaining work:

- Create or update Jenkins jobs: `developer_build`, `teardown_developer`, `deploy_dev`,
  `release_staging`, `rollback_environment`, and `cluster_smoke_check`.
- Run `yas-ci-multibranch` on the real Jenkins controller/agent.
- Confirm Docker Hub receives commit SHA, `main/latest`, and `vX.Y.Z` tags.
- Confirm Jenkins can authenticate with `github-gitops-ssh` and push to `yas-cd/main`.
- Verify GitOps commits do not trigger full app CI.

## 5. GCP VM And K3s Setup

Status: runbook exists; cluster installation not verified from this repo.

Target VM:

- Provider: Google Cloud Compute Engine.
- Instance: `gcp-ci-cd-agent`.
- OS: Ubuntu 24.04 LTS.
- RAM: 32 GB.
- Recommended CPU: 4-8 vCPU.
- Recommended disk: 150 GB or more.

Firewall policy:

- SSH must be restricted to admin IP.
- Demo ports may be open only for the required demo audience.
- Admin surfaces must not be broadly public: Jenkins, ArgoCD, Kiali, Kubernetes API, databases,
  and admin consoles.

K3s install command from the runbook:

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

Tools to install on the VM:

- Java 21.
- Git.
- Docker or the selected container build runtime.
- Helm.
- `yq`.
- `kustomize`.
- `kubectl`.
- `argocd` CLI.
- `istioctl`.

Verification commands:

```bash
java -version
docker version
kubectl version --client
helm version --short
yq --version
kustomize version
argocd version --client
istioctl version --remote=false
kubectl get nodes -o wide
kubectl describe node gcp-ci-cd-agent
kubectl get pods -A
kubectl get storageclass,pvc -A
systemctl status k3s --no-pager
```

Evidence required:

- GCP VM machine type, memory, disk, and OS screenshot/output.
- Firewall rules screenshot/output.
- Tool version outputs.
- K3s node and storage outputs.

Remaining work:

- Run the VM/bootstrap commands on the actual GCP VM.
- Capture evidence and mark the related checklist items complete.

## 6. Ingress, App Access, And DNS

Status: documented; cluster runtime not verified from this repo.

Target NodePorts:

- Nginx Ingress HTTP: `30080`.
- Nginx Ingress HTTPS: `30081`.
- Istio IngressGateway HTTP: `30090`.
- Istio IngressGateway HTTPS: `30490`.

Hosts-file entries for demo clients:

```text
<GCP_VM_EXTERNAL_IP> yas.dev.local
<GCP_VM_EXTERNAL_IP> yas.staging.local
<GCP_VM_EXTERNAL_IP> yas.developer.local
<GCP_VM_EXTERNAL_IP> yas.mesh.local
```

Basic app checks:

```bash
curl -H "Host: yas.dev.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
curl -H "Host: yas.staging.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
curl -H "Host: yas.developer.local" "http://${GCP_VM_EXTERNAL_IP}:30080/"
```

Evidence required:

- Ingress controller pods and services.
- Successful curl/browser output for dev, staging, and developer.
- Firewall proof that demo ports are intentionally exposed and admin ports are restricted.

Remaining work:

- Install Nginx Ingress on the cluster.
- Confirm NodePort mapping.
- Capture app access evidence after ArgoCD sync.

## 7. Developer, Dev, And Staging Deployment Flows

Status: GitOps overlay mechanism exists; end-to-end deployment flows not verified.

Developer flow:

- Jenkins `developer_build` should accept branch/service input.
- It should build the selected service image and tag it by commit SHA.
- It should update only the selected service in `overlays/developer/kustomization.yaml`.
- ArgoCD should sync `yas-developer`.

Dev flow:

- Merge/push to `main` should produce commit SHA, `main`, and `latest` Docker Hub tags.
- Jenkins should update `overlays/dev/kustomization.yaml`.
- ArgoCD should sync `yas-dev`.

Staging flow:

- Git tag `vX.Y.Z` should produce commit SHA and release Docker Hub tags.
- Jenkins should update `overlays/staging/kustomization.yaml` only with `vX.Y.Z` tags.
- `scripts/validate-staging-immutable.sh` must pass before push.
- ArgoCD should sync `yas-staging`.

Rollback/teardown:

- Rollback should revert overlay tags or revert a GitOps commit.
- Developer teardown should remove or disable developer desired state through GitOps and let
  ArgoCD prune.

Evidence required:

- Jenkins logs for each flow.
- Docker Hub screenshots for tags.
- GitOps diffs and commits.
- ArgoCD `Synced/Healthy` output.
- Curl/browser output for each environment.

Remaining work:

- Implement Jenkins jobs in the app repo.
- Run the flows against the real cluster.
- Capture evidence.

## 8. Istio And Kiali Mesh

Status: runbook exists; mesh not verified from this repo.

Target setup:

- Install Istio after the basic GitOps deployment works.
- Install Kiali for topology visualization.
- Enable sidecar injection on the selected namespace.
- Restart workloads so pods show READY `2/2`.

Commands to capture during setup:

```bash
kubectl label namespace dev istio-injection=enabled --overwrite
kubectl get namespace dev --show-labels
kubectl rollout restart deployment -n dev
kubectl rollout status deployment -n dev
kubectl get pods -n dev
```

Mesh acceptance evidence:

- STRICT mTLS configured.
- AuthorizationPolicy allow and deny curl logs.
- Retry behavior curl logs.
- Kiali graph screenshot.

Mesh access check:

```bash
curl -H "Host: yas.mesh.local" "http://${GCP_VM_EXTERNAL_IP}:30090/"
```

Remaining work:

- Install Istio/Kiali on the K3s cluster.
- Apply mTLS, authorization, and retry policies.
- Capture the required logs and screenshots.

## 9. Final Report Pack

Status: checklist exists; evidence still needs to be collected from runtime systems.

Files to keep updated:

- `docs/project02/implementation-progress.md`
- `docs/project02/cluster-runbook.md`
- `docs/project02/jenkins-jobs.md`
- `docs/project02/mesh-runbook.md`
- `.agents/evidence/README.md`
- `specs/001-yas-lab2-cd/tasks.md`

Required final pack:

- GCP VM and firewall evidence.
- Kubernetes node, pod, and storage evidence.
- Jenkins CI/CD logs.
- Docker Hub tag screenshots.
- GitOps commits and diffs.
- ArgoCD app screenshots.
- App curl/browser evidence.
- Mesh mTLS, authorization, retry, and Kiali evidence.
- Production reality check.

Completion rule:

- Do not mark runtime tasks complete until there is command output, screenshot, Jenkins log,
  ArgoCD output, or Git commit evidence proving the step ran successfully.
