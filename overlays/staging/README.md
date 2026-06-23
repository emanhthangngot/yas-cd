# Staging Overlay

Staging represents immutable release deployments.

- Namespace: `staging`
- Tags must be release tags such as `v1.2.3`.
- Do not deploy `latest`, `main`, or branch names.

Validate:

```bash
scripts/validate-staging-immutable.sh
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging
```
