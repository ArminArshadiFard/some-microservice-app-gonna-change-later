# Project Plan

Event ticketing platform: five microservices (user, event, booking, payment, notification).

Two-person team. Sprints = GitHub Milestones. Tasks = Issues with assignee.
Estimates are indicative; rebalance at each planning.

## Milestone overview

| Sprint | Focus | Assignment parts covered | Exit criteria |
|---|---|---|---|
| S0 (3 days) | Setup & skeleton | — (enables all) | `docker compose up` -> 5 `/health/` return 200, CI green |
| S1 (week 1) | Design + User + Event | Part 1 (10%), start Part 2 | Design docs merged; register/login + event CRUD/search + seat hold working |
| S2 (week 2) | Booking + Payment + Notification + fault tolerance | Part 2 (40%), Part 3 (15%) | Full booking flow works; circuit breaker and hold expiry demoable |
| S3 (week 3) | Docker + K8s + CI/CD | Part 4 (20%), Part 5 (10%) | All services running on Minikube via ingress; images from GHCR |
| S4 (week 4) | Monitoring + tests + report + demo | Part 5, Part 6 (5%) | Dashboard screenshot, k6 results, report PDF, demo video |

## Role mapping (assignment -> this project)

| Assignment role | Our service | Main data |
|---|---|---|
| User Service | user-service | users, profiles |
| Product Service | event-service | events, ticket types, seat availability |
| Order Service | booking-service | bookings, status history |
| Payment Service | payment-service | payments |
| Notification Service | notification-service | sent notifications |

## Tasks

Owner: **A** = Armin, **B** = Amir. Split by service ownership (see Ownership below); both of us touch infrastructure.

### S0 — Setup (3 days)
| # | Task | Owner | Est | Depends |
|---|---|---|---|---|
| S0-1 | Repo, collaborator, branch protection | A | 1h | — |
| S0-2 | Scaffold + `docs/tech-stack.md`, `decisions.md`, `conventions.md` | A | 2h | S0-1 |
| S0-3 | `docker-compose.yml` + Postgres init (5 DBs, 5 users) + RabbitMQ | A | 3h | S0-2 |
| S0-4 | `user-service` full skeleton (health, Swagger, /metrics/, JWT config, Dockerfile) | A | 4h | S0-3 |
| S0-5 | Copy skeleton -> event, booking, payment, notification services | B | 3h | S0-4 |
| S0-6 | Minimal CI (ruff + pytest + docker build) | B | 3h | S0-5 |
| S0-7 | Enable required status checks on `main` | A | 0.5h | S0-6 |

### S1 — Design + User + Event (week 1)
| # | Task | Owner | Est | Depends |
|---|---|---|---|---|
| S1-1 | Architecture diagram (`docs/architecture.png`) | A | 3h | S0 |
| S1-2 | API contracts per service (endpoint list -> OpenAPI), incl. seat hold/release endpoints | B | 4h | S0 |
| S1-3 | DB schema per service (ERDs in docs) | B | 2h | S0 |
| S1-4 | User service: models, register/login, profile, roles (attendee/organizer), tests | A | 8h | S0-4 |
| S1-5 | Event service: event + ticket-type CRUD, search, atomic seat hold/release, tests | B | 9h | S0-5 |
| S1-6 | Part 1 deliverable assembled (diagram + contracts + schemas) | A | 1h | S1-1..3 |
| S1-7 | `docs/report-outline.md` started | B | 1h | S1-6 |
| S1-8 | Payment service stub: fixed-contract process endpoint (success/failure) so booking is never blocked | A | 2h | S0-4 |
| S1-9 | K8s foundation on Minikube: namespace, ConfigMap, Secret, Postgres (5 DBs), RabbitMQ | A | 4h | S0-3 |

### S2 — Booking + Payment + Notification + fault tolerance (week 2)
| # | Task | Owner | Est | Depends |
|---|---|---|---|---|
| S2-1 | Payment service: process endpoint + failure simulation + unit tests | A | 6h | S1-4 |
| S2-2 | Booking service: create/update/cancel, status flow `HELD`/`PAID`/`EXPIRED`/`CANCELLED`, calls to Event (hold) and Payment (httpx) | B | 7h | S2-1, S1-5 |
| S2-3 | tenacity retries + pybreaker on Booking -> Payment + failure demo test | B | 4h | S2-2 |
| S2-4 | Booking publishes `booking.confirmed` to RabbitMQ | B | 2h | S2-2 |
| S2-5 | Notification: Celery worker, queue consumer, console email, tests | A | 8h | S0-3 |
| S2-6 | Celery beat task in booking-service: expire holds, release seats in event-service | B | 3h | S2-2 |
| S2-7 | Part 3 report (communication strategy) | A | 2h | S2-3, S2-5 |
| S2-8 | Export OpenAPI YAMLs to `docs/openapi/` (CI step) | B | 1h | S1-4, S1-5, S0-6 |
| S2-9 | Event reminder job in notification-service (optional) | A | 1h | S2-5 |

