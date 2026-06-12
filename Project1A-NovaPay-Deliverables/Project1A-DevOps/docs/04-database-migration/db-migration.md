# Deliverable 4: Zero-Downtime Database Migration Strategy

**Author:** Nikhil Gautam
**Version:** 1.0 | June 2026

---

## 1. Overview

Database migrations are the highest-risk component of any banking deployment. A failed migration on a 100-million-row financial table can cause data corruption, regulatory violations, and extended downtime. NovaPay uses the **expand-contract pattern** — the only safe approach for zero-downtime migrations in production banking systems.

**Tools:** pgroll (PostgreSQL online schema migration), Flyway (migration versioning), pg_partman (partition management for large tables)

---

## 2. The Expand-Contract Pattern

### 2.1 Three-Phase Overview

```
PHASE 1: EXPAND          PHASE 2: MIGRATE         PHASE 3: CONTRACT
─────────────────        ────────────────         ─────────────────
Add new columns/         Backfill data from       Remove old columns
tables alongside         old schema to new.       after ALL services
existing ones.           Idempotent batches.      have fully migrated.
Both App V(N-1)          Both versions still      IRREVERSIBLE — needs
and V(N) work.           work. Retry-safe.        separate approval gate.
✅ REVERSIBLE            ✅ RETRY-SAFE             ⚠️ FORWARD-ONLY
```

### 2.2 Phase 1 — EXPAND

**What happens:** New columns/tables are added alongside existing ones. Old columns are not touched. Both the current app version V(N-1) and new version V(N) can operate against this schema simultaneously.

**Example — Adding encrypted email field:**
```sql
-- V2.0__expand_add_encrypted_email.sql
-- EXPAND PHASE: Add new encrypted_email column alongside existing email
-- App V(N-1) ignores encrypted_email (unknown column = ignored in SELECT *)
-- App V(N) reads/writes BOTH columns during transition

ALTER TABLE customer_profiles
  ADD COLUMN encrypted_email BYTEA;

-- Add index CONCURRENTLY to avoid table lock
CREATE INDEX CONCURRENTLY idx_customer_encrypted_email
  ON customer_profiles (encrypted_email);

-- Audit entry for RBI compliance (Section 6.1)
INSERT INTO schema_audit_log (migration_id, description, executed_by, phase)
VALUES ('V2.0', 'Add encrypted_email column alongside email', current_user, 'EXPAND');

-- DO NOT drop email column here. That is Phase 3 (V2.2).
```

**Rollback:** Simply drop the new column. Zero risk to existing data.
```sql
-- Rollback V2.0 (safe, no data loss)
DROP INDEX CONCURRENTLY IF EXISTS idx_customer_encrypted_email;
ALTER TABLE customer_profiles DROP COLUMN IF EXISTS encrypted_email;
```

**Abort Criteria:** If migration causes query latency to increase >20%, abort automatically and alert DBA.

---

### 2.3 Phase 2 — MIGRATE (Data Backfill)

**What happens:** Existing data is backfilled from old schema to new schema using batched, throttled, idempotent jobs. The application continues serving live traffic throughout.

**Example — Backfill 100M rows in batches:**
```sql
-- V2.1__migrate_backfill_encrypted_email.sql
-- MIGRATE PHASE: Backfill encrypted_email from existing email column
-- Batch size: 1,000 rows. Throttle: 100ms pause between batches.
-- Idempotent: WHERE encrypted_email IS NULL ensures safe retries.

DO $$
DECLARE
  batch_size INT := 1000;
  total_migrated INT := 0;
  batch_count INT;
BEGIN
  LOOP
    UPDATE customer_profiles
    SET encrypted_email = pgp_sym_encrypt(
      email,
      current_setting('app.encryption_key')
    )
    WHERE encrypted_email IS NULL
    AND id IN (
      SELECT id FROM customer_profiles
      WHERE encrypted_email IS NULL
      LIMIT batch_size
      FOR UPDATE SKIP LOCKED    -- Skip locked rows, don't block
    );

    GET DIAGNOSTICS batch_count = ROW_COUNT;
    total_migrated := total_migrated + batch_count;
    RAISE NOTICE 'Migrated % rows (total: %)', batch_count, total_migrated;

    EXIT WHEN batch_count = 0;
    PERFORM pg_sleep(0.1);  -- Throttle: 100ms between batches
  END LOOP;

  RAISE NOTICE 'Backfill complete. Total rows migrated: %', total_migrated;
END $$;

-- Verify completeness before marking migration done
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM customer_profiles
    WHERE encrypted_email IS NULL AND email IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Migration incomplete: rows with email but no encrypted_email exist';
  END IF;
  RAISE NOTICE 'Backfill verification: PASSED';
END $$;
```

