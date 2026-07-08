#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

require_tool yq
require_tool kustomize

scripts/sync-gateway-routes.sh --check

service_count="$(yq e '.services | length' services.yaml)"
if [ "$service_count" -le 0 ]; then
  echo "services.yaml does not contain services" >&2
  exit 1
fi

active_environments=""
expected_active_environments="${YAS_CD_EXPECTED_ACTIVE:-dev staging}"
deployable_images="$(mktemp)"
expected_gateway_services="$(mktemp)"
trap 'rm -f "$deployable_images" "$expected_gateway_services"' EXIT

yq -r '.services[] | select(.deploy == true) | .imageName' services.yaml | sort >"$deployable_images"
yq -r '.services[] | select(.type == "backend" and .chart != null) | .name' services.yaml | sort >"$expected_gateway_services"

for overlay in dev staging developer; do
  echo "validating overlay: $overlay"

  overlay_images="$(mktemp)"
  rendered_overlay="$(mktemp)"
  rendered_gateway_routes="$(mktemp)"
  yq -r '.images[].name | split("/")[-1]' "overlays/${overlay}/kustomization.yaml" | sort >"$overlay_images"

  if ! diff -u "$deployable_images" "$overlay_images"; then
    echo "overlay ${overlay} image list does not match deployable services.yaml images" >&2
    rm -f "$overlay_images" "$rendered_overlay" "$rendered_gateway_routes"
    exit 1
  fi
  rm -f "$overlay_images"

  kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone "overlays/${overlay}" >"$rendered_overlay"

  yq -r 'select(.kind == "ConfigMap" and .metadata.name == "yas-gateway-routes-config-configmap")
    | .data."gateway-routes-config.yaml"' "$rendered_overlay" >"$rendered_gateway_routes"

  while IFS= read -r service; do
    if ! yq -e ".spring.cloud.gateway.server.webflux.routes[]
      | select(.id == \"${service//-/_}_api\")
      | select(.uri == \"http://${service}\")
      | select(.predicates[] == \"Path=/api/${service}/**\")" "$rendered_gateway_routes" >/dev/null; then
      echo "overlay ${overlay} missing gateway route for service: ${service}" >&2
      rm -f "$rendered_overlay" "$rendered_gateway_routes"
      exit 1
    fi
  done <"$expected_gateway_services"

  if yq -e '.spring.cloud.gateway.server.webflux.routes[] | select(.id == "api" and .uri == "http://storefront-bff")' \
    "$rendered_gateway_routes" >/dev/null 2>/dev/null; then
    echo "overlay ${overlay} must not route generic /api/** back to storefront-bff" >&2
    rm -f "$rendered_overlay" "$rendered_gateway_routes"
    exit 1
  fi

  rm -f "$rendered_overlay" "$rendered_gateway_routes"

  replica_patch_count="$(yq -r '[.patches[]? | select(.target.kind == "Deployment" and (.path == "replicas-active.yaml" or .path == "replicas-dormant.yaml"))] | length' "overlays/${overlay}/kustomization.yaml")"
  if [ "$replica_patch_count" != "1" ]; then
    echo "overlay ${overlay} must contain exactly one deployment replica state patch, found: ${replica_patch_count}" >&2
    exit 1
  fi

  replica_patch="$(yq -r '.patches[]? | select(.target.kind == "Deployment" and (.path == "replicas-active.yaml" or .path == "replicas-dormant.yaml")) | .path' "overlays/${overlay}/kustomization.yaml")"
  if [ "$replica_patch" = "replicas-active.yaml" ]; then
    active_environments="${active_environments} ${overlay}"
  fi
done

active_environments="$(echo "$active_environments" | xargs)"
if [ "$active_environments" != "$expected_active_environments" ]; then
  echo "active environment policy mismatch; expected: ${expected_active_environments}, actual: ${active_environments:-none}" >&2
  exit 1
fi

for seed_overlay in operations/sampledata-seed/dev operations/sampledata-seed/staging \
  operations/debezium-connector-register/dev operations/debezium-connector-register/staging; do
  echo "validating operation overlay: ${seed_overlay}"
  kustomize build --load-restrictor=LoadRestrictionsNone "$seed_overlay" >/dev/null
done

scripts/validate-staging-immutable.sh

if grep -RInE --exclude-dir=.git --exclude=validate-gitops.sh 'git@github\.com:tzin1401/yas-cd\.git|tzin1401/yas-cd|targetRevision: lab2/cd-platform|path: deploy/gitops' \
  AGENTS.md README.md argocd docs specs .agents .specify >/tmp/yas-cd-old-source-scan.txt; then
  cat /tmp/yas-cd-old-source-scan.txt >&2
  echo "old GitOps source references remain" >&2
  exit 1
fi

if grep -RInE --exclude-dir=.git --exclude=validate-gitops.sh 'kubeadm|control-plane taint|kubeadm init|/etc/kubernetes/admin.conf|kube-flannel' \
  AGENTS.md README.md argocd docs specs .agents .specify >/tmp/yas-cd-old-k8s-scan.txt; then
  cat /tmp/yas-cd-old-k8s-scan.txt >&2
  echo "old kubeadm setup references remain" >&2
  exit 1
fi

if grep -RInE --exclude-dir=.git --exclude=validate-gitops.sh 'tailscale up|tailscale status|MASTER_TAILSCALE|WORKER_TAILSCALE' \
  AGENTS.md README.md argocd docs specs .agents .specify >/tmp/yas-cd-tailscale-scan.txt; then
  cat /tmp/yas-cd-tailscale-scan.txt >&2
  echo "active Tailscale setup references remain" >&2
  exit 1
fi

if grep -RInE --exclude-dir=.git --exclude=validate-gitops.sh 'password: admin|LarUmB3A49NTg9YmgW4=|TVacLC|ZrU9I0q2|NKAr3|password: redis|apiKey: update-me|BEGIN OPENSSH|BEGIN RSA|BEGIN PRIVATE|AKIA' \
  . >/tmp/yas-cd-secret-scan.txt; then
  cat /tmp/yas-cd-secret-scan.txt >&2
  echo "blocked secret-like pattern found" >&2
  exit 1
fi

echo "GitOps validation passed"
