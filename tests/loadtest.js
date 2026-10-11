// k6 load test, run inside the cluster by tests/loadtest.sh. Two scenarios:
//   steady: 150 requests/second for 3.5 minutes, below the rate limit. Every request
//           must succeed, and the API should scale out under the CPU load.
//   burst:  600 requests/second for 20 seconds, well above the 200/s limit. The gateway
//           should answer the excess with 429 instead of passing it to the API.
import http from "k6/http";
import { check } from "k6";
import { Counter } from "k6/metrics";
import exec from "k6/execution";

// due.localhost is pointed at the Gateway's in-cluster IP, so the TLS name (SNI) and
// Host header are exactly what a browser would send.
const BASE = "https://due.localhost";
const PATHS = ["/api/deadlines/upcoming?days=30", "/api/deadlines", "/api/modules"];
const rateLimited = new Counter("rate_limited_429");

export const options = {
  hosts: { "due.localhost": __ENV.GATEWAY_IP },
  insecureSkipTLSVerify: true,
  scenarios: {
    steady: {
      executor: "constant-arrival-rate",
      rate: 150, timeUnit: "1s", duration: "210s",
      preAllocatedVUs: 40, maxVUs: 100,
      tags: { phase: "steady" },
    },
    burst: {
      executor: "constant-arrival-rate",
      rate: 600, timeUnit: "1s", duration: "20s", startTime: "215s",
      preAllocatedVUs: 100, maxVUs: 200,
      tags: { phase: "burst" },
    },
  },
  thresholds: {
    "http_req_failed{phase:steady}": ["rate<0.01"],
    "http_req_duration{phase:steady}": ["p(95)<300"],
    "rate_limited_429{phase:burst}": ["count>0"],
  },
};

export function setup() {
  const email = `load-${Date.now()}@example.com`;
  const password = "a long load test password";
  const json = { headers: { "Content-Type": "application/json" } };
  http.post(`${BASE}/api/auth/register`, JSON.stringify({ email, password }), json);
  const token = http.post(`${BASE}/api/auth/login`, { username: email, password }).json("access_token");
  for (let i = 0; i < 20; i++) {
    const due = new Date(Date.now() + i * 36e5 * 12).toISOString();
    http.post(`${BASE}/api/deadlines`, JSON.stringify({ title: `Load test ${i}`, due_at: due }),
      { headers: { ...json.headers, Authorization: `Bearer ${token}` } });
  }
  return { token };
}

export default function (data) {
  const res = http.get(`${BASE}${PATHS[__ITER % PATHS.length]}`, {
    headers: { Authorization: `Bearer ${data.token}` },
    // In the burst, 429 is the expected answer; in the steady phase it counts as a failure.
    responseCallback: exec.scenario.name === "burst" ? http.expectedStatuses(200, 429) : http.expectedStatuses(200),
  });
  if (res.status === 429) rateLimited.add(1);
  check(res, { "status is 200 or 429": (r) => r.status === 200 || r.status === 429 });
}
