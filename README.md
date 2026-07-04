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
scripts/update-image-tag.sh staging cart v1.2.3
```

For environment-level CD flows, keep the baseline runtime active: `dev` and
`staging` run together while `developer` stays dormant.

```bash
scripts/promote-staging-release.sh v1.2.3
scripts/teardown-developer.sh
scripts/activate-environment.sh baseline
```

The default runtime follows the CQ demo service scope from
`docs/project02/service-scope-cq.md`: teacher-required services, the minimal
runtime dependencies for `order` and `tax`, `swagger-ui`, and `sampledata`
kept dormant after seeding.

Never commit real secrets, kubeconfigs, tokens, SSH keys, Docker Hub credentials, Snyk tokens, SonarQube tokens, ArgoCD tokens, or Google Cloud service account keys.
