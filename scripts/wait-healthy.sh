#!/usr/bin/env bash
# Waits until every ArgoCD Application is Synced and Healthy, printing progress.
#   scripts/wait-healthy.sh [timeout seconds, default 900]
set -uo pipefail
TIMEOUT="${1:-900}"
deadline=$(( $(date +%s) + TIMEOUT ))

status() {
  kubectl -n argocd get applications.argoproj.io \
    -o custom-columns='APP:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' --no-headers 2>/dev/null
}

while true; do
  table="$(status)"
  total=$(echo "$table" | grep -c . || true)
  ready=$(echo "$table" | awk '$2=="Synced" && $3=="Healthy"' | grep -c . || true)
  echo "$(date +%T) ${ready}/${total} applications synced and healthy"
  if [[ "$total" -gt 1 && "$ready" -eq "$total" ]]; then
    echo "$table"
    exit 0
  fi
  if (( $(date +%s) > deadline )); then
    echo "Timed out. Current state:"
    echo "$table"
    kubectl -n argocd get applications.argoproj.io -o json \
      | jq -r '.items[] | select(.status.health.status!="Healthy" or .status.sync.status!="Synced")
               | "--- \(.metadata.name): \(.status.conditions // [] | map(.message) | join("; "))\n\(.status.operationState.message // "")"'
    exit 1
  fi
  sleep 15
done
