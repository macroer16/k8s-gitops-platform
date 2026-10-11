#!/usr/bin/env bash
# Creates the local cluster on your machine and installs the whole platform.
set -euo pipefail
cd "$(dirname "$0")/.."
KEY_BACKUP="${HOME}/.config/k8s-gitops-platform/sealed-secrets-key.yaml"

for tool in docker k3d kubectl helm kubeseal jq; do
  command -v "$tool" >/dev/null || { echo "Missing: $tool (see scripts/install-tools.sh)"; exit 1; }
done

if ! k3d cluster list platform >/dev/null 2>&1; then
  k3d cluster create --config cluster/k3d.yaml --wait
fi
kubectl config use-context k3d-platform

# Restore the sealed-secrets key from a previous cluster, so committed secrets still decrypt.
if [[ -f "$KEY_BACKUP" ]]; then
  echo "==> Restoring sealed-secrets key from ${KEY_BACKUP}"
  kubectl apply -f "$KEY_BACKUP"
fi

scripts/bootstrap.sh local main
scripts/wait-healthy.sh 1200

cat <<MSG

Platform is up.
  App:     https://due.localhost
  ArgoCD:  https://argocd.localhost   user admin, password: make argocd-password
  Grafana: https://grafana.localhost  user admin, password: make grafana-password
Your browser will warn about the certificate: it's signed by the cluster's own CA.
MSG
