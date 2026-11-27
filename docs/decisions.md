# Decision Log

## D1 — REST over gRPC
Django's REST ecosystem (DRF + drf-spectacular) gives working OpenAPI docs for free.
gRPC would need extra tooling for marginal benefit at this scale.

## D2 — tenacity + pybreaker instead of Resilience4j
Resilience4j is JVM-only. tenacity covers retries/backoff; pybreaker covers circuit
breaking with a comparable state machine (closed → open → half-open).

## D3 — Single Postgres instance, five databases (dev)
Keeps docker-compose light; services still own their DB. Production would use
per-service instances or schemas. Noted as a trade-off.