**Batch Sizing for 100M Row Tables:**
| Table Size | Batch Size | Throttle | Estimated Duration |
|-----------|-----------|---------|-------------------|
| < 1M rows | 5,000 | 50ms | < 5 minutes |
| 1M – 10M rows | 2,000 | 100ms | < 30 minutes |
| 10M – 100M rows | 1,000 | 150ms | 2–4 hours |
| > 100M rows | 500 | 200ms | 4–8 hours |

**Abort Criteria:** If query latency increases >20% during backfill, pause immediately and alert DBA. Resume after investigation.

---

### 2.4 Phase 3 — CONTRACT

**What happens:** Old columns/tables removed after ALL application services have migrated to the new schema. This is the **only irreversible step** — requires its own deployment with a separate approval gate.

**Governance Requirements Before Executing Phase 3:**
- [ ] All microservices confirmed running V(N) or higher (no V(N-1) instances remain)
- [ ] Backfill verified 100% complete (zero NULL rows in new column)
- [ ] DBA review and sign-off
- [ ] 72-hour monitoring window after Phase 2 complete
- [ ] CAB approval (Change Advisory Board)
- [ ] Rollback plan documented and reviewed

```sql
-- V2.2__contract_drop_email.sql
-- CONTRACT PHASE: Remove old email column
-- IRREVERSIBLE — only execute after all services use encrypted_email
-- Requires: DBA approval + CAB sign-off

-- Final verification before dropping
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM customer_profiles
    WHERE encrypted_email IS NULL AND email IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'ABORT: Cannot contract — unmigrated rows exist. Run V2.1 backfill first.';
  END IF;
END $$;

-- Drop old column (irreversible)
ALTER TABLE customer_profiles DROP COLUMN email;

-- Update audit log
INSERT INTO schema_audit_log (migration_id, description, executed_by, phase)
VALUES ('V2.2', 'Drop legacy email column — contract phase complete', current_user, 'CONTRACT');
```

---

## 3. Version Compatibility Matrix

This matrix shows which app versions can operate against each schema state:

| Schema State | App V(N-1) Compatible? | App V(N) Compatible? | Notes |
|-------------|----------------------|---------------------|-------|
| Pre-expand (email only) | ✅ Yes | ❌ No | V(N) requires encrypted_email |
| Post-expand (both columns) | ✅ Yes | ✅ Yes | Both versions work — safe deployment window |
| Post-backfill (both populated) | ✅ Yes | ✅ Yes | Both versions work |
| Post-contract (encrypted_email only) | ❌ No | ✅ Yes | V(N-1) will fail — all instances must be V(N) first |

**Key Insight:** The safe deployment window is **Phase 1 + Phase 2**. Phase 3 only happens after 100% of instances are on V(N).

---

## 4. Online Schema Migration Tool

**Tool:** pgroll (PostgreSQL) — avoids table-level locks

pgroll runs migrations using shadow tables and triggers, allowing live reads/writes throughout. Compared to standard `ALTER TABLE`:

| Approach | Table Lock During Migration | Safe for Production? |
|----------|---------------------------|---------------------|
| Standard ALTER TABLE | Yes — full table lock | ❌ No (causes downtime) |
| pgroll (online) | No — shadow table + triggers | ✅ Yes |
| gh-ost (MySQL) | No | ✅ Yes (MySQL only) |

**Abort Criteria:** If migration job impacts query latency by more than 20%, pgroll automatically aborts and rolls back the shadow table. DBA receives PagerDuty alert.

---

## 5. Migration Governance Framework

```
Developer writes migration → DBA Review (required) → Staging test with
production-scale data → Performance impact assessment → CAB approval →
Scheduled execution window → Monitor during backfill → Phase 3 approval gate
```

**DBA Review Checklist:**
- [ ] Migration uses CONCURRENTLY for index creation
- [ ] Backfill is batched and throttled
- [ ] Backfill job is idempotent (safe to retry)
- [ ] Abort criteria defined (latency threshold)
- [ ] Rollback procedure documented for each phase
- [ ] Estimated duration calculated for production data volume
- [ ] Execution window avoids blackout periods

---

## 6. Deployment Window for Migrations

Database migrations follow the same blackout calendar as application deployments (see Deliverable 2). Additionally:
- Phase 1 (EXPAND): Can run any time outside blackout periods
- Phase 2 (MIGRATE): Must run during low-traffic hours (00:00–06:00 IST)
- Phase 3 (CONTRACT): Requires CAB approval + separate deployment — minimum 72 hours after Phase 2

---

*AI Attribution: Claude (Anthropic) assisted with formatting. All migration strategies, batch sizing, and governance procedures are Nikhil Gautam's own design.*
