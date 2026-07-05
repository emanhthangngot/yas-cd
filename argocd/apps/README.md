# ArgoCD Applications

Apply these after ArgoCD is installed on the GCP VM cluster:

```bash
kubectl apply -f argocd/apps/
```

The applications track `git@github.com:emanhthangngot/yas-cd.git`, branch `main`, and sync these paths:

- `platform/base`
- `overlays/dev`
- `overlays/staging`
- `overlays/developer`
- `operations/sampledata-seed/dev` (manual sync only)
- `operations/sampledata-seed/staging` (manual sync only)

Do not point ArgoCD at the app repo `tzin1401/yas`.

The sampledata seed applications intentionally do not enable automated sync.
They are one-shot operational jobs and should be synced only by the
`seed_sampledata` Jenkins job or an operator during the initial demo setup.
