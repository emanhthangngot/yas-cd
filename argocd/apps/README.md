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
- `operations/debezium-connector-register/dev` (manual sync only)
- `operations/debezium-connector-register/staging` (manual sync only)

Do not point ArgoCD at the app repo `tzin1401/yas`.

The sampledata seed and debezium connector-register applications intentionally
do not enable automated sync. They are one-shot operational jobs: sampledata
seed should run only via the `seed_sampledata` Jenkins job or an operator
during initial demo setup; the debezium connector-register job registers the
`product` table's CDC connector against the shared Kafka Connect worker
(`platform/base/debezium-connect.yaml`) so `search` gets Postgres change
events for its Elasticsearch index — sync it once after `platform/base` is
up, and again only if the connector config or Kafka Connect worker changes.
