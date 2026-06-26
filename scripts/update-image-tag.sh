#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <dev|staging|developer> <service> <tag>" >&2
}

if [ "$#" -ne 3 ]; then
  usage
  exit 2
fi

ENVIRONMENT="$1"
SERVICE="$2"
TAG="$3"

case "$ENVIRONMENT" in
  dev|staging|developer) ;;
  *)
    echo "invalid environment: $ENVIRONMENT" >&2
    usage
    exit 2
    ;;
esac

if [ "$ENVIRONMENT" = "staging" ] && ! [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "staging requires immutable release tag vX.Y.Z, got: $TAG" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v yq >/dev/null 2>&1; then
  echo "missing required tool: yq" >&2
  exit 1
fi

service_exists="$(SERVICE="$SERVICE" yq -r '.services[] | select(.name == env(SERVICE)) | .name' services.yaml)"
if [ -z "$service_exists" ]; then
  echo "unknown service in services.yaml: $SERVICE" >&2
  exit 1
fi

deploy_enabled="$(SERVICE="$SERVICE" yq -r '.services[] | select(.name == env(SERVICE)) | .deploy' services.yaml)"
if [ "$deploy_enabled" != "true" ]; then
  echo "service is not deployable: $SERVICE" >&2
  exit 1
fi

image_name="$(SERVICE="$SERVICE" yq -r '.services[] | select(.name == env(SERVICE)) | .imageName' services.yaml)"
overlay="overlays/${ENVIRONMENT}/kustomization.yaml"
image_ref="$(IMAGE_NAME="$image_name" yq -r '.images[] | select(.name | split("/")[-1] == env(IMAGE_NAME)) | .name' "$overlay" | head -n 1)"

if [ -z "$image_ref" ]; then
  echo "image not found in ${overlay}: ${image_name}" >&2
  exit 1
fi

IMAGE_REF="$image_ref" TAG="$TAG" yq -i '(.images[] | select(.name == env(IMAGE_REF)) | .newTag) = env(TAG)' "$overlay"

scripts/validate-gitops.sh

echo "updated ${ENVIRONMENT}/${SERVICE} to ${TAG}"
