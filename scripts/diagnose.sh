set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR"

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"

echo "========================================"
echo "APEX OPERATIONS API - DIAGNOSTICS"
echo "========================================"

echo
echo "[1] Docker Compose Service Status"
echo "----------------------------------------"

docker compose ps


echo
echo "[2] Application Liveness"
echo "----------------------------------------"

curl --silent \
     --show-error \
     --max-time 5 \
     --output /dev/null \
     --write-out 'HTTP Status: %{http_code}\n' \
     "${BASE_URL}/health" || true


echo
echo "[3] Application Readiness"
echo "----------------------------------------"

curl --silent \
     --show-error \
     --max-time 5 \
     --output /dev/null \
     --write-out 'HTTP Status: %{http_code}\n' \
     "${BASE_URL}/ready" || true


echo
echo "[4] API Container Health"
echo "----------------------------------------"

API_CONTAINER="$(docker compose ps -q api)"

if [[ -n "$API_CONTAINER" ]]; then

    docker inspect \
        --format 'Container={{.Name}} State={{.State.Status}} Health={{if .State.Health}}{{.State.Health.Status}}{{else}}not-configured{{end}}' \
        "$API_CONTAINER"

else

    echo "API container not found"

fi


echo
echo "[5] Recent API Logs"
echo "----------------------------------------"

docker compose logs \
    --no-color \
    --tail=30 api


echo
echo "[6] Recent PostgreSQL Logs"
echo "----------------------------------------"

docker compose logs \
    --no-color \
    --tail=20 postgres


echo
echo "========================================"
echo "DIAGNOSTIC COLLECTION COMPLETE"
echo "========================================"
