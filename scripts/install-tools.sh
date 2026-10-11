#!/usr/bin/env bash
# Installs the command-line tools this project needs into ~/.local/bin (Linux or WSL2).
# Versions are pinned so everyone gets the same behaviour.
set -euo pipefail

KUBECTL=v1.34.1
HELM=v3.19.0
K3D=v5.8.3
KUBESEAL=0.32.2
BIN="${HOME}/.local/bin"
mkdir -p "$BIN"
cd "$(mktemp -d)"

echo "kubectl ${KUBECTL}"
curl -fsSLo kubectl "https://dl.k8s.io/release/${KUBECTL}/bin/linux/amd64/kubectl"
install kubectl "$BIN/"

echo "helm ${HELM}"
curl -fsSL "https://get.helm.sh/helm-${HELM}-linux-amd64.tar.gz" | tar xz
install linux-amd64/helm "$BIN/"

echo "k3d ${K3D}"
curl -fsSLo k3d "https://github.com/k3d-io/k3d/releases/download/${K3D}/k3d-linux-amd64"
install k3d "$BIN/"

echo "kubeseal ${KUBESEAL}"
curl -fsSL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL}/kubeseal-${KUBESEAL}-linux-amd64.tar.gz" | tar xz kubeseal
install kubeseal "$BIN/"

echo "Done. Make sure ${BIN} is on your PATH."
