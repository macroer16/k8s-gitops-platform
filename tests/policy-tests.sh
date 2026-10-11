#!/usr/bin/env bash
# Proves the cluster refuses unsafe workloads. Each case is a server-side dry run,
# so nothing is actually created. Every case must be REJECTED, except the control.
#   tests/policy-tests.sh [allowed registry prefix] [unsigned image to test, optional]
set -uo pipefail
REG="${1:-ghcr.io/macroer16}"
UNSIGNED="${2:-}"
NS=due
failures=0

# A pod that satisfies every rule; each test breaks exactly one thing.
pod() {
  local image="$1" security="$2" resources="$3"
  cat <<YAML
apiVersion: v1
kind: Pod
metadata: { name: policy-test, namespace: $NS }
spec:
  securityContext: { runAsNonRoot: true, runAsUser: 10001, seccompProfile: { type: RuntimeDefault } }
  containers:
    - name: c
      image: $image
      securityContext: $security
      resources: $resources
YAML
}
SAFE='{ allowPrivilegeEscalation: false, capabilities: { drop: [ALL] } }'
LIMITS='{ requests: { cpu: 10m, memory: 16Mi }, limits: { memory: 32Mi } }'
GOOD_IMAGE="$(kubectl -n $NS get deploy due-api -o jsonpath='{.spec.template.spec.containers[0].image}')"

expect() {
  local want="$1" name="$2" manifest="$3"
  out=$(echo "$manifest" | kubectl apply --dry-run=server -f - 2>&1)
  if [[ $? -eq 0 ]]; then got=allowed; else got=rejected; fi
  if [[ "$got" == "$want" ]]; then
    echo "  ok  ${name}: ${got}"
  else
    echo "  FAIL ${name}: expected ${want}, got ${got}"; echo "$out" | sed 's/^/       /'
    failures=$((failures + 1))
  fi
  [[ "$got" == rejected ]] && echo "$out" | grep -oE '(policy|violates PodSecurity)[^.]*' | head -1 | sed 's/^/       reason: /'
}

echo "Policy tests in namespace ${NS}"
expect allowed  "control: the real signed image with safe settings" "$(pod "$GOOD_IMAGE" "$SAFE" "$LIMITS")"
expect rejected "image from an unapproved registry" "$(pod docker.io/library/nginx:1.29-alpine "$SAFE" "$LIMITS")"
expect rejected "image tagged :latest" "$(pod "${REG}/due-api:latest" "$SAFE" "$LIMITS")"
expect rejected "no resource limits" "$(pod "$GOOD_IMAGE" "$SAFE" '{}')"
expect rejected "privilege escalation allowed (Pod Security restricted)" "$(pod "$GOOD_IMAGE" '{ allowPrivilegeEscalation: true, capabilities: { drop: [ALL] } }' "$LIMITS")"
expect rejected "running as root (Pod Security restricted)" "$(pod "$GOOD_IMAGE" "$SAFE" "$LIMITS" | sed 's/runAsNonRoot: true, runAsUser: 10001/runAsUser: 0/')"
if [[ -n "$UNSIGNED" ]]; then
  expect rejected "unsigned image from our own registry" "$(pod "$UNSIGNED" "$SAFE" "$LIMITS")"
fi
expect rejected "Deployment without a readiness probe" "$(cat <<YAML
apiVersion: apps/v1
kind: Deployment
metadata: { name: policy-test, namespace: $NS }
spec:
  selector: { matchLabels: { app: policy-test } }
  template:
    metadata: { labels: { app: policy-test } }
    spec:
      securityContext: { runAsNonRoot: true, runAsUser: 10001, seccompProfile: { type: RuntimeDefault } }
      containers:
        - name: c
          image: $GOOD_IMAGE
          securityContext: $SAFE
          resources: $LIMITS
YAML
)"

echo "Network policy: only the API may reach the database"
kubectl -n default run netpol-probe --image=docker.io/library/busybox:1.37 --restart=Never --rm -i --quiet \
  --command -- sh -c 'nc -z -w 3 due-postgres.due.svc.cluster.local 5432 && echo reachable || echo blocked' 2>/dev/null \
  | tee /tmp/netpol.txt | sed 's/^/       from another namespace: /'
grep -q blocked /tmp/netpol.txt && echo "  ok  database blocked from other namespaces" || { echo "  FAIL database reachable"; failures=$((failures+1)); }
kubectl -n $NS exec deploy/due-api -- python -c "import socket; socket.create_connection(('due-postgres', 5432), 3); print('reachable')" \
  | sed 's/^/       from the API: /'
[[ ${PIPESTATUS[0]} -eq 0 ]] && echo "  ok  API can reach the database" || { echo "  FAIL API can't reach database"; failures=$((failures+1)); }

if [[ $failures -gt 0 ]]; then echo "${failures} policy test(s) failed"; exit 1; fi
echo "All policy tests passed."
