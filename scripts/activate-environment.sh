#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <baseline|developer-preview>" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

TARGET_MODE="$1"

case "$TARGET_MODE" in
  baseline|developer-preview) ;;
  *)
    echo "invalid mode: $TARGET_MODE" >&2
    usage
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

case "$TARGET_MODE" in
  baseline)
    YAS_CD_SKIP_VALIDATE=1 scripts/set-environment-state.sh dev active
    YAS_CD_SKIP_VALIDATE=1 scripts/set-environment-state.sh staging active
    YAS_CD_SKIP_VALIDATE=1 scripts/set-environment-state.sh developer dormant
    ;;
  developer-preview)
    YAS_CD_SKIP_VALIDATE=1 scripts/set-environment-state.sh dev active
    YAS_CD_SKIP_VALIDATE=1 scripts/set-environment-state.sh staging dormant
    YAS_CD_SKIP_VALIDATE=1 scripts/set-environment-state.sh developer active
    ;;
esac

case "$TARGET_MODE" in
  baseline)
    scripts/validate-gitops.sh
    ;;
  developer-preview)
    YAS_CD_EXPECTED_ACTIVE="dev developer" scripts/validate-gitops.sh
    ;;
esac

echo "activated runtime mode: ${TARGET_MODE}"
