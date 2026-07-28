#!/usr/bin/env bash
#
# deploy.sh — set up the troubleshooting scenario: install Redis, PostgreSQL and the
# (intentionally broken) Tyk Stack into the `tyk` namespace.
#
# Usage:   bash deploy.sh
#
# Works on macOS, Linux, WSL and Git Bash. Requires: minikube (running),
# kubectl (pointed at minikube) and helm (v3) on your PATH.
#
# NOTE: the Tyk Stack install is EXPECTED to surface errors — that's the exercise.

set -uo pipefail

NAMESPACE="tyk"
VALUES_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/values.yaml"

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$1"; }

info "Checking prerequisites"
for bin in kubectl helm; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: '$bin' not found on your PATH. Please install it and retry." >&2
    exit 1
  fi
done

info "Adding Helm repositories"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
helm repo update

info "Installing Redis (release: tyk-redis)"
helm upgrade --install tyk-redis oci://registry-1.docker.io/bitnamicharts/redis \
  -n "$NAMESPACE" --create-namespace \
  --version 19.0.2 \
  --set image.repository=bitnamilegacy/redis \
  --set auth.password=topsecretpassword

info "Installing PostgreSQL (release: tyk-postgres)"
helm upgrade --install tyk-postgres bitnami/postgresql \
  -n "$NAMESPACE" --create-namespace \
  --version 12.12.10 \
  --set image.repository=bitnamilegacy/postgresql \
  --set auth.database=tyk_analytics \
  --set auth.postgresPassword=topsecretpassword

info "Installing the Tyk Stack (release: tyk-stack)"
if ! helm upgrade --install tyk-stack tyk-helm/tyk-stack \
       -n "$NAMESPACE" --create-namespace -f "$VALUES_FILE"; then
  warn "The Tyk Stack install reported an error — this is expected for the exercise."
  warn "Investigate with the commands below; fix values.yaml and re-run this script."
fi

info "Scenario deployed. Current state:"
kubectl get pods -n "$NAMESPACE" 2>/dev/null || true
cat <<EOF

Next steps:
  kubectl get pods -n $NAMESPACE
  kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp
  kubectl logs <pod-name> -n $NAMESPACE

If a release gets stuck, reset it with:
  helm uninstall tyk-stack -n $NAMESPACE
EOF
