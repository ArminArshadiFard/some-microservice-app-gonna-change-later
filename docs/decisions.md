# Decisions Log

Short record of design and implementation decisions. One entry per decision, newest at the bottom. This file feeds Part 6 (final report: "design and implementation decisions") so keep it updated as we go.

**Entry format:** context -> decision -> alternatives -> consequences.
**Status values:** Accepted, Superseded (link to the newer entry), Proposed.

---

## D-001: Domain is event ticketing
- **Status:** Accepted
- **Context:** The assignment allows e-commerce "or similar domain". We wanted a domain with a real engineering problem for the load test and fault-tolerance demos.
- **Decision:** Event ticketing. Role mapping: Product = event-service, Order = booking-service; User, Payment and Notification are unchanged.
- **Alternatives:** E-commerce, appointment booking, inventory management.
- **Consequences:** Limited seats create a concurrency problem (overselling) that we must solve and test. Service names differ from the assignment text, so the report includes the role mapping.

## D-002: Python 3.12 with Django REST Framework for all services
- **Status:** Accepted
- **Context:** Two-person team, four weeks, five services.
- **Decision:** One language and framework everywhere, so a skeleton built once is copied to every service.
- **Alternatives:** FastAPI, Node.js/Express.
- **Consequences:** Less context switching and shared tooling (ruff, pytest, Dockerfile). Django is heavier per service than FastAPI; acceptable at this scale.

## D-003: PostgreSQL for every service, one instance, five databases
- **Status:** Accepted
- **Context:** Each service must own its data; Minikube RAM is limited.
- **Decision:** One PostgreSQL instance with five databases and five users; each service has credentials only for its own database. No cross-service table access.
- **Alternatives:** MongoDB for event-service; one instance per service.
- **Consequences:** Low memory use and one engine to operate. Isolation is logical, not physical; the report lists per-service instances and MongoDB as future work.

## D-004: REST for synchronous calls, RabbitMQ for asynchronous events
- **Status:** Accepted
- **Context:** Booking needs the seat hold and the payment result before it can answer; notification must never block a booking.
- **Decision:** REST (httpx) for Booking -> Event and Booking -> Payment. RabbitMQ with Celery consumers for Booking -> Notification (`booking.confirmed`).
- **Alternatives:** gRPC, Kafka.
- **Consequences:** OpenAPI documents every call. RabbitMQ is light enough for Minikube.

## D-005: Seats are held before payment and expire
- **Status:** Accepted
- **Context:** Charging before reserving can oversell; reserving without expiry can lock seats forever.
- **Decision:** Booking-service asks event-service to hold seats (atomic decrement of available seats). Booking status flow: `HELD` -> `PAID` or `EXPIRED` / `CANCELLED`. A Celery beat task expires holds after a fixed time (default 10 minutes) and releases the seats.
- **Alternatives:** Reserve only after payment; distributed locks with Redis.
- **Consequences:** No oversold seats and no permanently locked seats. Needs a periodic task and a release endpoint in event-service.

## D-006: Atomic seat update in the database
- **Status:** Accepted
- **Context:** Many buyers compete for the last tickets.
- **Decision:** Use a single conditional update (`UPDATE ... SET available = available - n WHERE available >= n`) or `SELECT ... FOR UPDATE` in one transaction. No application-level counters.
- **Alternatives:** Redis counters, optimistic version checks.
- **Consequences:** Correctness comes from the database. Verified by a concurrency test and the k6 load test.

## D-007: tenacity retries and pybreaker circuit breaker on Booking -> Payment
- **Status:** Accepted
- **Context:** The assignment names Resilience4j or Istio, which are Java and service-mesh tools.
- **Decision:** Application-level equivalents: explicit timeouts, tenacity with exponential backoff and jitter on transient errors only (timeouts, 5xx), pybreaker for the circuit breaker. If the circuit is open the booking stays `HELD` and the client gets a clear "payment temporarily unavailable" response.
- **Alternatives:** Istio retries and outlier detection.
- **Consequences:** Works in Compose and Kubernetes with no mesh. Payment-service has a configurable failure mode so the behaviour can be demonstrated on demand.

## D-008: JWT validated locally by each service
- **Status:** Accepted
- **Context:** Avoid a call to user-service on every request.
- **Decision:** User-service issues short-lived access tokens (simplejwt) plus refresh tokens; other services verify the signature using configuration injected from a Kubernetes Secret.
- **Alternatives:** Token introspection endpoint, API gateway auth.
- **Consequences:** No runtime dependency on user-service for authorization. Key rotation needs a redeploy; noted as a limitation.

## D-009: Kubernetes on Minikube with nginx-ingress
- **Status:** Accepted
- **Context:** Assignment requires a Kubernetes deployment and ingress or gateway.
- **Decision:** Minikube, plain YAML manifests, nginx-ingress with path routing (`/api/users`, `/api/events`, `/api/bookings`, `/api/payments`, `/api/notifications`). Start with `--memory=4096 --cpus=2`.
- **Alternatives:** Kong, Istio, a cloud cluster, Helm.
- **Consequences:** Lightest option that meets the requirement. If RAM is too small, monitoring runs through Compose and the trade-off is documented (see D-011).

## D-010: GitHub Actions and GHCR for CI/CD
- **Status:** Accepted
- **Context:** Repo is on GitHub; no server to maintain.
- **Decision:** Pipeline: ruff -> pytest (matrix across services) -> docker build -> push to GHCR on `main`. Deploy job (`kubectl apply`) is optional and manually triggered. Branch protection requires status checks and one approval.
- **Alternatives:** Jenkins.
- **Consequences:** Pipeline lives next to the code. A real automatic deploy to a cloud cluster is out of scope.

## D-011: Monitoring with Prometheus, Grafana and Alertmanager
- **Status:** Accepted
- **Context:** Part 5 needs health monitoring, alerts and a dashboard screenshot.
- **Decision:** `django-prometheus` on every service, Prometheus scrape config, a Grafana dashboard exported as JSON, alert rules for service down, high error rate and high resource usage. Verify the service-down alert by stopping a service.
- **Alternatives:** Cloud monitoring services.
- **Consequences:** Needs extra memory. Fallback: run the monitoring stack in Compose and record this in the report.

## D-012: React frontend is optional and capped
- **Status:** Accepted
- **Context:** The frontend is not graded.
- **Decision:** Thin React UI (event list and book a ticket), hard cap of 6 hours, built only after S3 is done.
- **Alternatives:** No UI, Swagger UI only.
- **Consequences:** Cut first if any sprint slips.

---

## Template for new entries

```
## D-0XX: Title
- **Status:** Proposed | Accepted | Superseded by D-0YY
- **Context:**
- **Decision:**
- **Alternatives:**
- **Consequences:**
```