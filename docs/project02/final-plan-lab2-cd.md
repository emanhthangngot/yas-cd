# Final Plan Lab 2 CD Cho YAS

## Summary

- App/CI repo: `git@github.com:tzin1401/yas.git`.
- CD/GitOps repo: `git@github.com:emanhthangngot/yas-cd.git`.
- App repo giữ Lab 1 Jenkins CI: changed-module detection, Gitleaks, JUnit/JaCoCo, coverage gate 70%, Maven build, SonarQube, Snyk, Docker image build/push.
- CD repo giữ Kubernetes desired state: Kustomize base/overlays, ArgoCD apps, chart snapshot, runbooks, Spec Kit artifacts, and agent context.
- Runtime target: one Google Cloud VM 32 GB, Ubuntu 24.04, `k3s` single-node Kubernetes. No Tailscale.

## Workflow

```text
Developer push code to tzin1401/yas
  -> Jenkins CI gates in app repo
  -> Jenkins builds and pushes Docker Hub images
  -> Jenkins clones emanhthangngot/yas-cd
  -> Jenkins updates overlays/<env>/kustomization.yaml
  -> Jenkins pushes yas-cd/main
  -> ArgoCD syncs dev/staging/developer from yas-cd/main
```

## Acceptance Checklist

- ArgoCD Application manifests point to `git@github.com:emanhthangngot/yas-cd.git`.
- `dev`, `staging`, and `developer` overlays render from this repo.
- Staging uses only immutable release tags such as `vX.Y.Z`.
- Jenkins does not run `kubectl set image` or direct `kubectl apply` into ArgoCD-managed namespaces.
- App repo keeps Lab 1 CI gates intact.
- No real secrets are committed.
- GCP firewall/admin access is documented.
