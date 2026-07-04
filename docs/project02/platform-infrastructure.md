# Platform Infrastructure Contract

This document defines the shared platform infrastructure contract required by the `dev` and `staging` application environments in the YAS project.

## 1. Required Namespaces and Components

The `yas-platform` ArgoCD application deploys the following shared services:

| Component | Kind | Namespace | Internal DNS Service Endpoint | PVC Required | Consumers / Dependent Services |
|---|---|---|---|---|---|
| **PostgreSQL** | `StatefulSet` | `postgres` | `postgresql.postgres.svc.cluster.local:5432` | Yes | `cart`, `customer`, `inventory`, `keycloak`, `location`, `media`, `order`, `payment`, `payment-paypal`, `product`, `tax` |
| **Redis** | `Deployment` | `redis` | `redis-master.redis.svc.cluster.local:6379` | No | `cart`, `backoffice-bff`, `storefront-bff` |
| **Kafka** | `StatefulSet` | `kafka` | `kafka-cluster-kafka-brokers.kafka.svc.cluster.local:9092` | Yes | `order`, `search` |
| **Elasticsearch** | `StatefulSet` | `elasticsearch` | `elasticsearch-es-http.elasticsearch.svc.cluster.local:9200` | Yes | `product`, `search` |
| **Keycloak** | `Deployment` | `keycloak` | `identity.keycloak.svc.cluster.local:80` | No | `customer`, `backoffice-bff`, `storefront-bff`, `backoffice-ui`, `storefront-ui` |

## 2. Required PostgreSQL Databases

The PostgreSQL instance must initialize and maintain databases for all required CQ services:
*   `cart`
*   `customer`
*   `inventory`
*   `keycloak`
*   `location`
*   `media`
*   `order`
*   `payment`
*   `payment-paypal`
*   `product`
*   `search`
*   `tax`
*   `sampledata`

## 3. Namespace-Specific Identity Aliases

To make Keycloak reachable via a uniform name across all application namespaces, `identity-aliases.yaml` defines `ExternalName` services:
*   `identity.dev.svc.cluster.local` -> `identity.keycloak.svc.cluster.local`
*   `identity.staging.svc.cluster.local` -> `identity.keycloak.svc.cluster.local`
*   `identity.developer.svc.cluster.local` -> `identity.keycloak.svc.cluster.local`

## 4. Ingress NodePorts

Fixed NodePorts are allocated on the Traefik service in `kube-system` to allow external entrypoints:
*   `30080` (HTTP)
*   `30081` (HTTPS)

## 5. Verification Commands

Run the following commands on the K3s cluster node to verify the platform health:
```bash
# Check application status
kubectl get application -n argocd yas-platform

# Check pod readiness across platform namespaces
kubectl get pods -n postgres
kubectl get pods -n redis
kubectl get pods -n kafka
kubectl get pods -n elasticsearch
kubectl get pods -n keycloak

# Check PVC binding status
kubectl get pvc -n postgres
kubectl get pvc -n kafka
kubectl get pvc -n elasticsearch

# Verify PostgreSQL database list
kubectl exec -n postgres statefulset/postgresql -- psql -U lab-postgres-user -d postgres -c '\l'
```
