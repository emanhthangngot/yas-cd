# Developer Overlay

The `developer` environment is updated by the Jenkins `developer_build` job.

Required platform dependencies before app success:

- PostgreSQL
- Redis
- Keycloak
- Kafka + Zookeeper
- Elasticsearch
- `yas-configuration`
- Ingress or Gateway

Jenkins must update this overlay through GitOps and then sync ArgoCD. It must not mutate the namespace directly.

Intent:

- Namespace: `developer`
- Default image tag: `main`
- Jenkins `developer_build` patches only the selected branch services to branch commit SHA tags.
- Services not selected for a preview stay on the `main` tag.
- Default state is dormant through `replicas-dormant.yaml`.
- `developer_build` should call `scripts/prepare-developer-preview.sh <service=tag> [...]`.
- `teardown_developer` should call `scripts/teardown-developer.sh`.

Prepare a branch preview with `service=tag` assignments:

```bash
scripts/prepare-developer-preview.sh tax=9f2c4a1 payment=6d7e8f9
```

Tear down the preview and restore `dev` as the active environment:

```bash
scripts/teardown-developer.sh
```
