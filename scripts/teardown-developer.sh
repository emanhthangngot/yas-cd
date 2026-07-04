#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v yq >/dev/null 2>&1; then
  echo "missing required tool: yq" >&2
  exit 1
fi

overlay="overlays/developer/kustomization.yaml"

while IFS= read -r image_name; do
  image_ref="$(IMAGE_NAME="$image_name" yq -r '.images[] | select(.name | split("/")[-1] == env(IMAGE_NAME)) | .name' "$overlay" | head -n 1)"
  if [ -z "$image_ref" ]; then
    echo "image not found in ${overlay}: ${image_name}" >&2
    exit 1
  fi

  IMAGE_REF="$image_ref" yq -i '(.images[] | select(.name == env(IMAGE_REF)) | .newTag) = "main"' "$overlay"
done < <(yq -r '.services[] | select(.deploy == true) | .imageName' services.yaml)

scripts/activate-environment.sh baseline

echo "developer preview torn down; dev and staging restored as active environments"
