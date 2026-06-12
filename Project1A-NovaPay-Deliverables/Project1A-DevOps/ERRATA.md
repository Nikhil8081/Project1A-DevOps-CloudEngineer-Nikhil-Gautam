# ERRATA.md — Deliberate Technical Errors

This document identifies and corrects the three deliberate technical errors embedded in the project brief as part of the critical thinking assessment.

---

## Error 1 — Part A: DORA Metrics Lead Time Target (Section A5)

**Location:** Section A5, DORA Metrics table, "Lead Time for Changes" row

**Error in document:**
The DORA table lists the elite target for Lead Time for Changes as `< 1 hour`.

**Why this is incorrect:**
The project task statement (page 1) explicitly requires reducing "commit-to-production time to under two hours." More importantly, the DORA 2023/2024 State of DevOps Report defines the elite performer benchmark for Lead Time as **less than one hour** — however the document internally contradicts itself: the Deployment Velocity Audit Scoring table (Appendix) awards maximum points for `< 2 hours`, not `< 1 hour`, suggesting the intended target for NovaPay's context is **< 2 hours**. An elite target of < 1 hour is technically correct per DORA research but inconsistent with the project's stated goal of "under two hours."

**Correction:**
For NovaPay's context, the Lead Time target should be stated as `< 2 hours` in alignment with the project task. The DORA global elite benchmark of `< 1 hour` is aspirational and appropriate as a stretch goal.

---

## Error 2 — Part C: Cloudflare Outage Duration (Case Study 3)

**Location:** Part C, Case Study 3: Cloudflare Global Outage (Worldwide, July 2019)

**Error in document:**
The document's NOTE explicitly states: *"The original version of this document states the outage lasted 21 minutes. The actual duration was 27 minutes."*

This is the deliberate error — the original (incorrect) figure was **21 minutes**.

**Correction:**
The Cloudflare global outage on July 2, 2019 lasted **27 minutes** (approximately 17:47 UTC to 18:14 UTC). This is confirmed by Cloudflare's own post-mortem blog post published July 12, 2019.

---

## Error 3 — Part D: Minimum Commit Count Requirement (Section D, Day 15)

**Location:** Part D, Section D3, Day 15: Final Submission

**Error in document:**
The document states: *"Verify minimum 30 commits spread across all 15 days."*

**Why this is incorrect:**
A 15-day project with one major deliverable per day (Days 4–10), plus setup, integration, polish, and submission phases, should have a minimum of **2 commits per day** as instructed throughout the daily breakdown (each day lists 2 explicit `Commit:` instructions). That gives a minimum of **30 commits**, which is mathematically consistent. However, the document also describes Day 1 alone as having 1 commit, Day 2 as having 2 commits, Days 3–10 as having 2 commits each — totalling a **minimum of 19 commits** just from named commits, not 30. The "30 commit" figure appears inflated relative to the actual named commits in the daily plan, creating an inconsistency. Students following the daily plan exactly would fall short of 30 named commits without additional incremental commits.

**Correction:**
The minimum commit count of 30 is achievable only if students make additional incremental commits beyond the named ones (e.g., diagram updates, config fixes, cross-reference additions). The daily plan should explicitly state "minimum 2 commits per day = 30 commits over 15 days" to avoid confusion.

---

*Documented by: [Your Name]*
*Date: [Date]*
