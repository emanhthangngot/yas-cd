# Dev Overlay

The `dev` environment tracks successful `main` builds. Images may use commit SHA plus `main/latest` tags for lab convenience.

Do not place secrets in this folder.

Intent:

- Namespace: `dev`
- Default image tag: `main`
- Jenkins `deploy_dev` may patch tags to a commit SHA after a successful `main` build.
- Mutable `latest` is acceptable only for lab convenience in dev, not staging.
