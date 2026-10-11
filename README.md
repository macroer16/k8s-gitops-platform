# Latest end-to-end run

Commit `17637edc081e`, run [38174818226](https://github.com/macroer16/k8s-gitops-platform/actions/runs/38174818226), 2026-10-11 21:15 UTC.

## smoke

```
Smoke tests against https://due.localhost:8443
  ok  web app served through the gateway
  ok  Content-Security-Policy header present
  ok  X-Content-Type-Options header present
  ok  API healthy, including its database
  ok  register
  ok  login returns a token
  ok  create deadline
  ok  list shows exactly my deadline
  ok  calendar link has the right public path
  ok  calendar feed works through the gateway
  ok  requests without a token are refused (401)
All smoke tests passed.
```

## policy

```
Policy tests in namespace due
  ok  control: the real signed image with safe settings: allowed
  ok  image from an unapproved registry: rejected
       reason: policy-test was blocked due to the following policies 
  ok  image tagged :latest: rejected
       reason: policy-test was blocked due to the following policies 
  ok  no resource limits: rejected
       reason: policy-test was blocked due to the following policies 
  ok  privilege escalation allowed (Pod Security restricted): rejected
       reason: policy-test" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "c" must set securityContext
  ok  running as root (Pod Security restricted): rejected
       reason: policy-test" is forbidden: violates PodSecurity "restricted:latest": runAsNonRoot != true (pod or container "c" must set securityContext
  ok  unsigned image from our own registry: rejected
       reason: policy-test was blocked due to the following policies 
  ok  Deployment without a readiness probe: rejected
       reason: policy-test was blocked due to the following policies 
Network policy: only the API may reach the database
       from another namespace: blocked
  ok  database blocked from other namespaces
       from the API: reachable
  ok  API can reach the database
All policy tests passed.
```

## loadtest

```
  21:11:25  pods=6  cpu=114% of request
  21:11:35  pods=6  cpu=86% of request
  21:11:45  pods=6  cpu=86% of request
  21:11:55  pods=6  cpu=87% of request
  21:12:06  pods=6  cpu=87% of request
  21:12:16  pods=6  cpu=87% of request
  21:12:26  pods=6  cpu=77% of request
  21:12:36  pods=6  cpu=69% of request
  21:12:46  pods=6  cpu=69% of request
  21:12:56  pods=6  cpu=85% of request
  21:13:06  pods=6  cpu=90% of request
  21:13:17  pods=6  cpu=90% of request
  21:13:27  pods=6  cpu=89% of request
  21:13:37  pods=6  cpu=89% of request
  21:13:47  pods=6  cpu=89% of request
  21:13:57  pods=6  cpu=86% of request
  21:14:07  pods=6  cpu=81% of request
  21:14:17  pods=6  cpu=81% of request
job.batch/k6 condition met
    ✓ 'count>0' count=7712


  █ TOTAL RESULTS 

    checks_total.......................: 43411   184.143062/s
    checks_succeeded...................: 100.00% 43411 out of 43411
    checks_failed......................: 0.00%   0 out of 43411

    ✓ status is 200 or 429

    CUSTOM
    rate_limited_429........................................................: 7712   32.713167/s
      { phase:burst }.......................................................: 7712   32.713167/s

    HTTP
    http_req_duration.......................................................: avg=8.3ms  p(90)=5.19ms p(95)=7.48ms max=2.41s   
      { expected_response:true }............................................: avg=8.3ms  p(90)=5.19ms p(95)=7.48ms max=2.41s   
      { phase:steady }......................................................: avg=4.21ms p(90)=5.08ms p(95)=5.96ms max=229.61ms
    http_req_failed.........................................................: 0.00%  0 out of 43433
      { phase:steady }......................................................: 0.00%  0 out of 31500
    http_reqs...............................................................: 43433  184.236383/s

    EXECUTION
    dropped_iterations......................................................: 89     0.377525/s
    iteration_duration......................................................: avg=8.52ms p(90)=5.37ms p(95)=7.76ms max=2.57s   
    iterations..............................................................: 43411  184.143062/s
    vus.....................................................................: 2      min=0          max=63 
    vus_max.................................................................: 155    min=140        max=155

    NETWORK
    data_received...........................................................: 129 MB 545 kB/s
    data_sent...............................................................: 2.8 MB 12 kB/s




running (3m55.7s), 000/155 VUs, 43411 complete and 0 interrupted iterations
steady ✓ [ 100% ] 000/040 VUs  3m30s  150.00 iters/s
burst  ✓ [ 100% ] 000/115 VUs  20s    600.00 iters/s
API pods: started at 2, peaked at 6
```

## Applications

```
NAME              SYNC STATUS   HEALTH STATUS
cert-manager      Synced        Healthy
due               Synced        Healthy
envoy-gateway     Synced        Healthy
kyverno           Synced        Healthy
metrics-server    Synced        Healthy
monitoring        Synced        Healthy
platform          Synced        Healthy
platform-config   Synced        Healthy
sealed-secrets    Synced        Healthy
```

## Browser problems during screenshots

```
failed https://grafana.localhost:8443/apis/features.grafana.app/v0alpha1/namespaces/default/ofrep/v1/evaluate/flags net::ERR_ABORTED
console: Failed to initialize OpenFeature provider AggregateError: Provider errors occurred: OpenFeature Remote Evaluation Protocol Web Provider: a: The OFREP request failed.
    at xe (https://grafana.localhost:8443/public/build/7606.e8e4d98948a4bb1cf3bc.js:451:35554)
    at ee (https://grafana.localhost:84
failed https://grafana.localhost:8443/public/build/img/icons/unicons/sync.svg net::ERR_ABORTED```
