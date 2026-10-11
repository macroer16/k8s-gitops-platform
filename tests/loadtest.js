// k6 load test: one user, many requests. Run by tests/loadtest.sh inside the cluster.
import http from "k6/http";
import { check } from "k6";
import { Counter } from "k6/metrics";

// due.localhost is pointed at the Gateway's in-cluster IP, so the TLS name (SNI) and
// Host header are exactly what a browser would send.
const BASE = "https://due.localhost";
const params = { headers: {} };
const rateLimited = new Counter("rate_limited_429");

export const options = {
  hosts: { "due.localhost": __ENV.GATEWAY_IP },
  insecureSkipTLSVerify: true,
  stages: [
    { duration: "30s", target: 20 },
    { duration: "3m", target: 40 },
    { duration: "30s", target: 0 },
  ],
  thresholds: {
    // Successful requests must stay fast even while the API is scaling.
    "http_req_duration{expected_response:true}": ["p(95)<800"],
    checks: ["rate>0.95"],
  },
};

export function setup() {
  const email = `load-${Date.now()}@example.com`;
  const password = "a long load test password";
  http.post(`${BASE}/api/auth/register`, JSON.stringify({ email, password }),
    { headers: { ...params.headers, "Content-Type": "application/json" } });
  const login = http.post(`${BASE}/api/auth/login`, { username: email, password }, params);
  const token = login.json("access_token");
  for (let i = 0; i < 20; i++) {
    const due = new Date(Date.now() + i * 36e5 * 12).toISOString();
    http.post(`${BASE}/api/deadlines`, JSON.stringify({ title: `Load test ${i}`, due_at: due }),
      { headers: { ...params.headers, "Content-Type": "application/json", Authorization: `Bearer ${token}` } });
  }
  return { token };
}

export default function (data) {
  const p = { headers: { ...params.headers, Authorization: `Bearer ${data.token}` } };
  for (const path of ["/api/deadlines/upcoming?days=30", "/api/deadlines", "/api/modules"]) {
    const res = http.get(`${BASE}${path}`, p);
    if (res.status === 429) rateLimited.add(1);
    // 429 means the gateway's rate limit did its job, so it counts as a pass.
    check(res, { "200 or rate-limited": (r) => r.status === 200 || r.status === 429 });
  }
}
