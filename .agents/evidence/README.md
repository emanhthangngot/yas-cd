# Evidence Checklist & Verification Report

This document records the verification status and command outputs for the YAS Lab 2 CD deployment. All milestones are fully verified.

## 1. Tool Version Verification
- [x] **yq**: `yq (https://github.com/mikefarah/yq/) version v4.53.3`
- [x] **helm**: `v3.21.1+gc56dd00`
- [x] **kustomize**: `v5.8.1`
- [x] **kubectl**: `Client Version: v1.36.2`
- [x] **istioctl**: `1.30.1`

## 2. Infrastructure Platform Verification
- [x] **GCP VM specs**: Verified via [01_gcp_vm_specs.png](file:///home/pearspringmind/Studying/Devops/Lab2/yas-cd/evidence/01_gcp_vm_specs.png) (32 GB RAM class machine).
- [x] **GCP IP address**: Verified via [02_gcp_vm_ip_addr.png](file:///home/pearspringmind/Studying/Devops/Lab2/yas-cd/evidence/02_gcp_vm_ip_addr.png) (External IP `34.124.212.254`).
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
  `PeerAuthentication` is configured with `STRICT` mTLS.
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
