#!/usr/bin/env bash

set -Eeuo pipefail

# Application address
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"

# Retry configuration
MAX_ATTEMPTS=25
SLEEP_SECONDS=2


echo "====================================="
echo "Running Application Smoke Tests"
echo "====================================="



READY=false

for ((attempt=1; attempt<=MAX_ATTEMPTS; attempt++)); do

    echo "Readiness attempt: $attempt"

    if curl \
        --fail \
        --silent \
        --max-time 3 \
        "${BASE_URL}/ready" \
        | python3 -c \
          'import json,sys; assert json.load(sys.stdin)["status"] == "ready"' \
          2>/dev/null
    then
        READY=true
        break
    fi

    sleep "$SLEEP_SECONDS"

done


if [[ "$READY" != "true" ]]; then

    echo "FAIL: Application readiness check failed"

    exit 1

fi


echo "PASS: Application readiness"


#Checking Application Liveness

if curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "${BASE_URL}/health" > /dev/null
then

    echo "PASS: Application liveness"

else

    echo "FAIL: Application liveness"

    exit 1

fi



if curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "${BASE_URL}/api/tasks" > /dev/null
then

    echo "PASS: Tasks API"

else

    echo "FAIL: Tasks API"

    exit 1

fi


echo "====================================="
echo "All Smoke Tests Passed"
echo "====================================="

exit 0
