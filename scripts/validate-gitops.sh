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

service_count="$(yq e '.services | length' services.yaml)"
if [ "$service_count" -le 0 ]; then
  echo "services.yaml does not contain services" >&2
  exit 1
fi

deployable_images="$(mktemp)"
trap 'rm -f "$deployable_images"' EXIT

yq -r '.services[] | select(.deploy == true) | .imageName' services.yaml | sort >"$deployable_images"

for overlay in dev staging developer; do
  echo "validating overlay: $overlay"

  overlay_images="$(mktemp)"
  yq -r '.images[].name | split("/")[-1]' "overlays/${overlay}/kustomization.yaml" | sort >"$overlay_images"

  if ! diff -u "$deployable_images" "$overlay_images"; then
    echo "overlay ${overlay} image list does not match deployable services.yaml images" >&2
    rm -f "$overlay_images"
    exit 1
  fi
  rm -f "$overlay_images"

  kustomize build --enable-helm --load-restrictor=LoadRestrictionsNone "overlays/${overlay}" >/dev/null
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
