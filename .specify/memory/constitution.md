# YAS Lab 2 CD Constitution

## Core Principles

### I. GitOps Is The Deployment Source Of Truth

ArgoCD-managed environments (`dev`, `staging`, `developer`) must be changed through this repository: `base/**`, `overlays/**`, and `argocd/**`. Jenkins may build images in the app repo and commit desired state here, but must not mutate these namespaces directly with `kubectl set image`, ad-hoc `kubectl apply`, or manual deletes.

### II. Two-Repository Boundary

`tzin1401/yas` is the app and CI repo. It owns source code, tests, Dockerfiles, Lab 1 CI gates, and image builds. `emanhthangngot/yas-cd` is the CD/GitOps repo. It owns Kubernetes desired state, ArgoCD apps, CD docs, Spec Kit artifacts, and agent context.

### III. Service Catalog First

CD automation must read from `services.yaml` or a generated view of that catalog. The app repo remains the source for build-time service metadata; this repo carries a render-time snapshot used by GitOps validation. Service name, image name, deployability, and dependencies must not drift.

### IV. Existing CI Gates Stay Enforced

Lab 2 extends the Lab 1 Jenkins pipeline in the app repo. Gitleaks, unit tests, JaCoCo reports, coverage threshold, Maven build, SonarQube, and Snyk must remain active for code/service changes. GitOps commits in this repo must not trigger full app CI.

### V. Immutable Images For CD

Feature/developer images use commit SHA tags. `main` may publish `main` and `latest` for lab dev. Staging uses release tags such as `vX.Y.Z` and must not deploy `latest`, `main`, or branch names.

### VI. GCP Single-Node Lab Boundary Must Be Explicit

The Lab 2 runtime target is a single Google Cloud Compute Engine VM with 32 GB RAM running `k3s` single-node Kubernetes. NodePort demo access, hosts-file DNS, K3s bundled local-path storage, demo credentials, and Jenkins Docker access are acceptable for this course lab only. Tailscale is not part of the current target.

## Technical Constraints

- App/CI repo: `git@github.com:tzin1401/yas.git`
- CD/GitOps repo: `git@github.com:emanhthangngot/yas-cd.git`
- ArgoCD target branch: `main`
- Container registry: Docker Hub, format `docker.io/$DOCKERHUB_USERNAME/yas-<service>:<tag>`
- Kubernetes runtime: one GCP Compute Engine VM, Ubuntu 24.04 LTS, `k3s` single-node, default local-path StorageClass
- Required environments: `dev`, `staging`, `developer`

## Development Workflow

1. Update SDD/spec/docs before major CD behavior changes.
2. Validate the catalog snapshot before changing overlays.
3. Render manifests before committing GitOps changes.
4. Keep credentials in Jenkins/Kubernetes secret stores, never in Git.
5. Capture command output/screenshots in the report evidence workflow.
6. Verify GCP firewall and SSH tunnel assumptions before publishing demo URLs.

## Governance

This constitution overrides local convenience. Any change that bypasses GitOps, weakens CI gates in the app repo, changes the Java/Spring version decision, reintroduces Tailscale as the Lab 2 network path, exposes admin UIs broadly, or introduces committed secrets must be rejected unless a new ADR is added under `docs/project02/` and approved by the team.

**Version**: 2.0.0 | **Ratified**: 2026-06-23 | **Last Amended**: 2026-06-23
