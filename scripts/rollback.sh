#!/usr/bin/env bash

set -Eeuo pipefail


# --------------------------------------------------
# Project Configuration
# --------------------------------------------------

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR"

STATE_DIR=".release-state"

CURRENT_FILE="${STATE_DIR}/current"

PREVIOUS_FILE="${STATE_DIR}/previous"


# --------------------------------------------------
# Verify Configuration
# --------------------------------------------------

if [[ ! -f ".env" ]]; then

    echo "ERROR: .env file not found"

    exit 2

fi


# --------------------------------------------------
# Verify Release History
# --------------------------------------------------

if [[ ! -s "$CURRENT_FILE" ]]; then

    echo "ERROR: Current release is not recorded"

    exit 2

fi


if [[ ! -s "$PREVIOUS_FILE" ]]; then

    echo "ERROR: No previous verified release available"

    exit 2

fi


# --------------------------------------------------
# Load Release Information
# --------------------------------------------------

CURRENT="$(cat "$CURRENT_FILE")"

TARGET="$(cat "$PREVIOUS_FILE")"


echo "====================================="
echo "Starting Application Rollback"
echo "====================================="

echo "Current image: $CURRENT"

echo "Rollback target: $TARGET"


# --------------------------------------------------
# Docker Compose Helper
# --------------------------------------------------

compose() {

    docker compose \
        --env-file .env \
        -f compose.yaml \
        -f compose.release.yaml \
        "$@"

}


# --------------------------------------------------
# Restore Previous Image
# --------------------------------------------------

export APP_IMAGE="$TARGET"

echo "Pulling rollback image..."

compose pull api

echo "Recreating API container..."

compose up \
    -d \
    --no-build \
    --no-deps \
    --force-recreate \
    api


# --------------------------------------------------
# Verify Rollback
# --------------------------------------------------

echo "Verifying restored application..."

if bash scripts/smoke-test.sh; then

    echo "Rollback verification passed"


    # Save restored image as current.
    printf '%s\n' "$TARGET" \
        > "${CURRENT_FILE}.tmp"

    # Preserve old current image as previous.
    printf '%s\n' "$CURRENT" \
        > "${PREVIOUS_FILE}.tmp"

    mv "${CURRENT_FILE}.tmp" "$CURRENT_FILE"

    mv "${PREVIOUS_FILE}.tmp" "$PREVIOUS_FILE"


    echo "====================================="
    echo "ROLLBACK SUCCESSFUL"
    echo "====================================="

    echo "Restored image: $TARGET"

    exit 0

fi


# --------------------------------------------------
# Handle Rollback Failure
# --------------------------------------------------

echo "CRITICAL: Rollback health verification failed"

echo "Release state has not been updated"

echo "Manual incident investigation is required"

exit 1
