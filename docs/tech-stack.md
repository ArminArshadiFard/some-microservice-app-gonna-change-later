# Tech Stack

This document records the technology choices for the event ticketing platform (users browse events and book tickets) and the reasoning behind each one. The assignment allows a "similar domain" to e-commerce; the five required service roles map as follows: Product = event-service, Order = booking-service, with User, Payment and Notification unchanged. It covers the "Tech Stack Selection" and "Database Design" requirements of Part 1. Day-to-day decisions that change over time go in `decisions.md`.

## 1. Summary

| Layer | Choice | Why (one line) |
|---|---|---|
| Language | Python 3.12 | One language across all services; fast to build and test |
| API framework | Django 5 + Django REST Framework | Mature auth, ORM, migrations, admin; DRF gives serializers and viewsets |
| API docs | drf-spectacular | Generates OpenAPI 3 + Swagger UI from the code, so docs never drift |
| Auth | JWT via `djangorestframework-simplejwt` | Stateless, works across services without a shared session store |
| Databases | PostgreSQL 16 (one database per service) | Relational integrity for users, bookings, payments |
| Message broker | RabbitMQ | Simple, reliable queues; good fit for Booking -> Notification |
| Async workers | Celery (+ Celery beat) | Consumes RabbitMQ events; runs the hold-expiry and reminder jobs |
| Sync HTTP client | httpx | Timeouts, connection pooling, easy to mock in tests |
| Retries | tenacity | Declarative retry with exponential backoff |
| Circuit breaker | pybreaker | Python equivalent of Resilience4j |
| Containers | Docker + Docker Compose | Local reproducible environment |
| Orchestration | Kubernetes (Minikube) + nginx-ingress | Matches the assignment; path-based routing |
| CI/CD | GitHub Actions + GHCR | Same place as the repo; free for this scale |
| Metrics | Prometheus + django-prometheus | Per-service `/metrics/` with almost no code |
| Dashboards | Grafana | Required screenshot deliverable |
| Alerts | Prometheus alert rules + Alertmanager | Service-down and high-resource alerts |
| Unit/integration tests | pytest + pytest-django | Fast, readable, good fixtures |
| Load testing | k6 | Scriptable, simple results output |
| Lint/format | ruff | One fast tool for lint and format |
| Frontend (optional, not graded) | React + Vite | Thin UI only, capped at 6h |

## 2. Services and ownership of data

Each service is self-contained and owns its own database. No service reads another service's tables.

| Service | Responsibility | Database | Notes |
|---|---|---|---|
| user-service | Register, login, JWT issue, profile (attendee or organizer role) | `users_db` (PostgreSQL) | Passwords hashed with Django's PBKDF2 (or Argon2) |
| event-service | Event and ticket-type CRUD, search, seat availability | `events_db` (PostgreSQL) | Search via indexed `ILIKE` / PostgreSQL full-text search; atomic seat holds |
| booking-service | Create, track and cancel bookings; hold and expiry logic | `bookings_db` (PostgreSQL) | Statuses `HELD`, `PAID`, `EXPIRED`, `CANCELLED`; calls payment-service; publishes `booking.confirmed` |
| payment-service | Simulated payments, failure simulation | `payments_db` (PostgreSQL) | Configurable failure rate for demos and tests |
| notification-service | Consume events, send email (console) | `notifications_db` (PostgreSQL) | Booking confirmation and event reminders; logs sent notifications |

### Database choice rationale

- **PostgreSQL everywhere** keeps operations simple: one engine to run in Compose and Kubernetes, one backup story, one set of skills.
- Bookings, payments and seat counts need transactions and constraints, which favors SQL. Overselling is prevented in event-service with an atomic update (`UPDATE ... SET available = available - n WHERE available >= n`) or `SELECT ... FOR UPDATE` inside a transaction.
- Event search is covered by PostgreSQL full-text search at this scale.
- Deployment: **one PostgreSQL instance with five separate databases and five separate users**, each service holding credentials only for its own database. This keeps Minikube memory low while still enforcing data isolation. In production each service would get its own instance.
- The assignment suggests MongoDB for the catalog service as an example only. We note it as a future improvement for events with flexible attributes (see section 10).

## 3. Inter-service communication

| Path | Style | Technology |
|---|---|---|
| Client -> services | Synchronous REST | nginx-ingress, path-based routing (`/api/users`, `/api/events`, `/api/bookings`, ...) |
| Booking -> Event | Synchronous REST | Hold seats before payment; release them on failure or expiry |
| Booking -> Payment | Synchronous REST | httpx + tenacity retries + pybreaker circuit breaker |
| Booking -> Notification | Asynchronous events | RabbitMQ queue (`booking.confirmed`), Celery consumer |

Why this split: the seat hold and the payment result decide the booking status, so both are synchronous. Notification must never block or fail a booking, so it is asynchronous.

