# GitOps Base

The base renders deployable YAS services from the chart snapshot under `charts/`.

- It intentionally does not set a namespace.
- Environment overlays own namespace and image tags.
- Jenkins should patch overlay image entries to real Docker Hub images in the form `docker.io/$DOCKERHUB_USERNAME/yas-<service>:<tag>`.

Render examples:

```bash
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/dev
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/developer
```
