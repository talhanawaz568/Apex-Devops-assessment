# Apex Operations API — DevOps Practical Assessment

A minimal task-tracking API built with FastAPI, PostgreSQL, and Docker Compose.

## Prerequisites
- Docker Engine + Docker Compose plugin
- Optional: Python 3.12 for local development

## Run
```bash
cp .env.example .env
# Replace the DB_PASSWORD placeholder in .env with a strong, unique local value.
docker compose --env-file .env config --quiet
docker compose --env-file .env up --build -d
docker compose ps
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready
curl -i -X POST http://127.0.0.1:8000/api/tasks -H 'Content-Type: application/json' -d '{"title":"Verify daily backup"}'
curl -i http://127.0.0.1:8000/api/tasks
```

API docs: http://127.0.0.1:8000/docs

## Stop (retain database volume)
```bash
docker compose down
```

**Warning:** `docker compose down -v` destroys the database volume.

## Status
This starter includes phases 1–3 only. CI, tests, image promotion, release/rollback and the full runbook are future phases; do not claim they are complete.

## Decisions and limitations
- `create_all` initializes a fresh database for the assessment; production migrations should use Alembic.
- The application is a single instance and Compose does not provide high availability.
- Local `.env` is only an assessment convenience; production should use managed secrets or properly protected secret files.
- A Docker `HEALTHCHECK` monitors process liveness, while `/ready` checks database availability.
- Application dependency versions are pinned; container image tags should also be pinned by digest for stronger immutability in a later hardening step.
