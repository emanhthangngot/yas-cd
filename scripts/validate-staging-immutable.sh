#!/usr/bin/env sh
set -eu

overlay="${1:-overlays/staging/kustomization.yaml}"

if [ ! -f "$overlay" ]; then
  echo "staging immutability check failed: $overlay does not exist" >&2
  exit 1
fi

awk '
  /^[[:space:]]*newTag:[[:space:]]*/ {
    tag = $0
    sub(/^[[:space:]]*newTag:[[:space:]]*/, "", tag)
    gsub(/["'\'']/, "", tag)
    count++
    if (tag !~ /^v[0-9]+\.[0-9]+\.[0-9]+([-.+][0-9A-Za-z.-]+)?$/) {
      printf "staging immutability check failed: mutable or non-release tag %s\n", tag > "/dev/stderr"
      bad = 1
    }
  }
  END {
    if (count == 0) {
      print "staging immutability check failed: no image newTag entries found" > "/dev/stderr"
      bad = 1
    }
    exit bad
  }
' "$overlay"

echo "staging immutability check passed: all staging image tags are release tags"
