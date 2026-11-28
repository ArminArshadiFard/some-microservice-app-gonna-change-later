# Event Ticketing Platform

A microservice-based event ticketing system: users browse events, hold seats, pay, and get a confirmation. Built for the Microservice Architecture practical assignment.

## Services

| Service | Port | Role |
|---|---|---|
| user-service | 8001 | Register, login (JWT), profile |
| event-service | 8002 | Events, ticket types, seat availability |
| booking-service | 8003 | Bookings, seat holds, status tracking |
| payment-service | 8004 | Simulated payments (with failure simulation) |
| notification-service | 8005 | Email notifications via RabbitMQ + Celery |

Infrastructure: PostgreSQL (one server, one database per service), RabbitMQ.

## Run locally

Requirements: Docker Desktop with Compose.

```
git clone <repo-url>
cd <repo-folder>
cp .env.example .env        # PowerShell: Copy-Item .env.example .env
docker compose up --build
```

Check that everything is up:

```
docker compose ps
```

Useful URLs:

- RabbitMQ management: http://localhost:15672 (user `app`, password `app_dev_pw`)
- Service health: http://localhost:8001/health/ (8002 to 8005 for the others)
- Swagger docs: http://localhost:8001/api/users/docs/ (and `/api/events/docs/`, ...)

Stop everything: `docker compose down`
Stop and wipe all data: `docker compose down -v`

## Documentation

- [Tech stack](docs/tech-stack.md)
- [Decisions](docs/decisions.md)
- [Project plan](docs/project-plan.md)
- [Conventions](docs/conventions.md)

## Team workflow

Branch from `main` as `feat/<service>-<topic>`, open a PR (under 400 lines), get one approval, and wait for CI to pass. Full rules are in `docs/conventions.md`.