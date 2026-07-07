# Multi-Host Ingress (`<app>.<env>.yas.local.com`)

Per-app hostnames on the single GCP VM IP + ingress-nginx NodePort 30846,
routed by Host header. The legacy hosts (`yas.dev.local`, `yas.staging.local`,
`yas.developer.local`) keep working in parallel; smoke scripts are unchanged.

## Hosts

| Host | Backend |
|---|---|
| `storefront.<env>.yas.local.com` | `/` storefront-ui, `/api` `/oauth2` `/login` `/authentication` `/logout` storefront-bff, `/api/media` nginx rewrite, `/realms` `/resources` identity |
| `backoffice.<env>.yas.local.com` | `/` backoffice-ui, `/api` + auth paths backoffice-bff, `/api/media` nginx rewrite, `/realms` `/resources` identity |
| `swagger.<env>.yas.local.com` | `/swagger-ui` swagger-ui, `/api` storefront-bff (fetches `/api/<svc>/v3/api-docs`) |
| `identity.<env>.yas.local.com` | `/realms` `/resources` `/admin` identity (Keycloak) |

`<env>` = `dev`, `staging`, `developer`.

## Client hosts file

No DNS exists for these names. Each viewer adds one line
(`/etc/hosts`, Windows: `C:\Windows\System32\drivers\etc\hosts`):

```
34.124.212.254 storefront.dev.yas.local.com backoffice.dev.yas.local.com swagger.dev.yas.local.com identity.dev.yas.local.com storefront.staging.yas.local.com backoffice.staging.yas.local.com swagger.staging.yas.local.com identity.staging.yas.local.com
```

Access example: `http://storefront.staging.yas.local.com:30846/`.
The `:30846` port is required — dropping it needs the GCP firewall to open 80
and ingress-nginx to listen on hostPort 80 (not done).

## How Keycloak stays same-origin

Login never leaves the app host: the BFF redirects the browser to
`/realms/Yas/...` on the current host, a per-host Ingress with
`nginx.ingress.kubernetes.io/upstream-vhost: <host>:30846` proxies it to
Keycloak, and Keycloak (started with `--hostname-strict=false`) generates its
form/redirect URLs from that pinned Host header. Backchannel calls from the
BFF keep using `http://identity` (ExternalName -> `identity.keycloak.svc`), so
the token issuer stays `http://identity/realms/Yas` and matches the resource
server config. One Ingress per host is required because `upstream-vhost` is a
per-Ingress annotation.

## Keycloak redirect URIs — live update required once

`platform/base/keycloak-realm.configmap.yaml` (source of truth) now includes
the new `http://storefront.<env>.yas.local.com:30846/*` /
`http://backoffice.<env>.yas.local.com:30846/*` redirect URIs, but Keycloak
`--import-realm` only imports a realm that does not exist yet — changing the
ConfigMap does NOT update the live realm. Apply once on the running Keycloak:

- Admin console (host `identity.dev.yas.local.com:30846/admin` or SSH tunnel)
  → realm `Yas` → Clients → `storefront-bff` → Valid redirect URIs → add the
  three `storefront.*` entries above → Save. Repeat for `backoffice-bff` with
  the `backoffice.*` entries.
- Or with kcadm inside the keycloak pod (uses the admin credentials from the
  `keycloak-credentials` secret; ids differ per install so look them up):

```bash
kubectl exec -n keycloak deploy/keycloak -- /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:80 --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD"
kubectl exec -n keycloak deploy/keycloak -- /opt/keycloak/bin/kcadm.sh get clients -r Yas -q clientId=storefront-bff --fields id,redirectUris
kubectl exec -n keycloak deploy/keycloak -- /opt/keycloak/bin/kcadm.sh update clients/<id> -r Yas \
  -s 'redirectUris=[...existing plus new entries...]'
```

Without this step, login on the new hosts fails with Keycloak
`invalid_redirect_uri`; everything anonymous still works.

## Rollout checklist

1. Merge to `main`; ArgoCD auto-syncs `yas-dev` (staging qua manual gate).
2. `kubectl get ingress -n dev` shows the new `yas-hosts-*` / `yas-keycloak-*-host` objects.
3. Anonymous: `curl -H "Host: storefront.dev.yas.local.com" http://<VM_IP>:30846/api/product/storefront/products/featured?pageNo=0` → 200.
4. Update Keycloak redirect URIs (section above), then browser-test login on
   `storefront.dev.yas.local.com` and `backoffice.dev.yas.local.com`.
5. Sync `yas-staging`, repeat 2–4 for staging hosts.

## Known limitation

Product images rendered through `next/image` are broken independently of the
hostnames (optimizer cannot fetch `/api/media/...` server-side, and the media
PVC currently holds 1x1 placeholder files seeded by the
`seed-media-placeholders` initContainer). Tracked separately; the fix plan is
hostAliases `api.yas.local` -> media plus real sample images on the PVC.
