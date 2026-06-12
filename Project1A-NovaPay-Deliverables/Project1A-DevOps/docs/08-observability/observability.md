# Deliverable 8: Observability & DORA Metrics

**Author:** Nikhil Gautam
**Version:** 1.0 | June 2026

---

## 1. Observability Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Metrics | Prometheus | Time-series metrics collection |
| Visualisation | Grafana | Dashboards |
| Logs | Grafana Loki | Centralised log aggregation |
| Traces | Jaeger + OpenTelemetry | Distributed tracing across microservices |
| Alerting | Alertmanager | Alert routing, grouping, escalation |
| SLO Monitoring | Pyrra | SLO burn-rate tracking |

---

## 2. DORA Metrics Implementation

| DORA Metric | Definition | Elite Target | Measurement Method |
|-------------|-----------|--------------|---------------------|
| Deployment Frequency | How often code deploys to production | Multiple per day | `count(deployment_events) by (day)` in Prometheus |
| Lead Time for Changes | Commit to production deployment time | < 2 hours (NovaPay target) | Timestamp diff: `git commit timestamp` → `deployment success timestamp` |
| Change Failure Rate | % deployments causing failures | < 5% | `(rollbacks + hotfixes) / total_deployments` |
| MTTR | Time to restore after failure | < 15 minutes | `incident_resolved_at - incident_detected_at` |

### 2.1 Measurement Queries (Prometheus)

```promql
# Deployment Frequency (per day)
sum(increase(novapay_deployment_total{status="success"}[1d]))

# Lead Time for Changes (p50, hours)
histogram_quantile(0.5,
  rate(novapay_lead_time_seconds_bucket[7d])
) / 3600

# Change Failure Rate (7-day rolling)
sum(increase(novapay_deployment_total{status="rolled_back"}[7d]))
/
sum(increase(novapay_deployment_total[7d]))

# MTTR (average, 30-day)
avg(novapay_incident_duration_seconds{severity=~"SEV-1|SEV-2"}[30d]) / 60
```

---

## 3. Pipeline-Specific Metrics (15+)

### Build & Test Category
1. Build success rate (target > 95%): `sum(rate(ci_build_total{status="success"}[7d])) / sum(rate(ci_build_total[7d]))`
2. Flaky test rate: `sum(rate(test_flaky_total[7d])) / sum(rate(test_total[7d]))`
3. Top 10 flaky tests: `topk(10, sum by (test_name) (test_flaky_total))`
4. Cache hit rate (Gradle): `sum(rate(gradle_cache_hits[1d])) / sum(rate(gradle_cache_requests[1d]))`
5. Build duration p50/p99: `histogram_quantile(0.99, rate(ci_build_duration_seconds_bucket[1d]))`

### Compliance Category
6. SAST gate pass rate: `sum(rate(gate_result{gate="sast",result="pass"}[7d])) / sum(rate(gate_result{gate="sast"}[7d]))`
7. DAST gate pass rate (same pattern per gate)
8. False positive rate per scanning tool: `sum(rate(scan_false_positive[7d])) / sum(rate(scan_findings_total[7d]))`
9. Time-to-remediate Critical CVEs: `histogram_quantile(0.5, cve_remediation_duration_seconds_bucket)`
10. Compliance exception count (active): `count(compliance_exception{status="active"})`

### Deployment Category
11. Deployment duration p50/p99: `histogram_quantile(0.99, rate(deployment_duration_seconds_bucket[7d]))`
12. Rollback frequency: `sum(increase(rollback_total[30d]))`
13. Rollback trigger distribution: `sum by (category) (rollback_total)`
14. Canary promotion success rate: `sum(rate(canary_promotion{result="success"}[7d])) / sum(rate(canary_promotion[7d]))`
15. Blue-green switch duration: `histogram_quantile(0.99, switch_duration_seconds_bucket)`

---

## 4. Dashboard Designs

### Dashboard 1: Engineering (Real-Time Operations)
**Audience:** Developers, SRE on-call
**Refresh:** 10 seconds

Panels:
- Live deployment status (current version, environment, rollout progress)
- Error rate (real-time, 1-min granularity)
- p50/p95/p99 latency (last 1 hour)
- Active alerts (Alertmanager feed)
- Pod health grid (all namespaces)
- Recent deployments timeline

### Dashboard 2: Management (Weekly/Monthly Executive)
**Audience:** CTO, VP Engineering
**Refresh:** Daily

Panels:
- DORA 4 metrics trend (30-day)
- Deployment frequency trend (weekly)
- Change failure rate trend
- MTTR trend
- Availability (% uptime, monthly)
- Cost trend (if FinOps integrated)

### Dashboard 3: Regulatory (Audit-Ready Compliance)
**Audience:** Head of Compliance, RBI Auditor
**Refresh:** Daily

Panels:
- Compliance gate pass rate (all 8 gates, 90-day trend)
- Active exceptions with expiry dates
- Audit trail completeness (% of deployments with full evidence bundle)
- SBOM coverage (% of production images with valid SBOM)
- Segregation of duties violations (should always be 0)
- RBI section mapping coverage matrix

---

## 5. Alerting Strategy

| Severity | Routing | Response Time |
|----------|---------|---------------|
| Critical (Category A rollback triggers) | PagerDuty → SRE on-call (immediate page) | < 1 min |
| Warning (Category B triggers) | PagerDuty → SRE on-call (5-min escalation) | < 15 min |
| Info (gate failures, drift detected) | Slack #novapay-ops | Best effort |
| Compliance (exception expiring) | Email to Compliance team + Slack | 24h advance notice |

---

## 6. Anomaly Detection

For pipeline metrics (build duration, test duration, deployment duration), NovaPay uses **rolling 7-day baseline with 3-sigma threshold**:

```promql
# Alert if build duration exceeds 3 standard deviations from 7-day mean
(ci_build_duration_seconds - avg_over_time(ci_build_duration_seconds[7d]))
> 3 * stddev_over_time(ci_build_duration_seconds[7d])
```

This catches gradual performance degradation (e.g., growing dependency tree, slow test suite) before it becomes a blocker.

---

*AI Attribution: Claude (Anthropic) assisted with formatting. Nikhil Gautam's own design.*
