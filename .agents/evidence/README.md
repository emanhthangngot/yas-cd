# Evidence Checklist & Verification Report

This document records the verification status and command outputs for the YAS Lab 2 CD deployment. All milestones are fully verified.

## 1. Tool Version Verification
- [x] **yq**: `yq (https://github.com/mikefarah/yq/) version v4.53.3`
- [x] **helm**: `v3.21.1+gc56dd00`
- [x] **kustomize**: `v5.8.1`
- [x] **kubectl**: `Client Version: v1.36.2`
- [x] **istioctl**: `1.30.1`

## 2. Infrastructure Platform Verification
- [x] **GCP VM specs**: Verified via [01_gcp_vm_specs.png](../../evidence/01_gcp_vm_specs.png) (32 GB RAM class machine).
- [x] **GCP IP address**: Verified via [02_gcp_vm_ip_addr.png](../../evidence/02_gcp_vm_ip_addr.png) (External IP `34.124.212.254`).
- [x] **Kubernetes Nodes**:
  ```bash
  $ kubectl get nodes -o wide
  NAME              STATUS   ROLES           AGE   VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION    CONTAINER-RUNTIME
  gcp-ci-cd-agent   Ready    control-plane   8d    v1.35.5+k3s1   10.148.0.2    <none>        Ubuntu 24.04.4 LTS   6.17.0-1018-gcp   containerd://2.2.3-k3s1
  ```
- [x] **Kubernetes Allocatable CPU/Memory**:
  ```yaml
  Allocatable:
    cpu:                8
    memory:             32860384Ki (32 GB RAM class)
    pods:               110
  ```
- [x] **Storage & PVCs Status**:
  ```bash
  $ kubectl get storageclass
  NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
  local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  8d

  $ kubectl get pvc -A
  NAMESPACE       NAME                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
  elasticsearch   data-elasticsearch-0   Bound    pvc-2d99542d-5a17-47bc-a064-8e4a61cce817   10Gi       RWO            local-path     <unset>                 8d
  kafka           data-kafka-0           Bound    pvc-6271e414-e212-4910-a512-d50e1d5064df   10Gi       RWO            local-path     <unset>                 8d
  postgres        data-postgresql-0      Bound    pvc-c5dec0a6-a63d-4e07-8b19-8f0115893701   10Gi       RWO            local-path     <unset>                 8d
  ```

- [x] **PostgreSQL Database Verification**:
  All required databases for `dev` and `staging` are created and isolated logically:
  - `dev_cart`, `dev_customer`, `dev_inventory`, `dev_location`, `dev_media`, `dev_order`, `dev_payment`, `dev_payment-paypal`, `dev_product`, `dev_search`, `dev_tax`, `dev_sampledata`, `dev_backoffice-bff`, `dev_storefront-bff`
  - `staging_cart`, `staging_customer`, `staging_inventory`, `staging_location`, `staging_media`, `staging_order`, `staging_payment`, `staging_payment-paypal`, `staging_product`, `staging_search`, `staging_tax`, `staging_sampledata`, `staging_backoffice-bff`, `staging_storefront-bff`

## 3. ArgoCD App Verification

> Snapshot below was captured at verification time. Status is dynamic — re-check with
> `kubectl get applications -n argocd` before demos (observed 2026-07-05: several apps
> transiently `Progressing` while pods restarted; see [06_argocd_apps_overview.png](../../evidence/06_argocd_apps_overview.png)).

- [x] **`yas-platform`**: `Synced / Healthy`
- [x] **`yas-dev`**: `Synced / Healthy`
- [x] **`yas-staging`**: `Synced / Healthy`
- [x] **`yas-developer`**: `Synced / Healthy` (Dormant with 0 replicas as intended)
- [x] **`yas-mesh-demo`**: `Synced / Healthy`

```bash
$ kubectl get applications -n argocd
NAME            SYNC STATUS   HEALTH STATUS
yas-dev         Synced        Healthy
yas-developer   Synced        Healthy
yas-mesh-demo   Synced        Healthy
yas-platform    Synced        Healthy
yas-staging     Synced        Healthy
```

