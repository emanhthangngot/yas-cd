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
- Developer preview is disabled in the current runtime policy.
- `developer_build` must not change the GitOps desired state unless the policy is explicitly re-enabled.

The guard script exits non-zero with a policy message:

```bash
scripts/prepare-developer-preview.sh tax=9f2c4a1
```
