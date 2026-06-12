# Deliverable 7a: Production Deployment Runbook

**Author:** Nikhil Gautam
**Version:** 1.0 | June 2026
**Audience:** On-call SRE engineer (usable at 3 AM with minimal context)

---

## 1. Pre-Deployment Checklist (8 Items)

Before initiating any production deployment, verify ALL of the following. Each item requires evidence (screenshot, link, or log reference) attached to the deployment ticket.

| # | Check | Evidence Required |
|---|-------|-------------------|
| 1 | All 8 pipeline gates passed (SAST, DAST, dependency, licence, K8s policy, IaC, encryption, SoD) | Link to compliance-bundle.json |
| 2 | Deployment window verified — not in blackout period | Output of `check-deployment-window.py` |
| 3 | UAT sign-off from Product Owner | JIRA ticket link with approval comment |
| 4 | Dual approval obtained (Release Manager + SRE Lead) | GitHub PR approvals (2 distinct approvers) |
| 5 | On-call engineer confirmed available and briefed | Slack confirmation in #novapay-deploys |
| 6 | Database migration tested in pre-prod (if applicable) | Pre-prod migration log + DBA sign-off |
| 7 | Rollback plan reviewed | Link to rollback-spec.md, confirm rollback time target |
| 8 | Communication drafted (if customer-impacting) | Status page draft message ready |

**If ANY item fails: STOP. Do not proceed. Escalate to SRE Lead.**

---

## 2. Step-by-Step Execution Procedure

### Step 1: Confirm Pipeline State
```bash
# Check the last successful pipeline run
gh run list --workflow=ci-pipeline.yml --limit 1

# Verify all 8 stages passed
gh run view <run-id> --json jobs --jq '.jobs[].conclusion'
# Expected: all "success"
```

**Decision point:** If any stage failed → STOP. Do not proceed with manual override.

### Step 2: Verify Deployment Window
```bash
python3 pipeline/scripts/check-deployment-window.py
# Expected output: "OK — not in blackout period"
```

**Decision point:** If in blackout window → STOP. Reschedule unless this is a Category A emergency hotfix with CAB pre-approval.

### Step 3: Announce Deployment
Post in `#novapay-deploys`:
```
🚀 DEPLOYMENT STARTING
Version: v2.2.0+a3f9c1b
Type: [Blue-Green / Canary]
Approved by: [Release Manager] + [SRE Lead]
Rollback owner: [your name]
ETA: ~20 minutes
```

### Step 4: Execute Deployment

**For Blue-Green:**
```bash
# 1. Deploy to idle environment (green)
helm upgrade --install novapay-green pipeline/helm/novapay \
  --namespace novapay-prod-green \
  --values pipeline/helm/novapay/values-production.yaml \
  --set image.tag=v2.2.0+a3f9c1b

# 2. Run smoke tests against green directly (not via load balancer)
bash pipeline/scripts/smoke-tests.sh --target green --internal

# 3. If smoke tests pass, drain blue
kubectl annotate deployment novapay -n novapay-prod-blue \
  drain="true" --overwrite

# 4. Wait 5 minutes for in-flight requests to drain
sleep 300

# 5. Switch traffic (atomic)
kubectl apply -f pipeline/helm/novapay/templates/virtualservice-green.yaml
```

**For Canary:**
```bash
# 1. Deploy canary at 2% traffic
kubectl apply -f pipeline/helm/novapay/templates/virtualservice-canary-2pct.yaml

# 2. Monitor for 15 minutes (automated via Prometheus alerts)
# Auto-promotion to next phase happens via ArgoCD if all checks pass
```

### Step 5: Post-Deployment Verification
```bash
bash pipeline/scripts/smoke-tests.sh --url https://api.novapay.in \
  --expected-sha a3f9c1b --timeout 60
```

**Expected outcomes for each smoke test:**
| Test | Expected Result |
|------|-----------------|
| `/actuator/health` | HTTP 200, `{"status":"UP"}` |
| `/actuator/ready` | HTTP 200 |
| Version check | All pods report SHA `a3f9c1b` |
| Synthetic transaction | Test payment completes < 2s |
| DB connectivity | Connection pool < 70% utilised |
| Downstream ping | Payment gateway responds < 500ms |

### Step 6: 5-Minute Bake Monitoring
```bash
python3 pipeline/scripts/monitor-deployment.py \
  --duration 300 --error-rate-threshold 0.1 --latency-p99-threshold 500
```

**Decision point:** If monitoring script reports breach → automatic rollback triggers (see incident-playbook.md). If clean → proceed to Step 7.

### Step 7: Mark Deployment Stable
```bash
gh deployment-status create --state success --description "Deployed v2.2.0 successfully"
```

Post in `#novapay-deploys`:
```
✅ DEPLOYMENT COMPLETE
Version: v2.2.0+a3f9c1b
Duration: 18 minutes
Status: STABLE — 5-min bake passed
```

### Step 8: Decommission Old Environment
For blue-green: scale down blue deployment to 0 replicas (keep manifests for instant rollback within 24h).
```bash
kubectl scale deployment novapay -n novapay-prod-blue --replicas=0
```

---

## 3. Post-Deployment Verification Procedure

Run 30 minutes after deployment completes:

1. Check Grafana "Production Overview" dashboard — all panels green
2. Check error budget consumption for the day — should be < expected daily burn
3. Spot-check 3 random customer-facing API calls via synthetic monitoring
4. Confirm no new Sentry/error-tracking alerts since deployment
5. Confirm DORA metrics recorded: deployment frequency counter incremented

---

*AI Attribution: Claude (Anthropic) assisted with formatting. Nikhil Gautam's own design.*
