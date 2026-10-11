#!/usr/bin/env bash
# Runs the k6 load test inside the cluster against the Gateway, then shows the
# HorizontalPodAutoscaler adding API pods.
set -euo pipefail
cd "$(dirname "$0")/.."
NS=loadtest
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=main -o jsonpath='{.items[0].metadata.name}')
GATEWAY_IP=$(kubectl -n envoy-gateway-system get svc "$SVC" -o jsonpath='{.spec.clusterIP}')

kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -
kubectl -n $NS create configmap k6-script --from-file=tests/loadtest.js --dry-run=client -o yaml | kubectl apply -f -
kubectl -n $NS delete job k6 --ignore-not-found
cat <<YAML | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata: { name: k6, namespace: $NS }
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: k6
          image: docker.io/grafana/k6:1.0.0
          args: ["run", "--summary-trend-stats=avg,p(90),p(95),max", "/scripts/loadtest.js"]
          env: [{ name: GATEWAY_IP, value: "$GATEWAY_IP" }]
          volumeMounts: [{ name: script, mountPath: /scripts }]
      volumes: [{ name: script, configMap: { name: k6-script } }]
YAML

echo "API pods while the load test runs (autoscaler: min 2, max 6):"
max=0
for _ in $(seq 1 30); do
  n=$(kubectl -n due get hpa due-api -o jsonpath='{.status.currentReplicas}')
  cpu=$(kubectl -n due get hpa due-api -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
  echo "  $(date +%T)  pods=${n}  cpu=${cpu:-?}% of request"
  (( n > max )) && max=$n
  kubectl -n $NS get job k6 -o jsonpath='{.status.conditions[*].type}' | grep -qE 'Complete|Failed' && break
  sleep 10
done
kubectl -n $NS wait --for=condition=complete job/k6 --timeout=6m || true
kubectl -n $NS logs job/k6 | tail -40
echo "Peak API pods: ${max}"
echo "$max" > /tmp/peak-replicas
kubectl -n $NS get job k6 -o jsonpath='{.status.succeeded}' | grep -q 1
