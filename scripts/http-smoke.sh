#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p .work
if curl --silent --max-time 1 http://127.0.0.1:8080/healthz >/dev/null; then
  echo 'Port 8080 is in use; stop the existing development server before the isolated smoke test.' >&2
  exit 69
fi
./scripts/ores --platform=server --allow-net=127.0.0.1:8080 src/main.ores > .work/http-smoke.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' EXIT
ready=false
for attempt in $(seq 1 100); do
  if curl --silent --fail http://127.0.0.1:8080/healthz > .work/health.json; then ready=true; break; fi
  kill -0 "$server_pid" 2>/dev/null || { cat .work/http-smoke.log; exit 1; }
  sleep .1
done
[[ "$ready" == true ]] || { cat .work/http-smoke.log; exit 1; }
jq -e '.status == "development" and .durable_execution == false and .websocket == false' .work/health.json >/dev/null
curl --silent --fail http://127.0.0.1:8080/ > .work/page.html
rg --quiet 'hx-post="/preview"' .work/page.html
curl --silent --fail --request POST http://127.0.0.1:8080/preview > .work/fragment.html
rg --quiet 'Preview reached approval' .work/fragment.html
curl --silent --fail http://127.0.0.1:8080/static/htmx.min.js > .work/htmx.js
cmp static/htmx.min.js .work/htmx.js
[[ "$(curl --silent --output /dev/null --write-out '%{http_code}' http://127.0.0.1:8080/ws)" == 501 ]]
[[ "$(curl --silent --output /dev/null --write-out '%{http_code}' http://127.0.0.1:8080/unknown)" == 404 ]]
[[ "$(curl --silent --output /dev/null --write-out '%{http_code}' --request PUT http://127.0.0.1:8080/preview)" == 405 ]]
echo 'Native Spin/SSR HTTP smoke tests passed'