### S3 — Docker + K8s + CI/CD (week 3)
| # | Task | Owner | Est | Depends |
|---|---|---|---|---|
| S3-1 | Finalize Dockerfiles + compose healthchecks + env wiring | A | 2h | S2 |
| S3-2 | K8s: 5 Deployments + Services (probes, resource limits) on top of the S1-9 foundation | A | 6h | S3-1, S1-9 |
| S3-3 | Verify Postgres + RabbitMQ in K8s with the real services; fix wiring (built in S1-9) | A | 1h | S3-2 |
| S3-4 | nginx-ingress, path-based routing, verify all services | A | 3h | S3-3 |
| S3-5 | CI: test matrix -> build -> push to GHCR | B | 5h | S0-6 |
| S3-6 | Optional deploy job (`kubectl apply`, manual trigger) | B | 3h | S3-5, S3-4 |
| S3-7 | Demo video (Part 4) | Both | 2h | S3-4 |
| S3-8 | `docs/demo-video-script.md` | A | 0.5h | — |

### S4 — Monitoring + tests + report (week 4)
| # | Task | Owner | Est | Depends |
|---|---|---|---|---|
| S4-1 | django-prometheus `/metrics/` everywhere + `prometheus.yml` | A | 2h | S3-2 |
| S4-2 | Grafana dashboard JSON + screenshot (Part 5 deliverable) | A | 3h | S4-1 |
| S4-3 | Alertmanager rule (service down) + verify it fires | B | 2h | S4-1 |
| S4-4 | k6 load test: many users competing for limited seats; assert no oversold seats | B | 4h | S3-4 |
| S4-5 | Integration tests: booking -> payment -> notification | B | 3h | S2-5 |
| S4-6 | Concurrency test: parallel holds on limited seats | B | 2h | S1-5 |
| S4-7 | Thin React UI (event list + book ticket), cap at 6h; can start once APIs are stable | B | 6h | S3-4 |
| S4-8 | Final report (≤2000 words) | Both | 8h | all |
| S4-9 | README run instructions + repo polish | A | 2h | all |

## Ownership

| Area | Armin (A) | Amir (B) |
|---|---|---|
| Services | user, payment, notification | event, booking |
| Containers and cluster | Compose, Dockerfiles, all Kubernetes (`deploy/k8s`), ingress | — |
| Pipeline and tests | — | CI/CD (`.github`), GHCR, OpenAPI export, integration, concurrency and k6 tests |
| Monitoring | Prometheus, Grafana (`deploy/monitoring`) | Alertmanager rule |
| Frontend | — | React UI (capped at 6h) |
| Docs | Architecture diagram, Part 1 assembly, Part 3 report, README | API contracts, ERDs, report outline |
| Shared | Final report, demo video, decisions log | Final report, demo video, decisions log |

Cross-service interfaces (agree first, change only by `contract` PR): JWT claims, payment API, `booking.confirmed` message.

## Key flows to demo (grading-friendly)
1. **Happy path:** register -> login -> browse events -> book tickets -> payment succeeds -> booking `PAID` -> notification logged.
2. **Payment failure:** payment-service failure mode on -> retries -> circuit opens -> booking stays `HELD` -> hold expires -> seats released.
3. **Oversell protection:** k6 with hundreds of virtual users on a small seat count -> confirmed tickets never exceed capacity.
4. **Alert:** stop a service -> Prometheus alert fires.

## Definition of Done (every task)
- [ ] Code merged to `main` via reviewed PR (1 approval)
- [ ] Tests pass in CI; new logic has a test
- [ ] `docker compose up` still works
- [ ] Docs/OpenAPI updated if the API changed
- [ ] Issue closed with a one-line note on what was done

## Weekly rhythm
- **Mon 15 min:** sprint planning — move issues to "Ready", confirm owners, rebalance
- **Wed 10 min:** check-in — anything blocked? cut scope if needed
- **Fri 20 min:** demo what works + retro (add a line to `docs/progress-log.md`)
- **Review SLA:** PRs reviewed within 24h. Small PRs (<400 lines) only.

## Scope guardrails
- React is **not graded** — hard cap 6h total.
- Minikube is heavy: if resources choke, run monitoring via compose and note the trade-off.
- If a sprint slips, cut from S4 (frontend, extra alerts) — never from S2/S3 (45% of grade).
- Reminder emails (S2-6) are optional; hold expiry is not.

## Risk register
| Risk | Impact | Mitigation |
|---|---|---|
| Minikube RAM too small for 5 svc + PG + RMQ + monitoring | Part 4 blocked | Start `--memory=4096 --cpus=2`; deploy monitoring via compose if needed |
| K8s/CI left too late | 30% of grade | Sprint 3 dedicated; compose works in S0 |
| RabbitMQ wiring unclear (Celery consumer) | Part 3 blocked | Spike it early in S2 (S2-5 starts day 1) |
| Seat hold race conditions or stuck holds | Core logic incorrect | Atomic DB update (D-006), expiry task (S2-6), concurrency test (S4-6) |
| One teammate unavailable | Slipped sprint | Tasks are single-owner but documented; pair on S2-3 and S3-4 |
| Secret committed by accident | Integrity/security | `.env` ignored + CI secret scan (`gitleaks`) optional |
| Report written at the end from memory | Weak Part 6 | `progress-log.md` + `decisions.md` updated continuously |

## GitHub mapping
- **Milestones:** S0–S4 with due dates.
- **Labels:** `part:1..6`, `svc:user|event|booking|payment|notification`, `type:feat|bug|chore|docs`, `blocked`.
- **Assignees:** the Owner column above.
- **Project board:** Backlog -> Ready -> In Progress -> Review -> Done.