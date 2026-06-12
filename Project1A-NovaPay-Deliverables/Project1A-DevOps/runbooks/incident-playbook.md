# Deliverable 7b: Incident Response Playbook

**Author:** Nikhil Gautam
**Version:** 1.0 | June 2026

---

## 1. Severity Classification

| Severity | Definition | Response Time | Escalation Path |
|----------|-----------|---------------|-----------------|
| SEV-1 | Complete service outage or data integrity risk | < 5 minutes | CTO + CISO + VP Eng |
| SEV-2 | Major feature degradation affecting > 10% users | < 15 minutes | VP Eng + SRE Lead |
| SEV-3 | Minor degradation, workaround exists | < 1 hour | SRE on-call + Tech Lead |
| SEV-4 | Cosmetic issue, no user impact | Next business day | Assigned engineer |

---

## 2. 7-Step Incident Response Workflow

```
Step 1: DETECT
  Automated alert fires (Prometheus/Grafana) OR manual report
  → Auto-creates incident ticket with timestamp

Step 2: TRIAGE & CLASSIFY (< 2 min)
  On-call engineer assesses severity using table above
  → Assigns SEV level, starts incident timer

Step 3: ACKNOWLEDGE & COMMUNICATE (< 5 min for SEV-1/2)
  → Post in #novapay-incidents (internal)
  → Update status page if customer-facing (external)
  → Page escalation path per severity table

Step 4: MITIGATE
  → Execute rollback if deployment-related (Category A/B per rollback-spec.md)
  → Apply immediate mitigation (circuit breaker, feature flag off, scale up)

Step 5: INVESTIGATE ROOT CAUSE (parallel with mitigation)
  → Pull logs (Loki), traces (Jaeger), metrics (Prometheus) for incident window
  → Identify: which pipeline gate, if any, should have caught this?

Step 6: RESOLVE & VERIFY
  → Confirm metrics returned to baseline
  → Run full smoke test suite
  → Update status page: resolved

Step 7: POST-MORTEM (within 24 hours)
  → Blameless retrospective
  → Document timeline, root cause, action items with owners
```

---

## 3. Communication Templates

### Initial Acknowledgement (Internal Slack — #novapay-incidents)
```
🔴 SEV-[X] INCIDENT DECLARED
Time: [HH:MM IST]
Summary: [one-line description]
Impact: [% users affected / services impacted]
Incident Commander: [name]
Status: Investigating
Next update: in 30 min (SEV-1) / 1 hour (SEV-2)
```

### Initial Acknowledgement (External Status Page)
```
We are currently investigating reports of [issue description].
Some users may experience [specific symptom].
We will provide an update within 30 minutes.
```

### Regular Update (every 30 min for SEV-1, hourly for SEV-2)
```
UPDATE [HH:MM IST] — SEV-[X]
Status: [Investigating / Mitigating / Monitoring]
Actions taken: [bulleted list]
Current impact: [updated impact assessment]
Next update: [time]
```

### Resolution Notification
```
✅ RESOLVED [HH:MM IST] — SEV-[X]
Issue: [description]
Duration: [start] to [end] ([X] minutes)
Root cause: [brief — full RCA in post-mortem]
Impact: [final impact summary]
Post-mortem: scheduled for [date/time], doc link to follow
```

### Post-Mortem Report Template
```markdown
# Post-Mortem: [Incident Title]

**Date:** [date]
**Severity:** SEV-[X]
**Duration:** [start] – [end] ([X] minutes)
**Author:** [name]

## Timeline
| Time | Event |
|------|-------|
| T+0 | ... |

## Root Cause
[detailed analysis]

## Impact
- Users affected: [number/percentage]
- Transactions affected: [number]
- Revenue impact: [if applicable]
- RBI notification required: [Yes/No — if outage > 30 min]

## What Went Well
- [item]

## What Went Wrong
- [item]

## Action Items
| Action | Owner | Deadline | Status |
|--------|-------|----------|--------|
| ... | ... | ... | Open |

## Pipeline Gate Analysis
Which gate should have caught this? [analysis]
What gate is now being added/modified to prevent recurrence?
```

---

## 4. Regulatory Notification (RBI)

If an incident causes a customer-facing outage exceeding **30 minutes**, NovaPay must notify RBI per the Master Direction on IT Governance, Section 6.3 (Incident management and business continuity).

**Notification workflow:**
1. Head of Compliance notified automatically at T+25 minutes if incident is ongoing
2. Draft RBI notification prepared using standard template
3. Submitted within 6 hours of incident resolution (per RBI timelines)
4. Includes: incident timeline, root cause, customer impact, remediation steps

---

*AI Attribution: Claude (Anthropic) assisted with formatting. Nikhil Gautam's own design.*
