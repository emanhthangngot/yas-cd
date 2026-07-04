#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <vX.Y.Z[-suffix]>" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

RELEASE_TAG="$1"

if ! [[ "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "staging requires immutable release tag vX.Y.Z, got: $RELEASE_TAG" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v yq >/dev/null 2>&1; then
  echo "missing required tool: yq" >&2
  exit 1
fi

overlay="overlays/staging/kustomization.yaml"

while IFS= read -r image_name; do
  image_ref="$(IMAGE_NAME="$image_name" yq -r '.images[] | select(.name | split("/")[-1] == env(IMAGE_NAME)) | .name' "$overlay" | head -n 1)"
  if [ -z "$image_ref" ]; then
    echo "image not found in ${overlay}: ${image_name}" >&2
    exit 1
  fi

  IMAGE_REF="$image_ref" RELEASE_TAG="$RELEASE_TAG" yq -i '(.images[] | select(.name == env(IMAGE_REF)) | .newTag) = env(RELEASE_TAG)' "$overlay"
done < <(yq -r '.services[] | select(.deploy == true) | .imageName' services.yaml)

scripts/activate-environment.sh baseline

echo "promoted staging to ${RELEASE_TAG}"
