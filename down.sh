#!/usr/bin/env bash
#
# down.sh — tear down the troubleshooting scenario: remove the Tyk Stack, Redis and
# PostgreSQL Helm releases and delete the `tyk` namespace.
#
# Usage:   bash down.sh
#
# Safe to run repeatedly; anything already gone is skipped. The minikube cluster itself
# is left running (to remove it entirely: `minikube delete`).

set -uo pipefail

NAMESPACE="tyk"

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }

command -v helm    >/dev/null 2>&1 || { echo "ERROR: 'helm' not found on PATH";    exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: 'kubectl' not found on PATH"; exit 1; }

info "Uninstalling Helm releases in namespace '$NAMESPACE'"
for release in tyk-stack tyk-redis tyk-postgres; do
  if helm uninstall "$release" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "  uninstalled: $release"
  else
    echo "  skipped (not found): $release"
  fi
done

info "Deleting namespace '$NAMESPACE'"
kubectl delete namespace "$NAMESPACE" --ignore-not-found

info "Done. The minikube cluster is still running."
echo "    To remove the cluster entirely: minikube delete"
