#!/usr/bin/env bash
# Creates the app's secrets as SealedSecrets: encrypted with the cluster's public key,
# so the encrypted files are safe to store in Git.
#   local: writes secrets/local/*.yaml (commit them) unless they already exist
#   ci:    applies them straight to the throwaway cluster
set -euo pipefail
CLUSTER="${1:?usage: make-secrets.sh local|ci}"
cd "$(dirname "$0")/.."
OUT="secrets/${CLUSTER}"
KEY_BACKUP="${HOME}/.config/k8s-gitops-platform/sealed-secrets-key.yaml"

if [[ "$CLUSTER" == "local" && -f "$OUT/due-secrets.yaml" ]]; then
  echo "==> Sealed secrets already exist in ${OUT}; ArgoCD applies them."
  exit 0
fi

random() { head -c 48 /dev/urandom | base64 | tr -d '/+=\n' | head -c "$1"; }
seal() { kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller --format yaml; }

mkdir -p "$OUT"
kubectl create secret generic due-secrets --namespace due \
  --from-literal=DATABASE_PASSWORD="$(random 32)" \
  --from-literal=JWT_SECRET="$(random 48)" \
  --dry-run=client -o yaml | seal > "$OUT/due-secrets.yaml"
kubectl create secret generic grafana-admin --namespace monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(random 24)" \
  --dry-run=client -o yaml | seal > "$OUT/grafana-admin.yaml"
kubectl apply -f "$OUT/due-secrets.yaml" -f "$OUT/grafana-admin.yaml"

if [[ "$CLUSTER" == "local" ]]; then
  # Back up the controller's private key outside the repo, so a rebuilt cluster can
  # still decrypt the files you commit. Never commit this file.
  mkdir -p "$(dirname "$KEY_BACKUP")"
  kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "$KEY_BACKUP"
  chmod 600 "$KEY_BACKUP"
  echo "==> Wrote ${OUT}/*.yaml. Commit and push them so ArgoCD manages them:"
  echo "    git add ${OUT} && git commit -m 'Add sealed secrets for local cluster' && git push"
  echo "    Controller key backed up to ${KEY_BACKUP} (keep it private)."
else
  rm -rf "$OUT"
fi
