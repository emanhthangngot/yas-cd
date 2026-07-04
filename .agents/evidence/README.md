# Evidence Checklist

Progress report:

- `docs/project02/implementation-progress.md` records what has been implemented locally,
  what still requires Jenkins/GCP/Kubernetes runtime execution, and which evidence is needed
  before marking each milestone complete.

- [ ] Tool gate output: `yq --version`
- [ ] Tool gate output: `helm version --short`
- [ ] Tool gate output: `kustomize version`
- [ ] Tool gate output: `kubectl version --client`
- [ ] Tool gate output: `argocd version --client`
- [ ] Tool gate output: `istioctl version --remote=false`
- [ ] GCP VM evidence: machine type, 32 GB-class RAM, disk size, Ubuntu version
- [ ] GCP firewall evidence: app/demo ports allowed as intended, admin ports restricted
- [ ] SSH tunnel command/evidence for Jenkins, ArgoCD, or Kiali admin access
- [ ] `kubectl get nodes -o wide`
- [ ] `kubectl describe node <node>` capacity/allocatable summary
- [ ] `kubectl get pods -A`
- [ ] `kubectl get storageclass,pvc -A`
- [ ] `kubectl describe storageclass local-path`
- [ ] `services.yaml` parsed and matched against repo artifacts
- [ ] Helm/Kustomize render or dry-run output for changed manifests
- [ ] Jenkins `yas-ci-multibranch` successful run
- [ ] Docker Hub commit SHA image tag
- [ ] Docker Hub `main/latest` image tags
- [ ] Docker Hub `vX.Y.Z` release tag
- [ ] Staging GitOps diff contains immutable `vX.Y.Z` image tags only
- [ ] Staging mutable-tag gate shows no `latest`, `main`, or branch tag
- [ ] ArgoCD `yas-dev` Synced/Healthy
- [ ] ArgoCD `yas-staging` Synced/Healthy
- [ ] ArgoCD `yas-developer` Synced/Healthy
- [ ] `argocd app wait` output for required apps
- [ ] `developer_build` log showing branch-to-commit resolution
- [ ] `developer_build` log showing `scripts/prepare-developer-preview.sh <service=tag>`
- [ ] `yas-developer` active evidence with selected service commit-SHA image tags
- [ ] `teardown_developer` log showing GitOps prune
- [ ] `teardown_developer` log showing `scripts/teardown-developer.sh`
- [ ] Developer overlay reset to `main` image tags after teardown
- [ ] `rollback_environment` log showing revert
- [ ] `release_staging` log showing `scripts/promote-staging-release.sh vX.Y.Z`
- [ ] `yas-staging` active evidence with immutable release image tags
- [ ] `scripts/activate-environment.sh dev` evidence after staging validation
- [ ] App URL reachable via GCP VM external IP plus hosts file or Host header
- [ ] Mesh namespace decision recorded: `dev` first, `developer` fallback only if needed
- [ ] Mesh namespace label output: `kubectl label namespace ... istio-injection=enabled --overwrite`
- [ ] Mesh namespace labels shown by `kubectl get namespace ... --show-labels`
- [ ] Mesh workload restart output: `kubectl rollout restart deployment -n <namespace>`
- [ ] Mesh rollout status output: `kubectl rollout status deployment -n <namespace>`
- [ ] Istio pod READY `2/2` from `kubectl get pods -n <namespace>`
- [ ] mTLS check output
- [ ] AuthorizationPolicy allow/deny curl logs
- [ ] Retry curl logs
- [ ] Kiali topology screenshot
- [ ] Production reality check section in report
