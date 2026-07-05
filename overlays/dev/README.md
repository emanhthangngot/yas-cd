# Dev Overlay

The `dev` environment tracks successful `main` builds. Jenkins pushes commit
SHA plus `main/latest` tags, but GitOps deploys the commit SHA tag so each
successful build rolls new pods.

Do not place secrets in this folder.

Intent:

- Namespace: `dev`
- Default bootstrap image tag: `main`
- Jenkins `deploy_dev` patches tags to a commit SHA after a successful `main` build.
- Mutable `latest` is acceptable only for lab convenience in dev, not staging.
