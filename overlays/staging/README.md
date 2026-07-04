# Staging Overlay

Staging represents immutable release deployments.

- Namespace: `staging`
- Tags must be release tags such as `v1.2.3`.
- Do not deploy `latest`, `main`, or branch names.
- Default state is dormant through `replicas-dormant.yaml`.
- Jenkins must activate staging with `scripts/promote-staging-release.sh <release-tag>`.

Promote and activate staging:

```bash
scripts/promote-staging-release.sh v1.2.3
```

Return to the default active `dev` environment after validation:

```bash
scripts/activate-environment.sh dev
```

Validate:

```bash
scripts/validate-staging-immutable.sh
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging
```
