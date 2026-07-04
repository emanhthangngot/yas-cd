# DevOps CD Playbook

## Jenkins

- Jenkins lives in the app repo `tzin1401/yas`.
- Keep Lab 1 CI gates intact in the app repo.
- Build and push Docker Hub images from the app repo.
- Clone this CD repo with credential ID `github-gitops-ssh`.
- Update `overlays/<env>/kustomization.yaml` here, commit, and push to `main`.
- Use `argocd-token` only for optional sync/get operations.
- Use `kubeconfig-readonly` only for read-only smoke checks.

## GitOps

- Update `overlays/<env>` and let ArgoCD sync.
- Do not mutate `dev`, `staging`, or `developer` namespaces directly.
- Render manifests before commit.
- Staging must use immutable `vX.Y.Z` tags only.

## Cluster

- One Google Cloud Compute Engine VM with 32 GB RAM.
- Ubuntu 24.04 LTS and `k3s` single-node Kubernetes.
- K3s server node schedules YAS workloads by default for this lab.
- Do not use Tailscale.
- Use K3s bundled local-path dynamic storage for lab PVCs only.
- Keep app/demo NodePorts stable: app/auth `30846`, Istio `30090/30490`; treat `30080/30081` as Traefik fallback unless re-verified.
- Keep ArgoCD `30444` and Kiali `30201` admin-only through SSH tunnel or GCP firewall allowlist.

## Evidence

Every demo step should produce command output or a screenshot suitable for the report: VM shape, firewall rules, Kubernetes node readiness, StorageClass/PVC state, ArgoCD health, Jenkins logs, GitOps diffs, Docker Hub tags, and app/mesh curl output.
