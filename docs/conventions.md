# Conventions

The shared rules for both teammates. If a rule here is wrong or missing, change this file in a PR and note why in `decisions.md`. Services built to these rules plug into each other without surprises.

## 1. Services, ports and names

| Service | Folder | Host port (Compose) | API prefix | Database | DB user |
|---|---|---|---|---|---|
| user-service | `services/user-service` | 8001 | `/api/users/` | `users_db` | `users_user` |
| event-service | `services/event-service` | 8002 | `/api/events/` | `events_db` | `events_user` |
| booking-service | `services/booking-service` | 8003 | `/api/bookings/` | `bookings_db` | `bookings_user` |
| payment-service | `services/payment-service` | 8004 | `/api/payments/` | `payments_db` | `payments_user` |
| notification-service | `services/notification-service` | 8005 | `/api/notifications/` | `notifications_db` | `notifications_user` |

- Inside containers (Compose and Kubernetes) **every service listens on port 8000**. Only the host port mapping differs.
- Service-to-service URLs use the service name: `http://event-service:8000`, `http://payment-service:8000`.
- Python package/module name inside a service: `config` for the Django project, one app per domain concept (e.g. `bookings`).

## 2. Endpoints every service must have

| Path | Purpose |
|---|---|
| `/health/` | Returns 200 `{"status": "ok"}`; used by Docker/K8s probes |
| `/metrics/` | Prometheus metrics (django-prometheus) |
| `<prefix>/docs/` | Swagger UI (drf-spectacular) |
| `<prefix>/schema/` | OpenAPI schema (YAML/JSON) |

`/health/` and `/metrics/` are not prefixed because probes and Prometheus reach the pod directly. Business endpoints and docs always live under the service prefix so ingress path routing works.

## 3. API style

- JSON only, `snake_case` field names, trailing slashes on URLs (Django default).
- Pagination: page-number style, default page size 20, response shape `{"count", "next", "previous", "results"}`.
- Timestamps: ISO 8601 in UTC. IDs: integers (UUIDs only if agreed in `decisions.md`).
- Status codes: 200/201 success, 400 validation, 401 unauthenticated, 403 forbidden, 404 not found, 409 conflict (e.g. not enough seats), 503 dependency unavailable.

### Error format (all services)

```json
{
  "error": {
    "code": "not_enough_seats",
    "message": "Only 2 seats left for this ticket type.",
    "details": {}
  }
}
```

`code` is a stable `snake_case` string; `message` is for humans. Implement once in the skeleton as a DRF exception handler and copy it.

## 4. Authentication

- user-service issues JWT access tokens (short-lived) and refresh tokens (simplejwt).
- Access token claims: `user_id`, `email`, `role` (`attendee` or `organizer`).
- All other services verify the token locally with the shared signing key from the `JWT_SIGNING_KEY` environment variable (same value everywhere in dev; a Kubernetes Secret in the cluster).
- Service-to-service calls forward the caller's `Authorization` header.
- Roles: organizers create/edit events; attendees book tickets.

## 5. Shared enums and events

**Booking status:** `HELD` -> `PAID` | `EXPIRED` | `CANCELLED`
**Payment status:** `SUCCESS` | `FAILED`
**Hold duration:** `SEAT_HOLD_MINUTES` env var, default 10.

**RabbitMQ**
- Queue: `notifications`
- Message on booking confirmation (JSON):

```json
{
  "event": "booking.confirmed",
  "booking_id": 123,
  "user_id": 7,
  "email": "user@example.com",
  "event_id": 4,
  "event_title": "Concert",
  "quantity": 2,
  "total_amount": "50.00",
  "occurred_at": "2026-12-01T10:00:00Z"
}
```

Changing a message shape requires a PR touching both producer and consumer.

## 6. Environment variables

- Naming: `UPPER_SNAKE_CASE`. Every service reads its config only from environment variables.
- Common: `DJANGO_SECRET_KEY`, `DJANGO_DEBUG`, `DJANGO_ALLOWED_HOSTS`, `DATABASE_URL`, `JWT_SIGNING_KEY`.
- Dependencies: `EVENT_SERVICE_URL`, `PAYMENT_SERVICE_URL`, `RABBITMQ_URL`.
- Real values go in `.env` (git-ignored). The committed `.env.example` lists every variable with a safe dev value. **Never commit `.env`.**

## 7. Git workflow

- `main` is protected: PR required, 1 approval, CI green.
- Branch names: `feat/<service>-<topic>`, `fix/<service>-<topic>`, `chore/<topic>`, `docs/<topic>`.
- Commits: `type(scope): message`, e.g. `feat(booking): add seat hold call`. Types: `feat`, `fix`, `chore`, `docs`, `test`, `ci`, `refactor`.
- One PR = one task from the plan, under 400 lines. Put the issue number in the PR description (`Closes #12`).
- Review within 24h. Reviewer runs `docker compose up` if the PR touches infrastructure.
- Update your branch from `main` before opening the PR: `git pull origin main`.
- Line endings are LF (`.gitattributes`); keep your editor on LF.

## 8. Code style and quality

- Python 3.12, formatted and linted with ruff (`ruff format`, `ruff check`). Line length 100.
- Type hints on public functions; docstrings only where behavior is not obvious.
- No business logic in views: put it in `services.py` in the app; views only validate and call it.
- Every new endpoint: serializer, permission class, OpenAPI annotation, at least one test.

## 9. Testing

- pytest + pytest-django; tests live in `<service>/tests/`.
- File names `test_<thing>.py`; fixtures in `conftest.py`.
- Calls to other services are mocked in unit tests (e.g. `respx` for httpx).
- Integration tests live in the top-level `tests/integration/` and run against Compose.
- Load tests live in `tests/load/` (k6).

## 10. Docker and Compose

- One `Dockerfile` per service, same shape in all five: slim Python base, non-root user, gunicorn, `EXPOSE 8000`.
- Image names: `ghcr.io/<owner>/<repo>/<service>:<tag>`.
- Every service has a healthcheck calling `/health/`.
- Start the stack: `docker compose up --build`. Stop and wipe data: `docker compose down -v`.

## 11. Logging

- Log to stdout in one line per event; include `service`, `level`, `message`, and `booking_id` / `user_id` where relevant.
- Never log passwords, tokens or full payment details.

## 12. Docs

- `docs/tech-stack.md` (what and why), `docs/decisions.md` (changes and reasons), `docs/project-plan.md` (tasks), `docs/progress-log.md` (one line per Friday).
- API docs come from code (drf-spectacular); exported YAMLs go to `docs/openapi/` by CI.