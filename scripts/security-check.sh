#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR"

echo "APEX SECURITY VERIFICATION"

FAILED=0


check() {

    local description="$1"

    shift

    if "$@"; then

        echo "PASS: $description"

    else

        echo "FAIL: $description"

        FAILED=1

    fi

}



check "Environment file exists" \
    test -f .env



check "Environment file has mode 600" \
    test "$(stat -c '%a' .env)" = "600"



check "Git ignores .env" \
    git check-ignore -q .env



API_CONTAINER="$(docker compose ps -q api)"

if [[ -z "$API_CONTAINER" ]]; then

    echo "FAIL: API container is not running"

    exit 1

fi



USER_ID="$(docker compose exec -T api id -u)"

check "Application runs as non-root" \
    test "$USER_ID" -ne 0



READ_ONLY="$(docker inspect \
    --format '{{.HostConfig.ReadonlyRootfs}}' \
    "$API_CONTAINER")"

check "Read-only root filesystem" \
    test "$READ_ONLY" = "true"



SECURITY_OPTIONS="$(docker inspect \
    --format '{{json .HostConfig.SecurityOpt}}' \
    "$API_CONTAINER")"

check "No-new-privileges enabled" \
    bash -c \
    '[[ "$1" == *no-new-privileges:true* ]]' \
    _ "$SECURITY_OPTIONS"



CAPABILITIES="$(docker inspect \
    --format '{{json .HostConfig.CapDrop}}' \
    "$API_CONTAINER")"

check "Linux capabilities dropped" \
    bash -c \
    '[[ "$1" == *ALL* ]]' \
    _ "$CAPABILITIES"


echo
echo "======================================"

if [[ "$FAILED" -eq 0 ]]; then

    echo "SECURITY CHECKS PASSED"

else

    echo "SECURITY CHECKS FAILED"

fi

echo "======================================"

exit "$FAILED"
