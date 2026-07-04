#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: GCP_VM_EXTERNAL_IP=<ip> scripts/smoke-runtime-storefront.sh [dev|staging ...]

Optional environment variables:
  APP_NODEPORT    NodePort for the application ingress, default: 30080
  CURL_TIMEOUT    curl max-time in seconds, default: 20

The script is read-only. It verifies the storefront login redirect, product API,
and same-origin media URLs after ArgoCD has synced the CD repo manifests.
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ -z "${GCP_VM_EXTERNAL_IP:-}" ]; then
  echo "GCP_VM_EXTERNAL_IP is required" >&2
  usage
  exit 2
fi

APP_NODEPORT="${APP_NODEPORT:-30080}"
CURL_TIMEOUT="${CURL_TIMEOUT:-20}"

if ! command -v curl >/dev/null 2>&1; then
  echo "missing required tool: curl" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

environments=("$@")
if [ "${#environments[@]}" -eq 0 ]; then
  environments=(dev staging)
fi

request() {
  local env_name="$1"
  local path="$2"
  local output_file="$3"
  curl -sS \
    --max-time "$CURL_TIMEOUT" \
    --resolve "yas.${env_name}.local:${APP_NODEPORT}:${GCP_VM_EXTERNAL_IP}" \
    -o "$output_file" \
    -w "%{http_code}" \
    "http://yas.${env_name}.local:${APP_NODEPORT}${path}"
}

request_headers() {
  local env_name="$1"
  local path="$2"
  local output_file="$3"
  curl -sS \
    --max-time "$CURL_TIMEOUT" \
    --resolve "yas.${env_name}.local:${APP_NODEPORT}:${GCP_VM_EXTERNAL_IP}" \
    -D "$output_file" \
    -o /dev/null \
    -w "%{http_code}" \
    "http://yas.${env_name}.local:${APP_NODEPORT}${path}"
}

expect_status() {
  local status="$1"
  local pattern="$2"
  local label="$3"
  if [[ ! "$status" =~ $pattern ]]; then
    echo "${label}: unexpected HTTP status ${status}" >&2
    return 1
  fi
}

for env_name in "${environments[@]}"; do
  case "$env_name" in
    dev|staging) ;;
    *)
      echo "unsupported environment for this smoke check: ${env_name}" >&2
      exit 2
      ;;
  esac

  echo "smoke checking storefront ${env_name}"

  auth_headers="$tmpdir/${env_name}-auth.headers"
  auth_status="$(request_headers "$env_name" "/oauth2/authorization/keycloak" "$auth_headers")"
  expect_status "$auth_status" '^30[12378]$' "${env_name} keycloak authorization redirect"
  if ! grep -Eiq 'location: .*realms/Yas/protocol/openid-connect/auth' "$auth_headers"; then
    echo "${env_name} keycloak authorization redirect does not target the Yas realm" >&2
    exit 1
  fi
  if ! grep -Eiq 'location: .*client_id=storefront-bff' "$auth_headers"; then
    echo "${env_name} keycloak authorization redirect does not use storefront-bff client_id" >&2
    exit 1
  fi
  if ! grep -Eiq "location: .*redirect_uri=.*yas\\.${env_name}\\.local.*login.*keycloak" "$auth_headers"; then
    echo "${env_name} keycloak authorization redirect does not return to /login/oauth2/code/keycloak" >&2
    exit 1
  fi
  if [ "$APP_NODEPORT" != "80" ] && ! grep -Eiq "location: .*redirect_uri=.*yas\\.${env_name}\\.local:${APP_NODEPORT}/login/oauth2/code/keycloak" "$auth_headers"; then
    echo "${env_name} keycloak authorization redirect does not include NodePort ${APP_NODEPORT} in redirect_uri" >&2
    exit 1
  fi

  auth_location="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, "", $0); sub(/^location:[[:space:]]*/, "", $0); print; exit}' "$auth_headers")"
  keycloak_body="$tmpdir/${env_name}-keycloak-login.html"
  keycloak_cookies="$tmpdir/${env_name}-keycloak.cookies"
  keycloak_status="$(curl -sS \
    --max-time "$CURL_TIMEOUT" \
    --resolve "yas.${env_name}.local:${APP_NODEPORT}:${GCP_VM_EXTERNAL_IP}" \
    -c "$keycloak_cookies" \
    -o "$keycloak_body" \
    -w "%{http_code}" \
    "$auth_location")"
  expect_status "$keycloak_status" '^2[0-9][0-9]$' "${env_name} keycloak login page"
  if ! grep -q 'Sign in to Yas' "$keycloak_body"; then
    echo "${env_name} keycloak login page did not render the Yas realm login form" >&2
    exit 1
  fi

  registration_path="$(grep -Eo '/realms/Yas/login-actions/registration[^"[:space:]]+' "$keycloak_body" | head -n 1 | sed 's/&amp;/\&/g' || true)"
  if [ -z "$registration_path" ]; then
    echo "${env_name} keycloak login page did not expose a registration link" >&2
    exit 1
  fi
  registration_body="$tmpdir/${env_name}-keycloak-registration.html"
  registration_status="$(curl -sS \
    --max-time "$CURL_TIMEOUT" \
    --resolve "yas.${env_name}.local:${APP_NODEPORT}:${GCP_VM_EXTERNAL_IP}" \
    -b "$keycloak_cookies" \
    -c "$keycloak_cookies" \
    -o "$registration_body" \
    -w "%{http_code}" \
    "http://yas.${env_name}.local:${APP_NODEPORT}${registration_path}")"
  expect_status "$registration_status" '^2[0-9][0-9]$' "${env_name} keycloak registration page"
  if ! grep -q 'Register' "$registration_body" || ! grep -q 'Username' "$registration_body" || ! grep -q 'Email' "$registration_body"; then
    echo "${env_name} keycloak registration page did not render the expected registration form" >&2
    exit 1
  fi

  product_body="$tmpdir/${env_name}-products.json"
  product_status="$(request "$env_name" "/api/product/storefront/products" "$product_body")"
  expect_status "$product_status" '^2[0-9][0-9]$' "${env_name} product storefront API"
  if grep -q 'http://media/media' "$product_body"; then
    echo "${env_name} product API still returns the old internal media URL" >&2
    exit 1
  fi

  media_path="$(grep -Eo '/api/media[^"[:space:]]+' "$product_body" | head -n 1 || true)"
  if [ -z "$media_path" ]; then
    echo "${env_name} product API did not return a same-origin /api/media URL" >&2
    exit 1
  fi

  media_body="$tmpdir/${env_name}-media.body"
  media_status="$(request "$env_name" "$media_path" "$media_body")"
  expect_status "$media_status" '^2[0-9][0-9]$' "${env_name} media asset ${media_path}"
  if [ ! -s "$media_body" ]; then
    echo "${env_name} media asset response is empty: ${media_path}" >&2
    exit 1
  fi

  echo "${env_name} storefront smoke passed: login redirect, product API, media asset"
done
