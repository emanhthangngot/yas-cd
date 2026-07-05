# Dev Istio Overlay

This folder groups the dev service-mesh and auth-routing patches by function.

- `namespace.yaml`: enables Istio sidecar injection for the `dev` namespace.
- `mtls.yaml`: defines namespace-wide STRICT mTLS plus PERMISSIVE exceptions for edge/UI/BFF workloads.
- `destination-rules.yaml`: enables Istio mutual TLS for in-namespace service traffic.
- `virtual-services.yaml`: keeps retry policy for services that need mesh-level retries.
- `authorization-policies.yaml`: restricts backend callers by service account.
- `keycloak-oauth-patch.yaml`: configures BFF OAuth endpoints and redirect URIs for Keycloak through the dev NodePort host.
- `sidecar-resources-patch.yaml`: sets Istio sidecar CPU/memory requests and limits.
