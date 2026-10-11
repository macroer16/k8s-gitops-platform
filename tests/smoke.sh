#!/usr/bin/env bash
# End-to-end checks through the real Gateway: HTTPS, routing, security headers, and the app working.
#   tests/smoke.sh [base URL, default https://due.localhost]
set -euo pipefail
BASE="${1:-https://due.localhost}"
CURL=(curl -fsS --insecure --max-time 10)   # the cluster's CA isn't trusted by this machine
pass() { echo "  ok  $1"; }

echo "Smoke tests against ${BASE}"

"${CURL[@]}" "$BASE/" | grep -q '<div id="root">' && pass "web app served through the gateway"

headers=$("${CURL[@]}" -I "$BASE/")
grep -qi '^content-security-policy:' <<<"$headers" && pass "Content-Security-Policy header present"
grep -qi '^x-content-type-options: nosniff' <<<"$headers" && pass "X-Content-Type-Options header present"

[[ "$("${CURL[@]}" "$BASE/api/health")" == '{"status":"ok"}' ]] && pass "API healthy, including its database"

email="smoke-$(date +%s)-$RANDOM@example.com"
password="a long smoke test password"
"${CURL[@]}" -X POST "$BASE/api/auth/register" -H 'content-type: application/json' \
  -d "{\"email\":\"$email\",\"password\":\"$password\"}" >/dev/null && pass "register"
token=$("${CURL[@]}" -X POST "$BASE/api/auth/login" --data-urlencode "username=$email" \
  --data-urlencode "password=$password" | jq -r .access_token)
[[ -n "$token" && "$token" != null ]] && pass "login returns a token"
auth=(-H "Authorization: Bearer $token")

"${CURL[@]}" "${auth[@]}" -X POST "$BASE/api/deadlines" -H 'content-type: application/json' \
  -d '{"title":"Smoke test deadline","due_at":"2030-01-01T09:00:00Z"}' >/dev/null && pass "create deadline"
"${CURL[@]}" "${auth[@]}" "$BASE/api/deadlines" | jq -e 'length == 1' >/dev/null && pass "list shows exactly my deadline"

# The calendar link must include /api, which proves UVICORN_ROOT_PATH and the route rewrite agree.
cal=$("${CURL[@]}" "${auth[@]}" -X POST "$BASE/api/me/calendar-link" | jq -r .url)
[[ "$cal" == */api/calendar/*.ics ]] && pass "calendar link has the right public path"
"${CURL[@]}" "${BASE}/api/calendar/${cal##*/calendar/}" | grep -q BEGIN:VCALENDAR && pass "calendar feed works through the gateway"

code=$(curl -s -o /dev/null -w '%{http_code}' --insecure "$BASE/api/deadlines")
[[ "$code" == 401 ]] && pass "requests without a token are refused (401)"

echo "All smoke tests passed."
