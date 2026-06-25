# YAS Lab 2 CD Agent Rules

## Source Of Truth

- App/CI repo: `git@github.com:tzin1401/yas.git`
- CD/GitOps repo: `git@github.com:emanhthangngot/yas-cd.git`
- CD branch: `main` for ArgoCD sync; feature work may use `lab2/task/*`
- Service catalog snapshot: `services.yaml`
- SDD: `.specify/memory/constitution.md` and `specs/001-yas-lab2-cd/`
- GitOps desired state: `base/**`, `overlays/**`, `argocd/**`
- Project docs: `docs/project02/**`

## Target Platform

- Jenkins Controller (Master) runs on AWS EC2 (`3.27.92.213`).
- One Google Cloud Compute Engine VM (`gcp-ci-cd-agent`) with 32 GB RAM.
- This GCP VM acts as Jenkins Agent (CI) with label `gcp-build-agent` AND runs Kubernetes.
- Kubernetes: `k3s` single-node on Ubuntu 24.04 LTS.
- Workloads run on the K3s server node; no manual scheduling change is required.
- No Tailscale.
- Default storage is K3s bundled local-path and lab-only.
- App/demo access uses NodePorts. Jenkins, ArgoCD, Kiali, Kubernetes API, databases, and admin consoles must not be broadly public.

## Hard Rules

- Never commit real secrets, kubeconfig files, tokens, Docker Hub passwords, Snyk tokens, SonarQube tokens, SSH private keys, ArgoCD tokens, or Google Cloud service account keys.
- Never run `kubectl set image` or direct `kubectl apply` into ArgoCD-managed namespaces: `dev`, `staging`, `developer`.
- Jenkins in the app repo updates this CD repo only; ArgoCD owns cluster sync.
- Final CD images use Docker Hub: `docker.io/$DOCKERHUB_USERNAME/yas-<service>:<tag>`.
- Do not use mutable `latest` in staging.
- Do not weaken Lab 1 CI gates in the app repo: Gitleaks, tests, JaCoCo coverage, build, SonarQube, and Snyk.
- Do not hardcode service lists when `services.yaml` can be used.

## Required Checks Before Commit

- Run `git status --short`.
- Validate `services.yaml` parses.
- Render changed Kustomize overlays.
- Run `scripts/validate-staging-immutable.sh` when staging changes.
- Confirm no real secret appears in staged diff.
- Update `docs/project02/**` or `.agents/evidence/README.md` when deployment behavior changes.

## Commit Style

- `docs(lab2): ...`
- `gitops(lab2): ...`
- `mesh(lab2): ...`
- `cd(lab2): ...`

<!-- SPECKIT START -->
For additional context about technologies, project structure, runtime
constraints, and validation flows, read `specs/001-yas-lab2-cd/plan.md`.
<!-- SPECKIT END -->
