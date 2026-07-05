#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <dev|staging> <image-tag>" >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

ENVIRONMENT="$1"
IMAGE_TAG="$2"

case "$ENVIRONMENT" in
  dev|staging) ;;
  *)
    echo "invalid environment: $ENVIRONMENT" >&2
    usage
    exit 2
    ;;
esac

if [ -z "$IMAGE_TAG" ]; then
  echo "image tag must not be empty" >&2
  exit 1
fi

if [ "$ENVIRONMENT" = "staging" ] && ! [[ "$IMAGE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "staging sampledata seed requires immutable release tag vX.Y.Z, got: $IMAGE_TAG" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v yq >/dev/null 2>&1; then
  echo "missing required tool: yq" >&2
  exit 1
fi

overlay="operations/sampledata-seed/${ENVIRONMENT}/kustomization.yaml"
if [ ! -f "$overlay" ]; then
  echo "missing sampledata seed overlay: $overlay" >&2
  exit 1
fi

IMAGE_TAG="$IMAGE_TAG" yq -i '(.images[] | select(.name == "docker.io/emanhthangngot/yas-sampledata") | .newTag) = env(IMAGE_TAG)' "$overlay"

kustomize build --load-restrictor=LoadRestrictionsNone "$(dirname "$overlay")" >/dev/null

echo "prepared sampledata seed for ${ENVIRONMENT} with image tag ${IMAGE_TAG}"
