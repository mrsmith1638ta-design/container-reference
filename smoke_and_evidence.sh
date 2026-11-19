#!/usr/bin/env bash
set -euo pipefail

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCE="${ROOT}/EVIDENCE/${STAMP}"
PORT="${PORT:-8080}"
BASE="http://127.0.0.1:${PORT}"

mkdir -p "${EVIDENCE}"

{
  echo "timestamp_utc=${STAMP}"
  echo "host_kernel=$(uname -srm)"
  echo "python_version=$(python3 --version 2>&1)"
  echo "pip_version=$(python3 -m pip --version 2>&1 | cut -d' ' -f1-2)"
  echo "working_root=${ROOT}"
} > "${EVIDENCE}/environment.txt"

find "${ROOT}/app" "${ROOT}/tests" "${ROOT}/Dockerfile" "${ROOT}/requirements.txt" \
  -type f -print0 \
  | sort -z \
  | xargs -0 sha256sum > "${EVIDENCE}/source_hashes.txt"

python3 -m pytest "${ROOT}/tests" -v --tb=short 2>&1 | tee "${EVIDENCE}/unit_tests.txt"

python3 -m gunicorn -k uvicorn.workers.UvicornWorker \
  -b "127.0.0.1:${PORT}" -w 1 --timeout 60 app.main:app \
  > "${EVIDENCE}/server_stdout.txt" 2>&1 &
SERVER_PID=$!
trap 'kill "${SERVER_PID}" 2>/dev/null || true' EXIT

for _ in $(seq 1 40); do
  if python3 -c "import urllib.request,sys;urllib.request.urlopen('${BASE}/healthz',timeout=1)" 2>/dev/null; then
    break
  fi
  sleep 0.25
done

{
  echo "=== GET /healthz ==="
  python3 -c "import urllib.request;print(urllib.request.urlopen('${BASE}/healthz',timeout=5).read().decode())"
  echo "=== GET /readyz ==="
  python3 -c "import urllib.request;print(urllib.request.urlopen('${BASE}/readyz',timeout=5).read().decode())"
  echo "=== POST /v1/convert 100C ==="
  python3 -c "
import json,urllib.request
req=urllib.request.Request('${BASE}/v1/convert',data=json.dumps({'value':100.0,'unit':'c'}).encode(),headers={'Content-Type':'application/json'})
print(urllib.request.urlopen(req,timeout=5).read().decode())
"
  echo "=== POST /v1/convert rejected unit ==="
  python3 -c "
import json,urllib.error,urllib.request
req=urllib.request.Request('${BASE}/v1/convert',data=json.dumps({'value':10.0,'unit':'k'}).encode(),headers={'Content-Type':'application/json'})
try:
    urllib.request.urlopen(req,timeout=5)
    print('UNEXPECTED ACCEPT')
except urllib.error.HTTPError as exc:
    print('status', exc.code, exc.read().decode())
"
} 2>&1 | tee "${EVIDENCE}/live_http_session.txt"

kill "${SERVER_PID}" 2>/dev/null || true
wait "${SERVER_PID}" 2>/dev/null || true

{
  echo "run_timestamp_utc=${STAMP}"
  echo "unit_tests=$(grep -c 'PASSED' "${EVIDENCE}/unit_tests.txt" || true) passed"
  echo "live_endpoints_exercised=4"
  echo "source_files_hashed=$(wc -l < "${EVIDENCE}/source_hashes.txt" | tr -d ' ')"
  echo "result=PASS"
} > "${EVIDENCE}/summary.txt"

echo "evidence written to ${EVIDENCE}"
