#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <dev|staging|developer> <active|dormant>" >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

ENVIRONMENT="$1"
STATE="$2"

case "$ENVIRONMENT" in
  dev|staging|developer) ;;
  *)
    echo "invalid environment: $ENVIRONMENT" >&2
    usage
    exit 2
    ;;
esac

case "$STATE" in
  active|dormant) ;;
  *)
    echo "invalid state: $STATE" >&2
    usage
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v yq >/dev/null 2>&1; then
  echo "missing required tool: yq" >&2
  exit 1
fi

overlay="overlays/${ENVIRONMENT}/kustomization.yaml"
replica_patch="replicas-${STATE}.yaml"

if [ ! -f "overlays/${ENVIRONMENT}/${replica_patch}" ]; then
  echo "missing replica patch: overlays/${ENVIRONMENT}/${replica_patch}" >&2
  exit 1
fi

patch_count="$(yq -r '[.patches[]? | select(.target.kind == "Deployment" and (.path == "replicas-active.yaml" or .path == "replicas-dormant.yaml"))] | length' "$overlay")"
if [ "$patch_count" != "1" ]; then
  echo "${overlay} must contain exactly one deployment replica state patch, found: ${patch_count}" >&2
  exit 1
fi

REPLICA_PATCH="$replica_patch" yq -i '(.patches[] | select(.target.kind == "Deployment" and (.path == "replicas-active.yaml" or .path == "replicas-dormant.yaml")) | .path) = env(REPLICA_PATCH)' "$overlay"

if [ "${YAS_CD_SKIP_VALIDATE:-0}" != "1" ]; then
  scripts/validate-gitops.sh
fi

echo "set ${ENVIRONMENT} to ${STATE}"
