# ArgoCD Applications

Apply these after ArgoCD is installed on the GCP VM cluster:

```bash
kubectl apply -f argocd/apps/
```

The applications track `git@github.com:emanhthangngot/yas-cd.git`, branch `main`, and sync these paths:

- `overlays/dev`
- `overlays/staging`
- `overlays/developer`

Do not point ArgoCD at the app repo `tzin1401/yas`.
