#!/usr/bin/env bash
# Installs ArgoCD and hands the cluster over to it. Used by both `make up` and CI.
#   scripts/bootstrap.sh <cluster: local|ci> [git revision, default main]
set -euo pipefail
CLUSTER="${1:?usage: bootstrap.sh local|ci [revision]}"
REVISION="${2:-main}"
ARGOCD_CHART_VERSION=10.10.2
cd "$(dirname "$0")/.."

echo "==> Installing ArgoCD (chart ${ARGOCD_CHART_VERSION})"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace --values cluster/argocd-values.yaml --wait --timeout 10m

echo "==> Creating namespaces"
# The app namespace gets Pod Security "restricted" and opts in to the Kyverno policies.
kubectl create namespace due --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace due --overwrite \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  platform.macroer16/policies=enforced
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "==> Handing over to ArgoCD (revision ${REVISION}, values-${CLUSTER}.yaml)"
sed -e "s/\${CLUSTER}/${CLUSTER}/g" -e "s/\${REVISION}/${REVISION}/g" cluster/root-app.yaml | kubectl apply -f -

echo "==> Waiting for the sealed-secrets controller"
for _ in $(seq 1 120); do
  kubectl -n kube-system get deploy sealed-secrets-controller >/dev/null 2>&1 && break
  sleep 5
done
if ! kubectl -n kube-system rollout status deploy/sealed-secrets-controller --timeout=10m; then
  echo "sealed-secrets controller did not start. ArgoCD applications:"
  kubectl -n argocd get applications -o wide || true
  exit 1
fi

scripts/make-secrets.sh "$CLUSTER"
