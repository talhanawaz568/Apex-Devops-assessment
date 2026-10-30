#!/usr/bin/env bash

set -Eeuo pipefail



PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR"

IMAGE="${1:?Usage: ./scripts/deploy.sh IMAGE_REFERENCE}"

STATE_DIR=".release-state"

CURRENT_FILE="${STATE_DIR}/current"

PREVIOUS_FILE="${STATE_DIR}/previous"



if [[ ! "$IMAGE" =~ ^ghcr\.io/[a-z0-9_.-]+/[a-z0-9_.-]+:sha-[0-9a-f]{40}$ ]] \
   && [[ ! "$IMAGE" =~ ^ghcr\.io/[a-z0-9_.-]+/[a-z0-9_.-]+@sha256:[0-9a-f]{64}$ ]]
then

    echo "ERROR: Invalid image reference"

    echo "Use a GHCR commit-SHA tag or image digest"

    exit 2

fi



if [[ ! -f ".env" ]]; then

    echo "ERROR: .env file not found"

    exit 2

fi


mkdir -p "$STATE_DIR"

chmod 700 "$STATE_DIR"



PREVIOUS=""

if [[ -s "$CURRENT_FILE" ]]; then

    PREVIOUS="$(cat "$CURRENT_FILE")"

fi

compose() {

    docker compose \
        --env-file .env \
        -f compose.yaml \
        -f compose.release.yaml \
        "$@"

}



echo "====================================="
echo "Starting Deployment"
echo "====================================="

echo "Requested image: $IMAGE"

export APP_IMAGE="$IMAGE"

compose pull api



DIGEST="$(docker image inspect "$IMAGE" \
    --format '{{index .RepoDigests 0}}' \
    2>/dev/null || true)"


if [[ -z "$DIGEST" ]]; then

    echo "ERROR: Unable to determine image digest"

    exit 1

fi


echo "Resolved image: $DIGEST"



if [[ -n "$PREVIOUS" && "$PREVIOUS" == "$DIGEST" ]]; then

    echo "This image is already the recorded release"

    exit 0

fi



echo "Deploying application image..."

compose up \
    -d \
    --no-build \
    --no-deps \
    --force-recreate \
    api



echo "Running deployment smoke tests..."

if bash scripts/smoke-test.sh; then

    echo "Deployment verification successful"


    # Save old release as rollback target.
    if [[ -n "$PREVIOUS" ]]; then

        printf '%s\n' "$PREVIOUS" \
            > "${PREVIOUS_FILE}.tmp"

        mv "${PREVIOUS_FILE}.tmp" "$PREVIOUS_FILE"

    fi


    # Record new verified release.
    printf '%s\n' "$DIGEST" \
        > "${CURRENT_FILE}.tmp"

    mv "${CURRENT_FILE}.tmp" "$CURRENT_FILE"


    echo "====================================="
    echo "DEPLOYMENT SUCCESSFUL"
    echo "====================================="

    echo "Current image: $DIGEST"

    exit 0

fi



echo "ERROR: Deployment validation failed"

echo "Attempting recovery..."


if [[ -n "$PREVIOUS" ]]; then

    echo "Restoring previous image: $PREVIOUS"

    export APP_IMAGE="$PREVIOUS"

    compose pull api

    compose up \
        -d \
        --no-build \
        --no-deps \
        --force-recreate \
        api


    if bash scripts/smoke-test.sh; then

        echo "Previous verified release restored"

    else

        echo "CRITICAL: Recovery verification failed"

        echo "Manual investigation required"

        exit 1

    fi

else

    echo "No previous verified release recorded"

    echo "Manual investigation required"

fi


exit 1