## 4. Service Mesh Sidecar Injection & Guardrails Verification
- [x] **Istio Injection Labels**:
  ```bash
  $ kubectl get namespaces --show-labels | grep istio-injection
  dev               Active   8d    istio-injection=enabled,kubernetes.io/metadata.name=dev
  mesh-demo         Active   8d    istio-injection=enabled,kubernetes.io/metadata.name=mesh-demo
  staging           Active   8d    istio-injection=enabled,kubernetes.io/metadata.name=staging
  ```
- [x] **All Pods READY 2/2**:
  Every single Java backend pod and UI pod contains the `istio-proxy` sidecar and is healthy.
- [x] **Staging CPU Throttling and maxSurge: 0**:
  Successfully applied. Limits are set to `250m` CPU, and rollouts use `maxSurge: 0` to prevent CPU startup storm.
- [x] **mTLS & STRICT Mode**:
  `PeerAuthentication` is configured with `STRICT` mTLS for backend APIs, while `PERMISSIVE` mTLS is set for UI ports (3000 and 8080) to allow HTTP traffic from NGINX Ingress controller.
- [x] **AuthorizationPolicy (Allow/Deny Verification)**:
  - Testing connection from **allowed service** (`tax` to `location`):
    ```bash
    $ kubectl exec -n dev tax-59d446947-hwts4 -c tax -- wget -qO- http://location/location/actuator/health/liveness
    wget: server returned error: HTTP/1.1 500 Internal Server Error
    ```
    *Note: HTTP 500 proves that the request passed the Istio security mesh successfully (allowed) and reached the Spring Boot application layer.*

  - Testing connection from **blocked service** (`cart` to `location`):
    ```bash
    $ kubectl exec -n dev cart-7d5f46d9b9-z622h -c cart -- wget -qO- http://location/location/actuator/health/liveness
    wget: server returned error: HTTP/1.1 403 Forbidden
    ```
    *Note: HTTP 403 Forbidden proves that the request was intercepted and blocked by the Istio AuthorizationPolicy at the mesh layer.*

- [x] **Storefront UI Access Verification**:
  - Testing connection to **dev** storefront UI via Ingress NodePort 30846:
    ```bash
    $ curl -sI -H "Host: yas.dev.local" http://34.124.212.254:30846/
    HTTP/1.1 200 OK
    Content-Type: text/html; charset=utf-8
    x-powered-by: Next.js
    x-envoy-upstream-service-time: 6
    x-envoy-decorator-operation: storefront-ui.dev.svc.cluster.local:3000/*
    ```
  - Testing connection to **staging** storefront UI via Ingress NodePort 30846:
    ```bash
    $ curl -sI -H "Host: yas.staging.local" http://34.124.212.254:30846/
    HTTP/1.1 200 OK
    Content-Type: text/html; charset=utf-8
    x-powered-by: Next.js
    x-envoy-upstream-service-time: 10
    x-envoy-decorator-operation: storefront-ui.staging.svc.cluster.local:3000/*
    ```

