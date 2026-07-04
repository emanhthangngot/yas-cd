# Staging Overlay

Staging represents immutable release deployments.

- Namespace: `staging`
- Tags must be release tags such as `v1.2.3`.
- Do not deploy `latest`, `main`, or branch names.
- Default state is active through `replicas-active.yaml`.
- Rollouts use `maxSurge: 0` and `maxUnavailable: 1` so staging does not double
  Java pods during updates on the single-node GCP lab VM.
- Jenkins must promote immutable release tags with `scripts/promote-staging-release.sh <release-tag>`.

Promote and activate staging:

```bash
scripts/promote-staging-release.sh v1.2.3
```

Restore the baseline runtime after validation:

```bash
scripts/activate-environment.sh baseline
```

Validate:

```bash
scripts/validate-staging-immutable.sh
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging
```
