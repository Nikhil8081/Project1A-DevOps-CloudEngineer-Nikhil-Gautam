# Deliverable 5: Environment Promotion Workflow

**Author:** Nikhil Gautam
**Version:** 1.0 | June 2026

---

## 1. Four-Environment Model

NovaPay uses a strict four-environment promotion pipeline. The **same container image** moves through all environments — only configuration changes.

| Environment | Purpose | Data Profile | Access Control | Deploy Trigger |
|-------------|---------|-------------|----------------|----------------|
| Development | Feature development, unit testing | Synthetic/mock data only | All developers | Automatic on PR merge |
| Staging | Integration tests, DAST, performance | Anonymised production-like data | Dev team + QA | Automatic after dev gates pass |
| Pre-Production | UAT, compliance verification, regulatory | Masked production data subset | QA + Compliance + DBA | Manual approval (Tech Lead) |
| Production | Live customer-facing environment | Real production data | SRE + Release Manager only | Dual approval (RM + SRE Lead) |

**Core Principle:** Same artefact, different config. One container image, four environments.

---

## 2. Promotion Criteria

### Dev → Staging (Automated)
- [ ] All unit tests pass (100% — zero failures tolerated)
- [ ] Line coverage ≥ 80%, branch coverage ≥ 70%
- [ ] SAST: 0 Critical, ≤ 2 High findings
- [ ] Container image signed and pushed to Artifactory with SemVer tag
- [ ] No `latest` tag used
- **Trigger:** Automatic — no human approval if all gates pass

### Staging → Pre-Production (Tech Lead Approval)
- [ ] All integration tests pass including Pact contract tests
- [ ] DAST: 0 Critical/High findings from OWASP Top 10
- [ ] Performance test: p99 latency < 500ms under 2x expected load
- [ ] Dependency scan: 0 Critical CVEs, SBOM archived
- [ ] Licence compliance: no GPL/AGPL/SSPL detected
- **Gate:** Tech Lead manual approval in GitHub

### Pre-Production → Production (Dual Approval)
- [ ] UAT sign-off from Product Owner (written approval in JIRA)
- [ ] All 8 compliance gates passed (RBI + PCI-DSS verified)
- [ ] Database migration tested with production-scale data in pre-prod
- [ ] Deployment runbook reviewed and signed off by SRE Lead
- [ ] CAB approval OR pre-approved change category confirmed
- [ ] Deployment window verified (not in blackout period)
- [ ] On-call engineer confirmed available and briefed
- **Gate:** Dual approval — Release Manager AND SRE Lead (enforces SoD)

---

## 3. Configuration Management

### 3.1 Hierarchy
```
values.yaml           (base — shared across all environments)
  └── values-dev.yaml          (dev overrides)
  └── values-staging.yaml      (staging overrides)
  └── values-preprod.yaml      (pre-prod overrides)
  └── values-production.yaml   (prod overrides — minimal, security-hardened)
```

### 3.2 Secrets Management
- **Tool:** HashiCorp Vault
- Database passwords: 90-day automatic rotation
- API keys: 30-day automatic rotation
- No plaintext secrets in Git, Helm values, or Kubernetes manifests — ever
- Vault dynamic secrets for short-lived database credentials per service

### 3.3 Feature Flags
New features deploy to ALL environments but toggled off in production until validated:
```
Feature flag progression: 1% → 10% → 50% → 100%
Mirrors canary deployment pattern
Tool: LaunchDarkly-compatible flag service
```

### 3.4 Configuration Drift Detection
ArgoCD compares Git-declared state vs live cluster state every 3 minutes. Any drift triggers Slack alert to #novapay-ops and optional auto-sync.

---

## 4. Approval Workflow (RBAC)

| Role | Dev | Staging | Pre-Prod | Production |
|------|-----|---------|---------|-----------|
| Developer | Deploy | View | View | No access |
| QA Engineer | Deploy | Deploy | View | No access |
| Tech Lead | Deploy | Deploy | Approve | View |
| Release Manager | — | — | Deploy | Approve |
| SRE Lead | — | — | Deploy | Approve + Execute |
| DBA | — | — | DB approval | DB approval |

SoD enforcement: a developer cannot approve their own promotion at any stage.

---

*AI Attribution: Claude (Anthropic) assisted with formatting. Nikhil Gautam's own design.*
