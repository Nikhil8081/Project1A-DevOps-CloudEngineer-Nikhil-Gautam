# Deliverable 3: Compliance Gates — RBI & PCI-DSS

**Author:** Nikhil Gautam
**Version:** 1.0 | June 2026

---

## 1. Overview

NovaPay implements **8 automated compliance gates** (minimum required: 6) embedded in Stage 7 of the CI/CD pipeline. Every gate has precise thresholds, remediation guidance, a formal exception workflow, a structured audit trail, and explicit regulatory mapping.

No code reaches production without passing all 8 gates. Exceptions require documented approval with time-bound expiry.

---

## 2. Compliance Gate Matrix

| Gate | Tool | Threshold | On Failure | Exception Process | RBI | PCI-DSS |
|------|------|-----------|------------|------------------|-----|---------|
| SAST | SonarQube | 0 Critical, ≤2 High, ≥80% coverage | Block + auto-ticket | CISO approval within 24h | 5.1 | 6.2 |
| DAST | OWASP ZAP | 0 Critical/High (OWASP Top 10) | Block | Risk acceptance + TRC | 5.1 | 6.4, 11.3 |
| Dependency | Trivy | 0 Critical CVE (CVSS ≥9.0), SBOM required | Block | 72h remediation window | 7.2 | 6.3 |
| Licence | Syft | No GPL/AGPL/SSPL dependencies | Legal review triggered | Legal team sign-off | 7.2 | — |
| K8s Policy | OPA/Kyverno | All 7 policies pass | Deployment rejected | Dual approval override | 4.3 | 6.5 |
| IaC | Checkov | No privileged containers, limits set | PR blocked | Tech Lead exemption | 4.2 | — |
| Encryption | Custom OPA | TLS 1.3+, AES-256, no weak ciphers | Block | CISO approval | 5.4 | 6.2 |
| SoD | CODEOWNERS + RBAC | Author ≠ Approver ≠ Deployer | Block | Cannot be overridden | 4.3 | 6.5 |

---

## 3. Gate Specifications

### Gate 1: SAST (Static Application Security Testing)

**Tool:** SonarQube with custom NovaPay banking quality profile
**Stage:** 3 (runs in parallel with Gate 2)

**Thresholds:**
- Critical vulnerabilities: **0** (zero tolerance)
- High vulnerabilities: **≤ 2**
- Medium vulnerabilities: **≤ 10** (warning only)
- Line coverage: **≥ 80%**
- Branch coverage: **≥ 70%**
- Technical debt ratio (new code): **≤ 5%**

**Custom Banking Rules (added to SonarQube profile):**
- PII in logs: detect `customer_id`, `account_number`, `aadhaar` in log statements
- Weak encryption: flag `MD5`, `SHA1`, `DES` usage
- SQL injection: flag string concatenation in JDBC queries
- Hardcoded secrets: flag API keys, passwords, tokens in source
- Missing audit logs: flag financial transaction methods lacking `auditLog.write()`

**Remediation Guidance:**
- Critical: Fix immediately. No merge until resolved. JIRA ticket auto-created with CVE details.
- High: Fix within 48 hours or submit exception request to CISO.
- Coverage below threshold: Add unit tests covering uncovered branches before re-submitting.

**Exception Workflow:**
1. Developer raises exception ticket in JIRA with business justification
2. CISO reviews and approves/rejects within 24 hours
3. Approved exceptions expire automatically after 72 hours
4. All exceptions logged in immutable audit trail

**RBI Section 5.1:** "Vulnerability assessment must be performed regularly"
**PCI-DSS Req 6.2:** "Bespoke and custom software are protected from attacks"

---

### Gate 2: DAST (Dynamic Application Security Testing)

**Tool:** OWASP ZAP 2.x (active scan, authenticated)
**Stage:** 6 (runs in parallel with integration tests)

**Thresholds:**
- Critical (CVSS 9.0+): **0** — pipeline blocked
- High (CVSS 7.0–8.9): **0** — pipeline blocked
- Medium: **≤ 5** (with false positive review)
- Low: No limit (logged only)

**OWASP Top 10 Coverage (all enabled):**
A01 Broken Access Control, A02 Cryptographic Failures, A03 Injection, A04 Insecure Design, A05 Security Misconfiguration, A06 Vulnerable Components, A07 Identification/Auth Failures, A08 Data Integrity Failures, A09 Logging/Monitoring Failures, A10 SSRF

**Authentication:** Test credentials retrieved from HashiCorp Vault at runtime. Never hardcoded.

**Exception Workflow:** Risk acceptance form signed by Head of Compliance + TRC approval required. Minimum 5 business days to process. Temporary waiver maximum 30 days.

**RBI Section 5.1:** Vulnerability assessment
**PCI-DSS Req 6.4:** Public-facing web application protection, 11.3 Penetration testing

---

### Gate 3: Dependency & Container Scan

**Tool:** Trivy (CVE scanning), Syft (SBOM)
**Stage:** 4 (runs in parallel with SAST)

**Thresholds:**
- CVSS ≥ 9.0 (Critical): **0** — immediate block
- CVSS 7.0–8.9 (High): **0** — block
- CVSS 4.0–6.9 (Medium): Warning, logged
- SBOM: **Required** — CycloneDX JSON format, archived with every build

