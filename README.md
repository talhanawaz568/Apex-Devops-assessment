A containerized FastAPI + PostgreSQL application built for the Apex AI Arabia DevOps Practical Assessment. The project demonstrates automated testing, CI/CD, container security, deployment, monitoring, and rollback.

Tech Stack

Application: Python, FastAPI, PostgreSQL

Containers: Docker, Docker Compose

CI/CD: GitHub Actions, GitHub Container Registry

Testing: Pytest, Ruff

Security: Trivy, non-root containers

Operations: Bash scripts, health checks, structured logging

Architecture

GitHub → GitHub Actions → Tests → Docker Build
                                   |
                              Trivy Scan
                                   |
                                  GHCR
                                   |
                            Docker Compose
                              /        \
                          FastAPI    PostgreSQL

Quick Start

git clone <REPOSITORY_URL>
cd apex-devops-assessment

cp .env.example .env
nano .env
chmod 600 .env

docker compose up --build -d
docker compose ps

Verify application:

curl http://localhost:8000/health
curl http://localhost:8000/ready

Automated Testing

pip install -r requirements-dev.txt
ruff check app tests
python -m pytest -v

Deployment & Rollback

Deploy a CI-validated image:

./scripts/deploy.sh <GHCR_IMAGE_REFERENCE>

Run smoke tests:

./scripts/smoke-test.sh

Rollback to the previous verified release:

./scripts/rollback.sh
