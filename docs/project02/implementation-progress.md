# Lab 2 CD Implementation Progress

Last updated: 2026-07-05

CD repo: `git@github.com:emanhthangngot/yas-cd.git`
App repo: `git@github.com:tzin1401/yas.git`

This file records the current repo and runtime progress. For a short handoff
before starting a new chat, read `docs/project02/current-handoff.md` first.

## Current Status Summary

| Area | Status | Notes |
|---|---|---|
| Split GitOps repo | Done | CD repo owns `base/`, `overlays/`, `argocd/`, `charts/`, docs, specs, and agent context. |
| CQ service scope | Done in CD repo | Merged through CD PR #11; normal runtime excludes non-required heavy services. |
| Runtime policy | Done in CD repo | Merged through CD PR #12; `dev` and `staging` active, `developer` dormant. |
| Staging resource control | Done in CD repo | PR #13 sets staging CPU throttle; PR #14 sets `maxSurge: 0` rollouts. |
| ArgoCD apps | Implemented and previously observed | `yas-dev`, `yas-staging`, `yas-developer` point at `yas-cd/main`. Re-check after PR #14. |
| App repo Jenkinsfile | Aligned in working tree | Main Jenkinsfile handles `dev`/`staging`; developer preview is separated into `Jenkinsfile.developer-build`. |
| Staging release tag flow | Implemented in Jenkinsfile/CD scripts | Release tags promote existing commit-SHA images with `docker buildx imagetools create`; needs Jenkins tag-discovery verification. |
| Storefront login/register config | Runtime verified and hardened in CD | `storefront-bff` uses OAuth registration id `keycloak`; authorization, login page, and registration page render through same-host Keycloak URLs on NodePort `30846` for `dev` and `staging`. The BFF OAuth patch sets `SERVER_FORWARD_HEADERS_STRATEGY=framework`, and BFF extra config pins distinct WebFlux session cookies for storefront/backoffice callback state. |
| API gateway routing | Fixed in CD desired state | BFF route table now maps `/api/<service>/**` directly for product, location, inventory, cart, customer, media, rating, payment, payment-paypal, tax, promotion, search, order, recommendation, webhook, and sampledata; generic `/api/**` self-route was removed. |
| Gateway route generation | Implemented in CD repo | `scripts/sync-gateway-routes.sh` now derives backend gateway routes from `services.yaml`; `scripts/validate-gitops.sh` fails if rendered route YAML drifts from the service catalog. |
| Media image routing | Runtime verified | Product APIs now return same-origin `/api/media/...` thumbnail URLs, and the first seeded thumbnail returns `200 OK image/jpeg` in both `dev` and `staging`. |
| Storefront runtime smoke check | Implemented in CD repo | `scripts/smoke-runtime-storefront.sh` verifies Keycloak login redirect, Keycloak login page, registration page, product API routing, and same-origin `/api/media/**` assets for `dev` and `staging` after ArgoCD sync. |
| Platform infrastructure readiness | Done | PostgreSQL, Redis, Kafka, Elasticsearch, Keycloak, identity aliases, and PVC readiness are fully verified and documented in docs/project02/platform-infrastructure.md. |
| Service mesh | Done and reorganized | Required app pods in `dev` and `staging` namespaces show workload plus Istio sidecar as `READY 2/2`; STRICT mTLS, retry, and AuthorizationPolicy are verified and working. Overlay manifests are grouped under `overlays/<env>/istio/` by namespace, mTLS, DestinationRule, VirtualService, AuthorizationPolicy, Keycloak OAuth patch, and sidecar resources. |
| Final evidence pack | In progress | Use `.agents/evidence/README.md`. |

Current ArgoCD policy update:

- `yas-dev`: automated sync/self-heal.
- `yas-staging`: manual sync approval gate; Jenkins updates GitOps release tags, then an operator runs `argocd app sync yas-staging`.
- `yas-developer`: automated GitOps-managed namespace, dormant by default and active only during the explicit developer-preview mode.

## Recent CD Repo PRs

- PR #11: `cd(lab2): align cq demo service scope`
  - Kept teacher-required services and minimal runtime dependencies.
  - Added `swagger-ui`.
  - Kept `sampledata` dormant after seeding.
  - Removed `promotion`, `rating`, `recommendation`, and `webhook` from normal runtime pressure.
- PR #12: `cd(lab2): run dev staging in parallel`
  - `dev` active.
  - `staging` active.
  - `developer` dormant.
  - `scripts/activate-environment.sh baseline` now restores this policy.
- PR #13: `cd(lab2): throttle staging cpu usage`
  - Staging services render with lower CPU request/limit.
  - Observed staging service limits: `250m` CPU, memory limits unchanged.
- PR #14: `cd(lab2): cap staging rollout surge`
  - Staging rollouts render with `maxSurge: 0` and `maxUnavailable: 1`.
  - Purpose: avoid temporarily doubling Java pods on the single-node VM.

## Current Desired State

Runtime policy:

- `dev`: active.
- `staging`: active.
- `developer`: dormant.
- `sampledata`: dormant after seed data is available.

Image tag policy:

- `dev`: successful `main` builds deploy immutable commit SHA tags through GitOps; Docker Hub still receives `main` and `latest` convenience tags.
- `staging`: immutable release tags only, such as `v1.2.3`.
- `developer`: dormant by default; feature branches in the main app Jenkinsfile build/push images only and skip GitOps updates. `Jenkinsfile.developer-build` handles the course-required preview path.

