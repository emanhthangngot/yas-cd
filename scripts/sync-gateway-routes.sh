#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [--check]" >&2
}

CHECK=false
if [ "$#" -gt 1 ]; then
  usage
  exit 2
fi

if [ "$#" -eq 1 ]; then
  case "$1" in
    --check) CHECK=true ;;
    *)
      usage
      exit 2
      ;;
  esac
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v yq >/dev/null 2>&1; then
  echo "missing required tool: yq" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

base_file="base/yas-configuration.yaml"
chart_values_file="charts/yas-configuration/values.yaml"

base_target="$base_file"
chart_target="$chart_values_file"

if [ "$CHECK" = true ]; then
  base_target="$tmpdir/yas-configuration.yaml"
  chart_target="$tmpdir/values.yaml"
  cp -a "$base_file" "$base_target"
  cp -a "$chart_values_file" "$chart_target"
fi

services_file="$tmpdir/gateway-services.txt"
base_gateway_config="$tmpdir/gateway-routes-config.yaml"
chart_routes="$tmpdir/gateway-routes.yaml"

yq -r '.services[] | select(.type == "backend" and .chart != null) | .name' services.yaml >"$services_file"

{
  echo "spring:"
  echo "  cloud:"
  echo "    gateway:"
  # Spring Cloud Gateway in the shipped BFF images binds routes from
  # spring.cloud.gateway.server.webflux.routes; the legacy
  # spring.cloud.gateway.routes key is silently ignored.
  echo "      server:"
  echo "        webflux:"
  echo "          routes:"
  while IFS= read -r service; do
    route_id="${service//-/_}_api"
    echo "            - id: ${route_id}"
    echo "              uri: http://${service}"
    echo "              order: -10"
    echo "              predicates:"
    echo "                - Path=/api/${service}/**"
    echo "              filters:"
    echo '                - RewritePath=/api/(?<segment>.*), /${segment}'
    echo "                - TokenRelay="
  done <"$services_file"
  echo "            - id: ui"
  echo '              uri: ${UI_HOST}'
  echo "              order: -10"
  echo "              predicates:"
  echo "                - Path=/**"
} >"$base_gateway_config"

{
  while IFS= read -r service; do
    route_id="${service//-/_}_api"
    echo "- id: ${route_id}"
    echo "  uri: http://${service}"
    echo "  order: -10"
    echo "  predicates:"
    echo "    - Path=/api/${service}/**"
    echo "  filters:"
    echo '    - RewritePath=/api/(?<segment>.*), /$\{segment}'
    echo "    - TokenRelay="
  done <"$services_file"
  echo "- id: ui"
  echo '  uri: ${UI_HOST}'
  echo "  order: -10"
  echo "  predicates:"
  echo "    - Path=/**"
} >"$chart_routes"

GATEWAY_CONFIG="$base_gateway_config" yq -i \
  '(select(.kind == "ConfigMap" and .metadata.name == "yas-gateway-routes-config-configmap") | .data."gateway-routes-config.yaml") = load_str(strenv(GATEWAY_CONFIG))' \
  "$base_target"

CHART_ROUTES="$chart_routes" yq -i \
  'del(.gatewayRoutesConfig.spring.cloud.gateway.routes) |
   .gatewayRoutesConfig.spring.cloud.gateway.server.webflux.routes = load(strenv(CHART_ROUTES))' \
  "$chart_target"

if [ "$CHECK" = true ]; then
  failed=false
  if ! diff -u "$base_file" "$base_target"; then
    echo "base gateway routes are not synchronized with services.yaml; run scripts/sync-gateway-routes.sh" >&2
    failed=true
  fi
  if ! diff -u "$chart_values_file" "$chart_target"; then
    echo "chart gateway routes are not synchronized with services.yaml; run scripts/sync-gateway-routes.sh" >&2
    failed=true
  fi
  if [ "$failed" = true ]; then
    exit 1
  fi
else
  echo "synchronized gateway routes from services.yaml"
fi
