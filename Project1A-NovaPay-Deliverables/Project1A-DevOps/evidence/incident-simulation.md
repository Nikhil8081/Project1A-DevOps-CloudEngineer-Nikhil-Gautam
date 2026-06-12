# Incident Simulation Response — Friday 5 PM Production Incident

**Author:** Nikhil Gautam
**Scenario Source:** Part B, Section B5 of project brief

---

## Scenario Recap

It is Friday at 5:07 PM IST. A developer pushed a "critical hotfix" that bypassed staging. The canary deployment has been running for 8 minutes when these alerts fire simultaneously:

- ALERT: HTTP 500 error rate at 12% (threshold: 5%) — Severity: CRITICAL
- ALERT: PostgreSQL connection pool exhaustion on primary — Severity: HIGH
- ALERT: Downstream payment gateway timeout rate at 35% — Severity: CRITICAL

---

## Incident Timeline

| Time | Event / Action | Decision |
|------|----------------|----------|
| T+0 (17:15:00) | Three alerts fire simultaneously in Alertmanager | Auto-classified as SEV-1 (multiple critical alerts, payment-impacting) |
| T+0:05 | PagerDuty pages on-call SRE + Incident Commander | Per SEV-1 escalation: CTO + CISO + VP Eng notified |
| T+0:15 | HTTP 500 rate (12%) breaches Category A rollback threshold (>5% for 60s) | **Automatic rollback triggers** — Istio canary weight set to 0% |
| T+0:20 | On-call SRE acknowledges page, joins #novapay-incidents | Posts initial acknowledgement using template |
| T+0:45 | Canary weight confirmed at 0% — all traffic back on stable version | Verify: error rate beginning to drop |
| T+1:30 | Error rate drops to 6% (still elevated — stable version also affected) | **Root cause hypothesis:** DB connection pool exhaustion is NOT canary-specific |
| T+2:00 | Investigate PostgreSQL connection pool — pgBouncer shows 98% pool utilisation | Connection pool exhaustion predates the canary deploy — pre-existing condition exacerbated |
| T+2:30 | Internal Slack update #1 posted (per SEV-1: every 30 min) | "Investigating — rollback complete, pool exhaustion ongoing" |
| T+3:00 | Restart pgBouncer with increased pool size (emergency mitigation) | Connection pool drops to 60% utilisation |
| T+4:00 | Payment gateway timeout rate drops from 35% to 8% | Correlates with connection pool recovery — gateway calls were blocked behind DB queries |
| T+5:00 | Error rate drops to 0.3% — below 1% recovery threshold | All 6 smoke tests pass |
| T+6:00 | External status page updated: "Resolved" | Customer-facing notice posted |
| T+6:00 | Incident marked RESOLVED. Total duration: 6 minutes (within SEV-1 target of immediate mitigation) | Post-mortem scheduled for next business day |
| T+24:00 | Post-mortem conducted | Root cause + 5 action items identified |

---

## Root Cause Analysis

**Primary root cause:** The "critical hotfix" bypassed staging — meaning it skipped:
- Stage 5 (Integration & Contract Testing) — would have caught connection pool sizing issue under load
- Stage 6 (DAST) — not directly relevant here but also skipped
- The deployment blackout calendar check — **Friday 5 PM is within the daily peak window (17:00–20:00 IST)**

**Secondary contributing factor:** The new code introduced additional database queries per request without corresponding connection pool size adjustment, which under Friday evening peak UPI traffic (5–8 PM is a defined peak window) exhausted the connection pool.

---

## Which Pipeline Gate Was Missing / Bypassed?

| Gate | Status | Would It Have Caught This? |
|------|--------|---------------------------|
| Stage 1: Source Control | Bypassed (hotfix path used "skip staging" — **policy violation**) | The brief itself states hotfixes must NOT bypass security/compliance gates — this hotfix bypassed an additional gate it shouldn't have |
| Stage 5: Integration & Contract Testing | **SKIPPED** | **YES** — performance baseline test (p99 latency under 2x load) in Stage 5 would have shown connection pool exhaustion under load |
| Deployment Blackout Calendar | **NOT CHECKED** | **YES** — 17:07 IST falls within the 17:00–20:00 IST peak window. Pipeline should have blocked this deployment entirely |
| Category A Rollback | Worked correctly | Rollback executed automatically within 15 seconds of threshold breach — this part of the design worked |

---

## Did Our Pipeline Design Prevent This?

**Partially.** The Category A automated rollback (Section 6, Deliverable 6) worked exactly as designed — it triggered within 15 seconds and removed canary traffic. However, **two design gaps allowed this incident to occur in the first place:**

1. **Hotfix path gap:** Our pipeline design states hotfixes get an "expedited but not bypassed" pipeline (per Section A2.3). This incident shows a hotfix bypassed Stage 5 entirely — this is a **process violation**, not a pipeline design flaw, but it reveals the pipeline needs a **hard technical control** (not just policy) preventing hotfix branches from skipping Stage 5.

2. **Blackout calendar gap:** Our blackout calendar (Deliverable 2, Section 4) lists "Peak Hours: 10:00–12:00 and 17:00–20:00 IST" as a blackout window. The `check-deployment-window.py` script should have blocked this deployment at 17:07 IST. This incident reveals either the script was bypassed for the hotfix path, or the hotfix path doesn't call this script at all.

---

## Pipeline Improvements (Action Items from Post-Mortem)

| Action | Owner | Deadline | Priority |
|--------|-------|----------|----------|
| Make Stage 5 (Integration Tests) **mandatory and non-skippable** even for hotfix branches — reduce timeout from 12 min to 5 min for hotfix path instead of skipping entirely | Platform Team | 1 week | P0 |
| Add blackout calendar check to the hotfix pipeline path (`hotfix/*` branches) — currently only checked on `main`/`release/*` | Platform Team | 3 days | P0 |
| Add connection pool utilisation to Category A rollback triggers (currently only checked as a standalone alert, not tied to auto-rollback) | SRE Team | 1 week | P1 |
| Add a pre-deployment check: "will this change increase DB queries per request?" via static analysis diff | SAST Team | 2 weeks | P2 |
| Conduct tabletop exercise quarterly using this exact scenario to validate runbook currency | SRE Lead | Ongoing (quarterly) | P2 |

---

*AI Attribution: Claude (Anthropic) assisted with formatting and timeline structuring. Root cause analysis and action items are Nikhil Gautam's own analysis.*
