#!/usr/bin/env bash
# NovaPay Post-Deployment Smoke Test Suite
# Usage: ./smoke-tests.sh --url <base_url> --expected-sha <git_sha> --timeout <seconds>

set -euo pipefail

URL=""
EXPECTED_SHA=""
TIMEOUT=60

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --expected-sha) EXPECTED_SHA="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --target) shift 2 ;;
    --internal) shift ;;
    *) shift ;;
  esac
done

echo "Running smoke tests against ${URL} (timeout: ${TIMEOUT}s)"
FAILED=0

# Test 1: Health check
echo -n "1. Health check (/actuator/health)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${URL}/actuator/health")
if [[ "$STATUS" == "200" ]]; then echo "PASS"; else echo "FAIL (HTTP ${STATUS})"; FAILED=1; fi

# Test 2: Readiness check
echo -n "2. Readiness check (/actuator/ready)... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${URL}/actuator/ready")
if [[ "$STATUS" == "200" ]]; then echo "PASS"; else echo "FAIL (HTTP ${STATUS})"; FAILED=1; fi

# Test 3: Version consistency
echo -n "3. Version consistency check... "
ACTUAL_SHA=$(curl -s --max-time 10 "${URL}/actuator/info" | jq -r '.git.commit.id.abbrev // "unknown"')
if [[ "$ACTUAL_SHA" == "$EXPECTED_SHA"* ]]; then echo "PASS (${ACTUAL_SHA})"; else echo "FAIL (got ${ACTUAL_SHA}, expected ${EXPECTED_SHA})"; FAILED=1; fi

# Test 4: Synthetic transaction
echo -n "4. Synthetic transaction test... "
RESP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -X POST "${URL}/api/v1/test/synthetic-payment")
if [[ "$RESP" == "200" ]]; then echo "PASS"; else echo "FAIL (HTTP ${RESP})"; FAILED=1; fi

# Test 5: Database connectivity
echo -n "5. Database connectivity check... "
DB_STATUS=$(curl -s --max-time 10 "${URL}/actuator/health/db" | jq -r '.status // "DOWN"')
if [[ "$DB_STATUS" == "UP" ]]; then echo "PASS"; else echo "FAIL (${DB_STATUS})"; FAILED=1; fi

# Test 6: Downstream payment gateway ping
echo -n "6. Downstream payment gateway ping... "
GW_STATUS=$(curl -s --max-time 10 "${URL}/actuator/health/paymentGateway" | jq -r '.status // "DOWN"')
if [[ "$GW_STATUS" == "UP" ]]; then echo "PASS"; else echo "FAIL (${GW_STATUS})"; FAILED=1; fi

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "SMOKE TESTS FAILED — triggering rollback evaluation"
  exit 1
else
  echo ""
  echo "All smoke tests PASSED"
  exit 0
fi
