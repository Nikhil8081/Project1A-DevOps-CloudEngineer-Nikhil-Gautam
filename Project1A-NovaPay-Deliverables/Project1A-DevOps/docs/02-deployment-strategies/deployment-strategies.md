# Deliverable 2: Deployment Strategies — Blue-Green & Canary

**Author:** Nikhil Gautam
**Version:** 1.0 | June 2026

---

## 1. Overview

NovaPay requires zero-downtime deployments for a system handling UPI transactions 24/7. This document specifies both blue-green and canary deployment strategies, including traffic management, session handling, rollback triggers, and statistical promotion criteria.

| Change Type | Strategy | Reason |
|-------------|----------|--------|
| Major feature release | Canary | Gradual exposure, statistical validation |
| Critical security patch | Blue-Green | Instant atomic switch, fast rollback |
| Database schema migration | Blue-Green | Schema compatibility required |
| Emergency hotfix | Blue-Green | Speed + immediate rollback capability |
| Config-only change | Canary | Low risk, progressive validation |

---

## 2. Blue-Green Deployment

### 2.1 Architecture

Two identical deployments run in separate Kubernetes namespaces sharing one database:

- `novapay-prod-blue` — currently LIVE (serving 100% traffic)
- `novapay-prod-green` — IDLE or receiving new deployment
- `novapay-shared` — PostgreSQL 16, Redis 7, RabbitMQ 3.13 (shared by both)

Traffic switching is handled atomically by **Istio VirtualService** — updating weights from `blue=100, green=0` to `blue=0, green=100` in a single manifest update.

### 2.2 5-Step Traffic Switch Protocol

**Step 1 — DEPLOY (T+0):** Deploy new version to idle environment (green). Run all 6 smoke tests against green directly — no live traffic yet.

**Step 2 — DRAIN (T+5 min):** Set blue to drain mode. Stop accepting new connections. Allow in-flight HTTP requests to complete (30s timeout). Allow payment settlement jobs to complete (5 min timeout).

**Step 3 — SWITCH (T+10 min):** Update Istio VirtualService atomically: `blue=0, green=100`. DNS TTL pre-reduced to 30s. Switch takes effect in under 1 second.

**Step 4 — VERIFY (T+10 to T+20 min):** Monitor green for 10 minutes. Check: error rate < 0.1%, p99 < 200ms, zero CrashLoopBackOff. Run end-to-end synthetic UPI transaction.

**Step 5 — STABILISE or ROLLBACK (T+20 min):** All checks pass → mark stable, decommission blue. Any failure → switch back (blue=100, green=0) in under 60 seconds.

### 2.3 Istio VirtualService

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: novapay-vs
  namespace: novapay-shared
spec:
  hosts:
    - api.novapay.in
  http:
    - route:
        - destination:
            host: novapay-service
            subset: green
            port:
              number: 8080
          weight: 100
        - destination:
            host: novapay-service
            subset: blue
            port:
              number: 8080
          weight: 0
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: gateway-error,connect-failure,retriable-4xx
```

### 2.4 Session Management

Sessions stored in **Redis 7 cluster** (3 nodes) — external to both blue and green. During switch: active sessions remain valid, JWT tokens are stateless, payment state machines use distributed Redis locks that survive the switch.

### 2.5 Long-Running Transaction Handling

- Graceful shutdown timeout: **5 minutes** for payment settlement jobs
- In-flight jobs at switch time: complete on blue environment
- New jobs: routed to green immediately after switch
- RabbitMQ consumers: idempotent — safe to process on either colour

---

## 3. Canary Deployment

### 3.1 Canary Progression

| Phase | Traffic % | Duration | Success Criteria | Auto Action |
|-------|-----------|----------|-----------------|-------------|
| Canary | 2% | 15 min | Error rate < 0.1%, p99 < 200ms | Proceed or auto-rollback |
| Early Adopter | 10% | 30 min | Error rate < 0.05%, no critical alerts | Proceed or auto-rollback |
| Expansion | 25% | 60 min | All SLOs met, no degradation vs baseline | Proceed to full rollout |
| Full Rollout | 100% | 24 hr bake | Complete SLO compliance for 24 hours | Mark deployment stable |

### 3.2 Statistical Promotion Criteria

All three tests must pass before each phase promotion:

**Latency — Welch's t-test:** H0: canary p99 == baseline p99. Reject (block) if p-value < 0.05 AND canary > baseline. Baseline = rolling 7-day production average. 95% confidence interval.

**Error Rate — Chi-squared test:** Compares error counts proportionally. Block if p-value < 0.05 AND canary error rate > baseline error rate.

**Composite Score:** `score = (0.4 × latency) + (0.4 × errors) + (0.2 × resources)`. Promote only if score ≥ 0.85.

### 3.3 Canary Prometheus Alerts

```yaml
- alert: CanaryErrorRateTooHigh
  expr: |
    (rate(http_requests_total{version="canary",status=~"5.."}[5m])
    / rate(http_requests_total{version="canary"}[5m])) > 0.001
  for: 2m
  labels:
    severity: critical
    action: auto_rollback

- alert: CanaryLatencyTooHigh
  expr: |
    histogram_quantile(0.99,
      rate(http_request_duration_seconds_bucket{version="canary"}[5m])
    ) > 0.200
  for: 2m
  labels:
    severity: critical
    action: auto_rollback
```

---

## 4. Deployment Blackout Calendar

Pipeline blocks deployments during:

| Window | Schedule | Reason |
|--------|----------|--------|
| Salary Days | 1st, 7th, 15th of month 08:00–14:00 IST | Peak UPI volume (3–5x normal) |
| Month-End | 28th–31st 18:00–23:59 IST | Settlement runs |
| Major Festivals | Diwali, Eid, Christmas, Holi (full day) | Traffic spikes |
| Peak Hours | Daily 10:00–12:00 and 17:00–20:00 IST | UPI peak |
| RBI Windows | As published by RBI/NPCI | Regulatory |

Enforced by: `pipeline/scripts/check-deployment-window.py` — Stage 8, Step 1.

---

## 5. Version Consistency Check (Knight Capital Lesson)

After every deployment, verify all pods run identical image SHA:

```bash
EXPECTED_SHA="${GIT_SHA}"
for POD in $(kubectl get pods -n novapay-prod -l app=novapay -o name); do
  ACTUAL=$(kubectl exec ${POD} -- curl -s localhost:8080/actuator/info \
    | jq -r '.git.commit.id.abbrev')
  if [ "$ACTUAL" != "$EXPECTED_SHA" ]; then
    echo "VERSION MISMATCH: ${POD} running ${ACTUAL}, expected ${EXPECTED_SHA}"
    kubectl rollout undo deployment/novapay -n novapay-prod
    exit 1
  fi
done
```

This check directly addresses the Knight Capital disaster root cause — where one server ran different code, causing $440M in losses in 45 minutes.

---

*AI Attribution: Claude (Anthropic) assisted with formatting. All strategies and thresholds are Nikhil Gautam's own design.*
