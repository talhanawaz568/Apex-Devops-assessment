# Apex Operations API | Operational Runbook

*Apex AI Arabia Practical Assessment • Local Docker Compose • Version 1.0*

Purpose: provide a reproducible procedure for deploying, validating, operating, investigating and recovering the FastAPI/PostgreSQL service. Commands assume the repository root and a Bash shell on Ubuntu. Replace placeholders with actual project values and record only verified results.

## 1. System and release architecture

```text
Developer → GitHub → GitHub Actions [Ruff + Pytest]
                                ↓ pass
                         Docker build → Trivy scan
                                ↓ pass
                     GHCR commit-tagged image
                                ↓ controlled release
                  Ubuntu / Docker Compose
                      ├─ FastAPI container (:8000, localhost)
                      │    ├─ /health (process liveness)
                      │    ├─ /ready (DB readiness)
                      │    └─ structured JSON logs
                      └─ PostgreSQL container (private network)
                                └─ named Docker volume
Release script → smoke tests → record digest OR attempt rollback
```

GitHub Actions validates and publishes images; the local release script deploys an approved image. A green CI run is not evidence of a healthy deployment, so smoke tests run after deployment. Database schema is unchanged between demonstration releases.

## 2. Prerequisites and configuration

Required: Ubuntu with Docker Engine and Compose plugin, Git, curl, Bash, Python 3.12 for local testing, access to the GitHub repository, and permission to read any private GHCR image. Docker daemon access is highly privileged.

```bash
docker --version
docker compose version
git --version
python3 --version
sudo systemctl status docker
```

Clone the repository, then create a local configuration file from the nonsecret template:

```bash
git clone <REPOSITORY_URL>
cd apex-devops-assessment
cp .env.example .env
chmod 600 .env
nano .env
```

Configure DB_NAME, DB_USER and a strong unique DB_PASSWORD in .env. Never commit .env, disclose it in screenshots, or share raw rendered Compose configuration. Verify that Git ignores it:

```bash
git check-ignore .env
docker compose --env-file .env config --quiet
```

## 3. First-time deployment and application checks

```bash
docker compose --env-file .env up --build -d
docker compose ps
docker compose logs --tail=60 api
docker compose logs --tail=60 postgres
```

Expected: the API and PostgreSQL containers start and report healthy after startup. If not, read service logs before changing configuration.

```bash
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready
curl -i http://127.0.0.1:8000/api/tasks
```

Expected: /health returns HTTP 200 if the API process responds; /ready returns 200 when a database query succeeds and 503 when PostgreSQL is unavailable. Successful task responses demonstrate database-dependent functionality.

### Create and retrieve a test task

```bash
curl -i -X POST http://127.0.0.1:8000/api/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Verify database backup"}'
curl -i http://127.0.0.1:8000/api/tasks
```

### Verify persistent data across recreation

```bash
docker compose down
docker compose --env-file .env up -d
curl -i http://127.0.0.1:8000/ready
curl -i http://127.0.0.1:8000/api/tasks
```

The created task should remain because PostgreSQL uses a named volume. Never use docker compose down -v in a preservation test: it removes managed volumes and may destroy the database.

## 4. Quality checks and CI troubleshooting

```bash
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
ruff check app tests
python -m pytest -v --junitxml=pytest-results.xml
```

Pytest exercises API behavior against isolated testing dependencies; the live Compose deployment is checked separately. CI runs the same lint and test commands. If a test fails, inspect the failed assertion and traceback; do not skip tests to allow publication.

CI flow: quality job → build and vulnerability scan → publish (eligible main-branch push only). The publish job must not run if required checks fail. For Trivy failures, record package, CVE, installed/fixed versions, and the rescan result after remediation. Do not claim a security finding was fixed without a passing rescan.

## 5. Versioned deployment

Use the exact successful GHCR image reference produced by CI. If the registry package is private, log in with appropriately scoped credentials. Ensure PostgreSQL is available first.

```bash
docker compose --env-file .env up -d postgres
./scripts/deploy.sh ghcr.io/<OWNER>/<REPO>:sha-<FULL_COMMIT_SHA>
./scripts/smoke-test.sh
curl http://127.0.0.1:8000/
cat .release-state/current
```

The deployment script validates the image reference, pulls it, resolves a digest, recreates only the API service, runs smoke tests and records the new release only after successful validation. The release-state directory is local and must remain untracked. The deployment is not zero-downtime.

## 6. Rollback and failure handling

Prerequisites: a previous verified image is recorded and pullable, and the previous application version remains compatible with the current database schema.

```bash
cat .release-state/current
cat .release-state/previous
./scripts/rollback.sh
curl -i http://127.0.0.1:8000/ready
./scripts/smoke-test.sh
curl -i http://127.0.0.1:8000/api/tasks
```

Record the image before and after rollback and the observed API version. A successful smoke test verifies essential application behavior, not complete business correctness. If rollback fails, inspect image availability, application logs, PostgreSQL state, and schema compatibility; leave the incident open and escalate to manual recovery.

Rolling back the container does NOT roll back database schema or data. Production releases involving migrations require backward-compatible changes and tested database backups.

## 7. Incident investigation: database unavailable

Use synthetic test data only. On the local assessment system, first establish a healthy baseline, then deliberately stop PostgreSQL. Collect timestamps and screenshots from actual commands.

```bash
docker compose ps
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready
docker compose stop postgres
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready
./scripts/diagnose.sh
docker compose logs --tail=70 api
docker compose logs --tail=70 postgres
```

Expected during outage: liveness can remain HTTP 200; readiness returns HTTP 503 because its database check fails. Diagnose before restarting; a blanket API restart will not fix an unavailable database.

```bash
docker compose start postgres
docker compose ps
curl -i http://127.0.0.1:8000/ready
./scripts/smoke-test.sh
curl http://127.0.0.1:8000/api/tasks
```

Record the actual restored readiness status, whether tasks persist, observed recovery duration, and the diagnosis. For unexpected production incidents, investigate cause and backups before restarting services.


## 8. Security and operational limitations

Verify non-root execution (docker compose exec api id), read-only filesystem, dropped capabilities, no-new-privileges, private PostgreSQL networking and local .env exclusion. Do not paste docker inspect environment contents into public evidence. For production: use managed secrets, centralized monitoring, tested backups, TLS, access controls and formal alerting.

Known limits: single-host Compose, possible deployment downtime, no guaranteed automatic recovery, no database rollback, no managed backups, and no active Prometheus/Grafana monitoring stack. A proposal is not the same as a deployed monitoring service.


