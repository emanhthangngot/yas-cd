# YAS Lab 2 CD

This repository is the GitOps/CD source of truth for YAS Lab 2.

## Repository Boundary

- App and CI repo: `git@github.com:tzin1401/yas.git`
- CD and GitOps repo: `git@github.com:emanhthangngot/yas-cd.git`

The app repo owns source code, Jenkins CI, tests, Dockerfiles, and image builds. This repo owns Kubernetes desired state, ArgoCD applications, CD documentation, Spec Kit artifacts, and agent context.

## Layout

```text
base/                 Kustomize base for deployable YAS services
overlays/             dev, staging, and developer overlays
argocd/apps/          ArgoCD Application manifests
charts/               Helm chart snapshot used by Kustomize render
scripts/              GitOps validation scripts
docs/project02/       Lab 2 CD documentation and evidence guides
specs/                Spec Kit feature artifacts
.specify/             Spec Kit runtime/templates
.agents/              Agent context, playbooks, and Spec Kit skills
```

## Validation

```bash
scripts/validate-gitops.sh
```

Jenkins should update image tags through the repository contract script:

```bash
scripts/update-image-tag.sh dev cart main
scripts/update-image-tag.sh developer tax 9f2c4a1
scripts/update-image-tag.sh staging cart v1.2.3
```

For environment-level CD flows, use the higher-level scripts so only one
full-stack namespace is active on the single-node cluster:

```bash
scripts/promote-staging-release.sh v1.2.3
scripts/prepare-developer-preview.sh tax=9f2c4a1
scripts/teardown-developer.sh
scripts/activate-environment.sh dev
```

Never commit real secrets, kubeconfigs, tokens, SSH keys, Docker Hub credentials, Snyk tokens, SonarQube tokens, ArgoCD tokens, or Google Cloud service account keys.