## App Repo Jenkins State

Checked after returning local app repo to `main`:

- Only one Jenkinsfile exists.
- No separate dev/staging/developer Jenkinsfiles exist.
- Main Jenkinsfile selects behavior using `TAG_NAME` and `BRANCH_NAME`; developer preview is separated into `Jenkinsfile.developer-build`.
- Feature branch image tag: short commit id.
- `main` image tags: short commit id, `main`, and `latest`; GitOps deploys the short commit id to `dev`.
- Release tag image tags: existing short commit id promoted to `vX.Y.Z`; release jobs fail instead of rebuilding if the commit image is missing.
- GitOps target:
  - `TAG_NAME=vX.Y.Z` -> `staging`
  - `BRANCH_NAME=main` -> `dev` with short commit id image tags
  - feature branch -> no GitOps update

Important follow-up:

- Create/configure the Jenkins job `developer_build` from `Jenkinsfile.developer-build`.
- Jenkins multibranch tag discovery for `vX.Y.Z` release jobs still needs verification.

## Last Runtime Observation

Last observed on 2026-07-04 after commit `c40848e`:

- `yas-platform`, `yas-dev`, and `yas-staging` were `Synced` at revision `c40848e7ccdbafa4f8cca6d219aac656da98b684`.
- ArgoCD health still reported `Progressing`, but every required app pod in `dev` and `staging` reported both app container and Istio sidecar as `true,true Running`.
- `storefront-bff` OAuth redirect in `dev` and `staging` points at `http://yas.<env>.local:30846/realms/Yas/...` and returns to `http://yas.<env>.local:30846/login/oauth2/code/keycloak`.
- `backoffice-bff` and `storefront-bff` set `SERVER_FORWARD_HEADERS_STRATEGY=framework` through the environment-specific Keycloak OAuth patch so Spring resolves forwarded ingress host/proto/port consistently.
- `storefront-bff` uses `YAS_STOREFRONT_SESSION` and `backoffice-bff` uses `YAS_BACKOFFICE_SESSION`; retest OAuth callback in an incognito window or after deleting old `SESSION` cookies.
- Storefront ingress routes `/authentication` and `/logout` to `storefront-bff`; without these routes, the UI receives the storefront HTML page instead of the BFF authentication JSON/logout handler.
- Keycloak `storefront-bff` and `backoffice-bff` clients were updated to allow `http://yas.dev.local:30846/*` and `http://yas.staging.local:30846/*`; the same redirect URIs are now present in the GitOps realm config for new bootstraps.
- Keycloak login page returned `status=200 title=Sign in to Yas`; registration page returned `status=200 marker=Register,Username,Email,` in both `dev` and `staging`.
- Product API returned same-origin thumbnail URLs (`/api/media/...`) and the first thumbnail returned `200 OK` with `Content-Type: image/jpeg` in both `dev` and `staging`.

Useful runtime refresh command:

```bash
ssh -i ~/.ssh/gcp_key_member -F /dev/null -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new xuantri@34.124.212.254 '
sudo k3s kubectl get applications -n argocd yas-dev yas-staging yas-developer -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision --no-headers
sudo k3s kubectl get deploy -n dev --no-headers | awk "{print \$1,\$2}" | sort
sudo k3s kubectl get deploy -n staging --no-headers | awk "{print \$1,\$2}" | sort
sudo k3s kubectl get deploy -n developer --no-headers | awk "{print \$1,\$2}" | sort
sudo k3s kubectl top nodes 2>/dev/null || true
sudo k3s kubectl top pods -A --sort-by=cpu 2>/dev/null | head -30 || true
'
```

## Required Local Checks Before Any Commit

```bash
git status --short
scripts/validate-gitops.sh
scripts/validate-staging-immutable.sh
git diff --check
```

For staging changes, also render and inspect rollout/resource policy:

```bash
kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone overlays/staging \
  | yq e 'select(.kind == "Deployment") | .metadata.name + " replicas=" + (.spec.replicas | tostring) + " maxSurge=" + (.spec.strategy.rollingUpdate.maxSurge | tostring) + " cpuLimit=" + (.spec.template.spec.containers[0].resources.limits.cpu | tostring)' - \
  | sort
```

## Remaining Work

1. Decide whether to merge the app repo PR/branch that disables developer preview GitOps.
2. Confirm Jenkins multibranch is configured to discover/build Git tags.
3. Trigger or simulate a `vX.Y.Z` release, confirm staging GitOps update, then manually sync `yas-staging`.
4. Re-check ArgoCD health display if the UI still reports `Progressing` despite all pods being `2/2`.
5. Capture platform infrastructure evidence for PostgreSQL, Redis, Kafka, Elasticsearch, Keycloak, identity aliases, and PVCs.
6. Run `GCP_VM_EXTERNAL_IP=<ip> APP_NODEPORT=30846 scripts/smoke-runtime-storefront.sh dev staging` from a network path that can reach the NodePort, or run the equivalent `curl --resolve ...:127.0.0.1` checks on the GCP VM.
7. Runtime-verify additional backoffice UI/API paths if a public backoffice ingress is added.
8. Keep gateway routes synchronized through `scripts/sync-gateway-routes.sh` whenever backend services are added or removed from `services.yaml`.
9. Capture final evidence for Docker Hub tags, ArgoCD UI screenshots, external access, and mesh.