REST was chosen over gRPC because it is simpler to document with OpenAPI, easy to test with curl and Swagger UI, and sufficient for the traffic here.

## 4. Fault tolerance

- **Timeouts:** every outbound call has an explicit timeout (no default infinite waits).
- **Retries:** tenacity, exponential backoff with jitter, limited attempts, only on transient errors (timeouts, 5xx), never on 4xx.
- **Circuit breaker:** pybreaker on Booking -> Payment; opens after N consecutive failures, half-opens after a cool-down.
- **Fallback:** when the circuit is open, the booking stays `HELD` and a clear "payment temporarily unavailable" response is returned. The seat hold expires after a fixed time (e.g. 10 minutes); a Celery beat task marks the booking `EXPIRED` and releases the seats in event-service, so no seats are lost to failures.
- **Failure simulation:** payment-service exposes a configurable failure mode so the circuit breaker can be demonstrated on demand.
- Note: Resilience4j is a Java library and Istio is a service mesh; tenacity + pybreaker is the equivalent at application level for Python.

## 5. Authentication and security

- user-service issues short-lived JWT access tokens plus refresh tokens.
- Other services validate tokens locally using the shared signing configuration (injected via Kubernetes Secret), so there is no call to user-service per request.
- Secrets live in `.env` (git-ignored) locally and in Kubernetes Secrets in the cluster; `.env.example` is committed.
- Passwords are never stored in plain text; input validation through DRF serializers.
- Optional secret scanning in CI with gitleaks.

## 6. Containerization and orchestration

- One Dockerfile per service: slim Python base image, non-root user, dependencies installed from a pinned `requirements.txt`, gunicorn as the server.
- `docker-compose.yml` runs all five services, PostgreSQL, and RabbitMQ with healthchecks and `depends_on` conditions. Monitoring can also run through Compose if Minikube resources are tight.
- Kubernetes (Minikube): namespace, ConfigMap, Secret, Deployment + Service per service, PostgreSQL and RabbitMQ, nginx-ingress for path-based routing.
- Readiness and liveness probes use each service's `/health/` endpoint.
- Start Minikube with `--memory=4096 --cpus=2` as a baseline.

## 7. CI/CD

GitHub Actions, triggered on pull requests and pushes to `main`:

1. Lint (ruff)
2. Tests (pytest, matrix across the five services)
3. Build Docker images
4. Push images to GitHub Container Registry (GHCR) on `main`
5. Optional manual deploy job (`kubectl apply`)

Branch protection on `main` requires the status checks to pass and one review approval.

## 8. Monitoring and alerting

- `django-prometheus` exposes `/metrics/` on every service.
- Prometheus scrapes all services; Grafana shows request rate, latency, error rate, and service up/down.
- Alert rules: service down (`up == 0`), high error rate, high CPU/memory. Alertmanager routes them; the service-down alert is verified by stopping a service.

## 9. Testing

- **Unit tests:** pytest + pytest-django, focus on payment logic (success, failure, simulated errors), booking status transitions and seat-hold expiry.
- **Integration tests:** booking -> payment -> notification flow against the Compose stack.
- **Resilience test:** payment failures trigger retries and then open the circuit breaker; held seats are released after expiry.
- **Concurrency test:** many parallel bookings for a limited number of seats; assert that confirmed tickets never exceed capacity.
- **Load test:** k6 script on the booking flow (e.g. hundreds of virtual users competing for the last tickets), with zero oversold seats as the headline result; results saved under `tests/load/results/`.

## 10. Alternatives considered

| Option | Decision | Reason |
|---|---|---|
| Node.js / Express | Not chosen | Prefer one language and framework across the team |
| FastAPI | Not chosen | Faster per request, but Django gives auth, ORM, and migrations out of the box |
| MongoDB for events | Deferred | Extra engine to run; PostgreSQL full-text search is enough now. Future improvement |
| E-commerce, appointments or inventory domain | Not chosen | Ticketing adds a real concurrency problem (limited seats) that makes the load test and fault-tolerance demos meaningful |
| Kafka | Not chosen | Heavier to run on Minikube; RabbitMQ meets the requirement |
| gRPC | Not chosen | REST is simpler to document and demo with OpenAPI |
| Istio / Kong | Not chosen | Too heavy for Minikube; nginx-ingress is sufficient |
| Jenkins | Not chosen | GitHub Actions is integrated with the repo and needs no server |

## 11. Future improvements

- Separate PostgreSQL instance per service; MongoDB for the event catalog.
- Redis-based seat holds and a virtual waiting room for very high-demand events.
- Event recommendations based on past bookings (an AI-based extra service).
- Outbox pattern for reliable event publishing.
- Distributed tracing (OpenTelemetry + Jaeger).
- API gateway with rate limiting.
- Helm charts and automated deployment from CI.