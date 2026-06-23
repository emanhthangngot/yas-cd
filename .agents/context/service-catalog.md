# Service Catalog Notes

`services.yaml` is authoritative for Lab 2 automation.

## Deployable Services

Deployable services have all of:

- `deploy: true`
- `dockerfile`
- `chart`
- `imageName`
- `dependencies`

## Excluded Services

- `common-library`: Maven dependency only.
- `delivery`: Maven module exists, but this fork does not include Dockerfile or Helm chart.

## Image Rule

Final CD images must use Docker Hub:

```text
docker.io/$DOCKERHUB_USERNAME/yas-<service>:<tag>
```

Do not use `ghcr.io/nashtech-garage/*` in final Lab 2 GitOps overlays.