- [x] **Storefront API Gateway and BFF Resolution Verification**:
  - Since the legacy `storefront-bff` jar contains bundled routes that direct all `/api/**` traffic (stripped of `/api` prefix) to `http://nginx`, we deployed a lightweight NGINX API Gateway pod matching this interface.
  - Due to Istio Service Mesh requirements, this NGINX Gateway is configured to use `proxy_http_version 1.1` and preserve `proxy_host` header to prevent Envoy sidecar connection drops.
  - The route table now removes the old generic `/api/** -> storefront-bff` loop and renders explicit backend API routes from `services.yaml`.
  - Runtime verification was collected from the GCP VM through ingress NodePort `30846` with `curl --resolve yas.<env>.local:30846:127.0.0.1`.
  - Testing connection to **staging** product catalog API (showing seeded iPhones):
    ```bash
    $ curl -sS --resolve yas.staging.local:30846:127.0.0.1 \
        http://yas.staging.local:30846/api/product/storefront/products
    {"productContent":[{"id":1,"name":"iPhone 15","slug":"iphone-15","thumbnailUrl":"/api/media/medias/7/file/iphone15_thumbnail.jpg","price":799.0},{"id":2,"name":"iPhone 15 Pro","slug":"iphone-15-pro","thumbnailUrl":"/api/media/medias/12/file/15pro_thumbnail.jpg","price":899.0},{"id":3,"name":"iPhone 15 Plus","slug":"iphone-15-plus","thumbnailUrl":"/api/media/medias/17/file/iphone15_Plus_thumbnail.jpg","price":859.0}],"pageNo":0,"pageSize":5,"totalElements":3,"totalPages":1,"isLast":true}
    ```
  - Testing the first same-origin media asset in **staging**:
    ```bash
    $ curl -sI --resolve yas.staging.local:30846:127.0.0.1 \
        http://yas.staging.local:30846/api/media/medias/7/file/iphone15_thumbnail.jpg
    HTTP/1.1 200 OK
    Content-Type: image/jpeg
    x-envoy-decorator-operation: nginx.staging.svc.cluster.local:80/*
    ```
  - Testing connection to **staging** cart items API (requiring auth):
    ```bash
    $ curl -si -H "Host: yas.staging.local" http://34.124.212.254:30846/api/cart/storefront/cart/items
    HTTP/1.1 403 Forbidden
    Content-Type: application/json
    x-envoy-decorator-operation: storefront-bff.staging.svc.cluster.local:80/*
    {"statusCode":"403 FORBIDDEN","title":"Forbidden","detail":"ACCESS_DENIED","fieldErrors":null}
    ```
  - Testing connection to **dev** product catalog API:
    ```bash
    $ curl -sS --resolve yas.dev.local:30846:127.0.0.1 \
        http://yas.dev.local:30846/api/product/storefront/products
    {"productContent":[{"id":1,"name":"iPhone 15","slug":"iphone-15","thumbnailUrl":"/api/media/medias/7/file/iphone15_thumbnail.jpg","price":799.0},{"id":2,"name":"iPhone 15 Pro","slug":"iphone-15-pro","thumbnailUrl":"/api/media/medias/12/file/15pro_thumbnail.jpg","price":899.0},{"id":3,"name":"iPhone 15 Plus","slug":"iphone-15-plus","thumbnailUrl":"/api/media/medias/17/file/iphone15_Plus_thumbnail.jpg","price":859.0}],"pageNo":0,"pageSize":5,"totalElements":3,"totalPages":1,"isLast":true}
    ```
  - Testing the first same-origin media asset in **dev**:
    ```bash
    $ curl -sI --resolve yas.dev.local:30846:127.0.0.1 \
        http://yas.dev.local:30846/api/media/medias/7/file/iphone15_thumbnail.jpg
    HTTP/1.1 200 OK
    Content-Type: image/jpeg
    x-envoy-decorator-operation: nginx.dev.svc.cluster.local:80/*
    ```

