#!/bin/bash
# Repeatedly call the sql-writer endpoint to observe read/write splitting and failover behavior.
# Usage: ./call-writer-repeatedly.sh [interval-seconds] [timeout-seconds]
#    or: BASE_URL=http://<host>:8080 ./call-writer-repeatedly.sh
set -u

BASE_URL="${BASE_URL:-http://localhost:8080}"
INTERVAL="${1:-5}"
# Fail the request if it takes longer than this (defaults to the interval)
TIMEOUT="${2:-$INTERVAL}"

echo "Calling ${BASE_URL}/sql-writer every ${INTERVAL}s with ${TIMEOUT}s timeout (Ctrl+C to stop)"

while true; do
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  sql_result="$(curl -s --max-time "$TIMEOUT" "${BASE_URL}/sql-writer" || echo "Request failed (timeout: ${TIMEOUT}s)")"
  echo "[${timestamp}] sql-writer: ${sql_result}"
  sleep "$INTERVAL"
done