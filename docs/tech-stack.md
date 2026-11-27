# Tech Stack

> Living document. Update when a version or choice changes.
> How-to conventions: `docs/conventions.md`. Rationale for debatable picks: `docs/decisions.md`.

## Architecture in one line
Five independent Django/DRF services, each owning one PostgreSQL database,
communicating via REST (sync) and RabbitMQ (async), containerized and deployed to Minikube.

## Core stack

| Concern | Choice | Version | Rationale |
|---|---|---|---|
| Language (backend) | Python | 3.12 | Pinned in all Dockerfiles |
| Backend framework | Django | 5.0.x | Part 2 services |
| API framework | Django REST Framework | 3.15.x | Part 2 |
| API style | REST (not gRPC) | — | Simpler in Django; ADR D1 |
| API docs | drf-spectacular | latest | Auto Swagger → Part 1 & 2 deliverables |
| Auth | djangorestframework-simplejwt | latest | JWT; HS256 shared secret |
| DB driver | psycopg[binary] | 3.x | Postgres 16 |
| WSGI server | gunicorn | latest | Prod-style serving in containers |
| CORS | django-cors-headers | latest | React dev origin |
| Database | PostgreSQL | 16-alpine | One DB per service |
| Message queue | RabbitMQ | 3-management | Part 3 async |
| Async worker | Celery | 5.x | Notification consumer |
| HTTP client (svc→svc) | httpx | latest | Order → Payment |
| Retries | tenacity | latest | Part 3 |
| Circuit breaker | pybreaker | latest | Part 3; ADR D2 |

## Observability

| Concern | Choice | Notes |
|---|---|---|
| App metrics | django-prometheus | `/metrics/` on every service |
| Metrics store | Prometheus | Scrapes all services |
| Dashboards | Grafana | One dashboard, committed as JSON |
| Alerting | Alertmanager | ≥1 rule (service down, error rate) |

## Frontend
| Concern | Choice | Notes |
|---|---|---|
| Language | Node.js 20 | Dev + build |
| Framework | React 18 + Vite 5 | Thin demo (not graded) |
| HTTP | native `fetch` | No state library |

## Delivery & ops

| Concern | Choice | Notes |
|---|---|---|
| Containers | Docker | Dockerfile per service |
| Local orchestration | docker-compose | Postgres + RabbitMQ + 5 services |
| Orchestration | Minikube + nginx-ingress | Path-based routing |
| Registry | GHCR (`ghcr.io/<owner>/<svc>`) | Tags: `:<git-sha>` + `:latest` |
| CI/CD | GitHub Actions | lint → test → build → push → deploy (manual apply) |
| Load testing | k6 | Order flow scenario |
| Tests | pytest, pytest-django, pytest-cov, DRF APIClient | Unit + integration |
| Lint/format | ruff | CI-enforced |

## Environments

| Concern | Local (runserver) | Compose | Minikube |
|---|---|---|---|
| Config source | `.env` | `.env` + `environment:` | ConfigMap + Secret |
| DB host | `localhost:5432` | `postgres:5432` | `postgres.<ns>.svc` |
| Broker | `localhost:5672` | `rabbitmq:5672` | `rabbitmq.<ns>.svc` |
| API docs | on | on | on |
| CORS | allow-all | allow-all | allow-all (dev) |
| `DEBUG` | True | True | False |

## Version pinning policy
Exact versions live in `services/*/requirements.txt`, Dockerfiles (`python:3.12-slim`),
and `frontend/package.json`. This document records intent, not exact pins.

## Security baseline
- Secrets never committed; `.env.example` only.
- `JWT_SECRET` shared across services via env/Secret.
- K8s: DB password + JWT secret in `Secret`; non-secret config in `ConfigMap`.
- `DEBUG=False` and explicit `ALLOWED_HOSTS` on Minikube.
- Service-to-service calls forward the user's JWT (ADR D3).

## Out of scope / future improvements
Refresh-token rotation, RS256, distributed tracing (OpenTelemetry), per-service Postgres
instances, HPA/autoscaling, GitOps (ArgoCD), gRPC, service mesh.