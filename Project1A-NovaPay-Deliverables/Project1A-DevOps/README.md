# Project1A-DevOps&CloudEngineer — NovaPay Zero-Downtime CI/CD Pipeline

**Candidate:** [Your Name]
**Track:** DevOps & Cloud Engineer
**Organisation:** Zetheta Algorithms Private Limited
**Timeline:** 15 Days | June 6 – June 20, 2026

---

## Executive Summary

NovaPay Digital Bank currently deploys via manual SSH with a 4.5-hour MTTR, fortnightly release cycles, zero automated compliance scanning, and 17 open RBI audit non-conformances. This project delivers a production-grade, zero-downtime CI/CD pipeline architecture that reduces commit-to-production time to under 2 hours, achieves five-nines (99.999%) availability, and satisfies all RBI Master Direction and PCI-DSS v4.0 requirements through automated compliance gates embedded directly in the pipeline.

---

## Architecture Overview

```
Git Push → Source Control → Build & Test → SAST → Dependency/Container Scan
        → Integration & Contract Tests → DAST → Policy & Compliance Gates
        → Blue-Green / Canary Deployment → Post-Deploy Verification
```

---

## Navigation Guide

| # | Deliverable | Location |
|---|-------------|----------|
| 1 | 8-Stage Pipeline Architecture | [docs/01-pipeline-architecture/](docs/01-pipeline-architecture/architecture.md) |
| 2 | Blue-Green + Canary Deployment | [docs/02-deployment-strategies/](docs/02-deployment-strategies/deployment-strategies.md) |
| 3 | Compliance Gates (RBI + PCI-DSS) | [docs/03-compliance-gates/](docs/03-compliance-gates/compliance-gates.md) |
| 4 | Zero-Downtime DB Migration | [docs/04-database-migration/](docs/04-database-migration/db-migration.md) |
| 5 | Environment Promotion Workflow | [docs/05-environment-promotion/](docs/05-environment-promotion/env-promotion.md) |
| 6 | Automated Rollback Specification | [docs/06-rollback-specification/](docs/06-rollback-specification/rollback-spec.md) |
| 7 | Deployment Runbook + Incident Playbook | [runbooks/](runbooks/deployment-runbook.md) |
| 8 | Observability & DORA Metrics | [docs/08-observability/](docs/08-observability/observability.md) |

---

## Pipeline Configuration Files

| File | Purpose |
|------|---------|
| [pipeline/.github/workflows/ci-pipeline.yml](pipeline/.github/workflows/ci-pipeline.yml) | Main CI pipeline (8 stages) |
| [pipeline/.github/workflows/cd-deploy.yml](pipeline/.github/workflows/cd-deploy.yml) | CD deployment workflow |
| [pipeline/.github/workflows/rollback.yml](pipeline/.github/workflows/rollback.yml) | Automated rollback workflow |
| [pipeline/policies/](pipeline/policies/) | OPA Rego + Kyverno policies |
| [pipeline/helm/](pipeline/helm/) | Helm charts for NovaPay |
| [pipeline/terraform/](pipeline/terraform/) | Terraform IaC modules |

---

## Tools Used

| Category | Tools |
|----------|-------|
| CI/CD | GitHub Actions, ArgoCD 2.x |
| SAST | SonarQube / SonarCloud |
| DAST | OWASP ZAP |
| Container Scan | Trivy |
| Policy | OPA / Kyverno |
| Image Signing | Cosign |
| Service Mesh | Istio |
| Monitoring | Prometheus + Grafana + Loki |
| Tracing | OpenTelemetry + Jaeger |
| Secrets | HashiCorp Vault |
| IaC | Terraform 1.7+ |
| DB Migration | pgroll / Flyway |

---

## Deliberate Errors Found

See [ERRATA.md](ERRATA.md) for the 3 deliberate technical errors identified and corrected.

---

## Key Metrics Targeted

| Metric | Current | Target |
|--------|---------|--------|
| Deployment Frequency | Once per 2 weeks | Multiple per day |
| Lead Time (Commit → Prod) | ~3 days | < 2 hours |
| MTTR | 4.5 hours | < 15 minutes |
| Change Failure Rate | ~40% | < 5% |
| Availability | ~99.5% | 99.999% (five-nines) |

---