**Remediation:**
- Upgrade dependency to patched version
- If no patch available: apply virtual patch or raise 72-hour exception
- Exception requires CISO sign-off and compensating control documentation

**RBI Section 7.2:** Third-party risk management
**PCI-DSS Req 6.3:** Security vulnerabilities are identified and addressed

---

### Gate 4: Licence Compliance

**Tool:** Syft + custom licence checker script

**Blocked Licences:** GPL v2/v3, AGPL, SSPL (copyleft — incompatible with proprietary banking software)
**Warning Licences:** LGPL (legal review required before approval)
**Approved Licences:** MIT, Apache 2.0, BSD 2/3-Clause, ISC, MPL 2.0

**On Failure:**
1. Pipeline blocked with list of offending packages
2. Legal team automatically notified via email
3. Developer must replace dependency or obtain legal team sign-off

**RBI Section 7.2:** Third-party risk / vendor management

---

### Gate 5: Kubernetes Policy (OPA/Kyverno)

**Tool:** OPA Rego policies enforced via Kyverno admission controller
**Stage:** 7

**7 Mandatory Policies:**
1. No privileged containers (`NOVAPAY-K8S-001`)
2. Memory limits required on all containers (`NOVAPAY-K8S-002`)
3. CPU limits required on all containers (`NOVAPAY-K8S-003`)
4. No `latest` image tag in production (`NOVAPAY-K8S-004`)
5. Containers must run as non-root (`NOVAPAY-K8S-005`)
6. Read-only root filesystem required (`NOVAPAY-K8S-006`)
7. Images must be from approved registry only (`NOVAPAY-K8S-007`)

**Exception:** Dual approval (CISO + VP Engineering) required. Maximum 7-day waiver.

**RBI Section 4.3:** Segregation of duties / access control
**PCI-DSS Req 6.5:** Change management processes

---

### Gate 6: Infrastructure-as-Code Scan (Checkov)

**Tool:** Checkov on Terraform + Helm files

**Key Checks:**
- No hardcoded credentials in Terraform
- S3 buckets must have encryption enabled
- Security groups must not allow 0.0.0.0/0 on port 22
- EKS clusters must have logging enabled
- All resources must have required tags (env, owner, cost-centre)

**On Failure:** PR is blocked. Developer must fix IaC before re-submitting.

**RBI Section 4.2:** Change management with testing and approval

---

### Gate 7: Encryption Compliance

**Tool:** Custom OPA policy (`encryption-compliance.rego`)

**Checks:**
- TLS minimum version: 1.2 (1.3 preferred)
- Blocked ciphers: RC4, DES, 3DES, MD5, SHA1, NULL, EXPORT
- Data at rest: AES-256 required, no MD5/SHA1/DES
- Certificates: valid, not expired, trusted CA

**RBI Section 5.4:** Encryption of data in transit and at rest
**PCI-DSS Req 6.2:** Bespoke software security

---

### Gate 8: Segregation of Duties

**Tool:** GitHub CODEOWNERS + ArgoCD RBAC

**Rules:**
- Developer who wrote code **cannot** approve their own PR
- PR approver **cannot** be the Release Manager who approves production deployment
- Release Manager **cannot** also be the SRE Lead who executes deployment
- Enforced automatically — no override possible

**Audit Trail:** Every approval recorded with GitHub username, timestamp, and commit SHA in immutable audit log.

**RBI Section 4.3:** Segregation of duties between development and deployment
**PCI-DSS Req 6.5:** Change management with dual approval

---

## 4. Audit Trail Schema

Every gate writes a structured JSON record to the immutable audit log (AWS S3 with object lock / Azure Blob with immutability policy):

```json
{
  "gate_id": "SAST-001",
  "pipeline_run_id": "run-4821",
  "git_sha": "a3f9c1b",
  "branch": "main",
  "author": "nikhil.gautam@novapay.in",
  "timestamp": "2026-06-10T14:32:00Z",
  "gate_type": "SAST",
  "tool": "SonarQube",
  "tool_version": "10.4",
  "result": "PASS",
  "threshold": { "critical": 0, "high": 2, "coverage": 80 },
  "actual": { "critical": 0, "high": 1, "coverage": 84.2 },
  "findings": [],
  "rbi_mapping": ["5.1", "6.1"],
  "pcidss_mapping": ["6.2"],
  "exception": false,
  "exception_approver": null,
  "exception_expiry": null
}
```

---

## 5. Resolving NovaPay's 17 RBI Non-Conformances

| Non-Conformance Category | Gate(s) That Resolve It |
|--------------------------|------------------------|
| No vulnerability scanning | SAST (Gate 1) + DAST (Gate 2) |
| No change management process | SoD (Gate 8) + IaC (Gate 6) |
| Missing audit trails | All gates write to immutable audit log |
| Weak encryption in transit | Encryption gate (Gate 7) |
| No third-party risk management | Dependency scan (Gate 3) + Licence (Gate 4) |
| No access controls on deployment | K8s Policy (Gate 5) + SoD (Gate 8) |
| Missing SBOM | Dependency scan (Gate 3) — SBOM mandatory |

---

*AI Attribution: Claude (Anthropic) assisted with formatting. All gate thresholds, regulatory mappings, and exception workflows are Nikhil Gautam's own design.*
