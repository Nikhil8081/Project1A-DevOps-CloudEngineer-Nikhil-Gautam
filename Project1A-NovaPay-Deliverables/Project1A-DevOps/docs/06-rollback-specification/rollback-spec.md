# Deliverable 6: Automated Rollback Specification

**Author:** Nikhil Gautam
**Version:** 1.0 | June 2026

---

## 1. Overview

Automated rollback is the safety net that makes rapid deployment possible. NovaPay implements three rollback categories based on urgency and automation level.

**Rollback Time Targets:**
- Category A (immediate): < 60 seconds
- Category B (escalated): < 15 minutes
- Category C (manual): Human-driven, no SLA

---

## 2. Rollback Trigger Categories

### Category A — Immediate (< 60 seconds, zero human intervention)

These triggers cause **instant traffic re-routing** without any human decision:

| Trigger | Threshold | Detection Method |
|---------|-----------|-----------------|
| HTTP 5xx error rate | > 5% for 60 seconds | Prometheus `rate(http_requests_total{status=~"5.."}[1m])` |
| Health check failure | 3 consecutive failures | Kubernetes liveness probe |
| CrashLoopBackOff | Any occurrence | Kubernetes pod watch |
| OOM Kill | Any occurrence | Kubernetes event watch |
| DB connection pool exhaustion | > 90% pool used for 60s | pgBouncer metrics |
| Readiness probe failure | Pod not ready for 60s | Kubernetes readiness probe |

**Automatic action:** Istio VirtualService weight flipped back to previous version in < 5 seconds.

### Category B — Escalated (< 15 minutes, alert on-call, auto-rollback if no response)

| Trigger | Threshold | Escalation |
|---------|-----------|-----------|
| p99 latency | > 2x baseline for 5 min | Page on-call SRE via PagerDuty |
| Error budget burn | > 10x normal rate for 10 min | Page SRE Lead |
| Transaction success rate | Drops > 2% below baseline | Page SRE + VP Engineering |
| CPU saturation | > 90% sustained 5 min | Page SRE on-call |
| Memory saturation | > 85% sustained 5 min | Page SRE on-call |

**Escalation flow:** Alert fires → PagerDuty pages on-call → 5-minute response window → If no acknowledgement, auto-rollback executes.

### Category C — Manual Decision

| Signal | Action |
|--------|--------|
| Gradual error rate increase below thresholds | SRE reviews, decides |
| Customer support spike reports | SRE reviews correlation |
| Retroactive compliance failure discovery | Compliance team + SRE |
| Downstream dependency correlation | Investigate before rollback |

---

## 3. Rollback Execution Workflow (8 Steps)

```
Step 1 — DETECT (T+0):
  Prometheus alert fires OR health check fails
  Alert written to audit log with timestamp

Step 2 — CORRELATE (T+15s):
  Check: is this deployment-related or infrastructure issue?
  Compare: deployment timestamp vs alert timestamp
  If deployment within last 2 hours: assume deployment-related

Step 3 — FREEZE (T+30s):
  Block all new deployments (set pipeline-lock flag)
  Notify #novapay-incidents Slack channel

Step 4 — ROLLBACK (T+45s for Cat A / T+5m for Cat B):
  Blue-Green: flip Istio VirtualService (< 5 seconds)
  Canary: set canary weight to 0% (< 5 seconds)
  Rolling: kubectl rollout undo deployment/novapay

Step 5 — VERIFY (T+60s to T+5m):
  Run all 6 smoke tests against rolled-back version
  Confirm error rate returned below 1%
  Confirm p99 latency returned to baseline

Step 6 — NOTIFY (T+5m):
  Internal: Slack #novapay-incidents with impact summary
  External: Status page updated (if user-facing impact)
  Regulatory: RBI notification if outage > 30 minutes (per RBI mandate)

Step 7 — INCIDENT (T+5m):
  Create SEV incident ticket
  Start 30-minute update cycle for SEV-1/SEV-2

Step 8 — POST-MORTEM (T+24h):
  Blameless post-mortem within 24 hours
  Root cause analysis
  Action items with owners and deadlines
  Update pipeline to prevent recurrence
```

---

## 4. Prometheus Alerting Rules

```yaml
groups:
  - name: novapay.rollback.triggers
    rules:
      - alert: HighErrorRateCategoryA
        expr: |
          rate(http_requests_total{
            namespace="novapay-prod",
            status=~"5.."
          }[1m]) /
          rate(http_requests_total{namespace="novapay-prod"}[1m]) > 0.05
        for: 1m
        labels:
          severity: critical
          category: A
          action: auto_rollback
        annotations:
          summary: "Error rate {{ $value | humanizePercentage }} > 5% — triggering automatic rollback"

      - alert: HighLatencyCategoryB
        expr: |
          histogram_quantile(0.99,
            rate(http_request_duration_seconds_bucket{
              namespace="novapay-prod"
            }[5m])
          ) > 2 * scalar(
            histogram_quantile(0.99,
              rate(http_request_duration_seconds_bucket{
                namespace="novapay-prod"
              }[7d])
            )
          )
        for: 5m
        labels:
          severity: warning
          category: B
          action: page_oncall

      - alert: ErrorBudgetBurnRate
        expr: |
          (1 - (
            rate(http_requests_total{status!~"5.."}[1h]) /
            rate(http_requests_total[1h])
          )) > 10 * (1 - 0.99999)
        for: 10m
        labels:
          severity: critical
          category: B
          action: page_sre_lead
```

---

## 5. Post-Rollback Verification

After every rollback, confirm system has fully recovered:

1. All 6 smoke tests pass
2. Error rate < 0.5% for 10 consecutive minutes
3. p99 latency within 15% of 7-day baseline
4. Zero CrashLoopBackOff events for 5 minutes
5. Database connection pool healthy (< 70% utilised)
6. All downstream payment gateway health checks green
7. Version consistency verified across all pods

Only after all 7 checks pass: lift pipeline-lock flag and allow new deployments.

---

*AI Attribution: Claude (Anthropic) assisted with formatting. Nikhil Gautam's own design.*
