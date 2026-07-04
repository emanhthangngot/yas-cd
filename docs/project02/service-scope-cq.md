# CQ Demo Service Scope

Source requirement: `docs/deployment-services-cq (1).pdf`.

The teacher-required demo keeps the e-commerce and service-mesh path small while
still showing the storefront, backoffice, API documentation, sample data, and
core order flow.

## Teacher-Required Services

- `product`
- `cart`
- `order`
- `customer`
- `inventory`
- `tax`
- `media`
- `search`
- `storefront-bff`
- `storefront-ui`
- `backoffice-bff`
- `backoffice-ui`
- `swagger-ui`
- `sampledata` as run-once seed data

## Runtime Dependencies Kept

These services stay enabled even though they are not listed as standalone demo
services in the PDF:

- `location`: required by `tax`
- `payment`: required by `order`
- `payment-paypal`: required by `payment`

Without these dependencies the required `tax` and `order` flows are likely to
fail or produce misleading evidence.

## Disabled Optional Services

These services are not part of the CQ demo scope and are disabled from the
default GitOps render:

- `promotion`
- `rating`
- `recommendation`
- `webhook`

They remain in `charts/` and can be reintroduced for a full YAS profile later.

## Sample Data Policy

`sampledata` remains in the rendered manifests for explicit seed operations, but
all environment overlays force its replicas to `0` by default. This matches the
PDF note that sample data should run once and can then be turned off.

## Active Demo Runtime

With the CQ scope active, the default `dev` environment renders:

- 15 Docker Hub-managed YAS services
- 1 third-party `swagger-ui` service
- `sampledata` deployment at `0` replicas

This keeps the single-node K3s runtime smaller than the previous 20-service
full-YAS profile while preserving the required demo paths.