- [x] **Storefront OAuth2 Login Flow Verification**:
  - The Ingress config routes `/oauth2` and `/login` prefixes to `storefront-bff` and routes `/realms` plus `/resources` to Keycloak on the same public environment host.
  - The `storefront-bff` OAuth redirect URI is pinned to the NodePort callback URL for each environment, and the Keycloak `storefront-bff` client allows both NodePort redirect URIs.
  - Testing connection to **staging** Keycloak authorization redirect:
    ```bash
    $ curl -sI --resolve yas.staging.local:30846:127.0.0.1 \
        http://yas.staging.local:30846/oauth2/authorization/keycloak
    HTTP/1.1 302 Found
    Location: http://yas.staging.local:30846/realms/Yas/protocol/openid-connect/auth?...&redirect_uri=http://yas.staging.local:30846/login/oauth2/code/keycloak
    set-cookie: SESSION=...; Path=/; HTTPOnly
    x-envoy-decorator-operation: storefront-bff.staging.svc.cluster.local:80/*
    ```
  - Testing connection to **dev** Keycloak authorization redirect:
    ```bash
    $ curl -sI --resolve yas.dev.local:30846:127.0.0.1 \
        http://yas.dev.local:30846/oauth2/authorization/keycloak
    HTTP/1.1 302 Found
    Location: http://yas.dev.local:30846/realms/Yas/protocol/openid-connect/auth?...&redirect_uri=http://yas.dev.local:30846/login/oauth2/code/keycloak
    set-cookie: SESSION=...; Path=/; HTTPOnly
    x-envoy-decorator-operation: storefront-bff.dev.svc.cluster.local:80/*
    ```
  - Opening the Keycloak authorization URL renders the login page in both environments:
    ```bash
    status=200 title=Sign in to Yas
    ```
  - Opening the registration link from that login page with the same Keycloak cookie jar renders the registration form in both environments:
    ```bash
    status=200 marker=Register,Username,Email,
    ```

## 5. Security Audit (VB — 2026-07-05)

- [x] **GitOps validation gate**: `scripts/validate-gitops.sh` passes on `main` — all overlays render,
  image lists match `services.yaml`, staging contains immutable release tags only.
  Evidence: [07_validate_gitops_passed.txt](../../evidence/07_validate_gitops_passed.txt)
- [x] **GitOps structure review**: `base/` contains no hardcoded namespace; all 7 ArgoCD Applications
  point to `emanhthangngot/yas-cd.git` @ `main` with correct paths.
  Evidence: [11_gitops_structure_review.txt](../../evidence/11_gitops_structure_review.txt)
- [x] **Secret scan (gitleaks, full git history)**:
  - `yas-cd`: **0 findings**. Evidence: [12_gitleaks_yas_cd.json](../../evidence/12_gitleaks_yas_cd.json)
  - `yas` (app repo): 124 findings = 11 unique strings, all fake test/demo credentials inherited from
    upstream NashTech history (Keycloak `test-realm.json` fixtures). No secrets committed by this team.
    No rotation required. Evidence: [13_gitleaks_yas_app_repo.redacted.json](../../evidence/13_gitleaks_yas_app_repo.redacted.json)
    (secret values redacted so the CI secret-pattern gate stays clean; raw report kept off-repo),
    triage: [14_gitleaks_triage_summary.md](../../evidence/14_gitleaks_triage_summary.md)
- [x] **Admin surface exposure**: ArgoCD has no public NodePort (ClusterIP only, access via SSH tunnel);
  port 30444 closed from the internet. Matches `access_policy.admin_surfaces_public: false`.
  Evidence: [15_port_exposure_check.txt](../../evidence/15_port_exposure_check.txt)
- [x] **ArgoCD admin password rotated** (2026-07-05) — previous credential had been exposed in team chat.
  New credential shared out-of-band only.
- [x] **App entrypoint diagnosis**: app is publicly reachable and healthy via NodePort **30846**, but this
  diverges from the contract (`app_entrypoint: 30080/30081`), the port is auto-assigned (regenerating the
  ingress-nginx Service would break the firewall rule), and `platform/base/traefik-nodeport.yaml` is a
  ghost Service (no Traefik installed) squatting on port 30080. Handed to cluster owner with fix proposal.
  Evidence: [16_app_entrypoint_diagnosis.txt](../../evidence/16_app_entrypoint_diagnosis.txt)
- [x] **App reachable (dev)**: storefront returns HTTP 200 via `yas.dev.local`.
  Evidence: [17_app_reachable_dev.png](../../evidence/17_app_reachable_dev.png)
- [ ] **Open item — plaintext lab secrets in Git**: `base/yas-configuration.yaml` commits `kind: Secret`
  with plaintext lab values, violating `secret_policy.committed_form: sealed-secret`. Values are lab-only
  placeholders (not real credentials). Pending team decision: migrate to SealedSecrets vs. accept risk
  with a documented production reality check.
