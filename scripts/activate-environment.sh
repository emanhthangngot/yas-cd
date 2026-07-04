#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <dev|staging|developer>" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

TARGET_ENVIRONMENT="$1"

case "$TARGET_ENVIRONMENT" in
  dev|staging|developer) ;;
  *)
    echo "invalid environment: $TARGET_ENVIRONMENT" >&2
    usage
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for environment in dev staging developer; do
  if [ "$environment" = "$TARGET_ENVIRONMENT" ]; then
    YAS_CD_SKIP_VALIDATE=1 scripts/set-environment-state.sh "$environment" active
  else
    YAS_CD_SKIP_VALIDATE=1 scripts/set-environment-state.sh "$environment" dormant
  fi
done

scripts/validate-gitops.sh

echo "activated ${TARGET_ENVIRONMENT}; other full-stack environments are dormant"
