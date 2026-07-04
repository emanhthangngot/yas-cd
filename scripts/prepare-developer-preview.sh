#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <service=tag> [service=tag ...]" >&2
}

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v yq >/dev/null 2>&1; then
  echo "missing required tool: yq" >&2
  exit 1
fi

overlay="overlays/developer/kustomization.yaml"

# Reset unselected services to main so a new preview cannot inherit stale branch images.
while IFS= read -r image_name; do
  image_ref="$(IMAGE_NAME="$image_name" yq -r '.images[] | select(.name | split("/")[-1] == env(IMAGE_NAME)) | .name' "$overlay" | head -n 1)"
  if [ -z "$image_ref" ]; then
    echo "image not found in ${overlay}: ${image_name}" >&2
    exit 1
  fi

  IMAGE_REF="$image_ref" yq -i '(.images[] | select(.name == env(IMAGE_REF)) | .newTag) = "main"' "$overlay"
done < <(yq -r '.services[] | select(.deploy == true) | .imageName' services.yaml)

for assignment in "$@"; do
  if [[ "$assignment" != *=* ]]; then
    echo "invalid service tag assignment: $assignment" >&2
    usage
    exit 2
  fi

  service="${assignment%%=*}"
  tag="${assignment#*=}"

  if [ -z "$service" ] || [ -z "$tag" ]; then
    echo "invalid service tag assignment: $assignment" >&2
    usage
    exit 2
  fi

  service_exists="$(SERVICE="$service" yq -r '.services[] | select(.name == env(SERVICE)) | .name' services.yaml)"
  if [ -z "$service_exists" ]; then
    echo "unknown service in services.yaml: $service" >&2
    exit 1
  fi

  deploy_enabled="$(SERVICE="$service" yq -r '.services[] | select(.name == env(SERVICE)) | .deploy' services.yaml)"
  if [ "$deploy_enabled" != "true" ]; then
    echo "service is not deployable: $service" >&2
    exit 1
  fi

  image_name="$(SERVICE="$service" yq -r '.services[] | select(.name == env(SERVICE)) | .imageName' services.yaml)"
  image_ref="$(IMAGE_NAME="$image_name" yq -r '.images[] | select(.name | split("/")[-1] == env(IMAGE_NAME)) | .name' "$overlay" | head -n 1)"
  if [ -z "$image_ref" ]; then
    echo "image not found in ${overlay}: ${image_name}" >&2
    exit 1
  fi

  IMAGE_REF="$image_ref" TAG="$tag" yq -i '(.images[] | select(.name == env(IMAGE_REF)) | .newTag) = env(TAG)' "$overlay"
done

scripts/activate-environment.sh developer

echo "prepared developer preview: $*"
