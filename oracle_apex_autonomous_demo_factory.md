# Oracle APEX-Driven Autonomous Demo Factory

*ATP-first • APEX-only • Synthetic-only • Team-reusable*

---

## 1. Purpose & Goals
This document defines a **repeatable demo factory** built entirely on **Oracle Autonomous Database (ATP first, ADW later)** and **Oracle APEX**, designed to support fast, safe, and consistent customer demos across an extended team.

### Goals
- Rapidly generate **isolated demo tenants** using schemas/users
- Use **100% synthetic, realistic data** (no non-public customer data)
- Showcase **Oracle Database AI capabilities**:
  - Select AI (natural language → SQL)
  - Document Understanding
  - Vision (image analysis)
- Keep demos **light-hearted but professional** via optional safe humor
- Provide **reset and cleanup workflows** to keep environments clean
- Remain **APEX-only** to stay focused on Oracle Database + OCI data services

### Non-Goals
- No ingestion of real customer data
- No public web scraping into database tables
- No external orchestration platforms (Functions, OKE, etc.) in MVP

---

## 2. High-Level Architecture (APEX-Only)

### Core Services
- Oracle Autonomous Database – **ATP (primary)**
- Oracle APEX – UI **and** orchestration
- Oracle Select AI
- OCI AI Services (Document Understanding, Vision)
- OCI Object Storage (demo artifacts)

### Design Principle
- **One shared ATP**
- **One admin/control schema**
- **One schema per demo tenant**

---

## 3. Data Safety & Guardrails

- Synthetic-only data generation
- Customer names used as labels only
- No uploads in MVP
- Strict PII avoidance
- Optional safe humor for non-critical text only

---

## 4. Tenant Model

### Control Plane Schema
**Schema:** `DEMO_FACTORY_ADMIN`

Tables:
- TENANTS
- MANIFESTS
- RUNS
- PROMPT_LIBRARY
- CLEANUP_POLICIES

### Tenant Schema
**Naming:** `DEMO_<CUSTOMER>_<YYYYMMDD>`

Contains:
- Synthetic OLTP tables
- Curated views
- Doc AI and Vision outputs
- Select AI views

---

## 5. Manifest (JSON)
```json
{
  "customer_label": "ACME",
  "industry_pack": "RETAIL",
  "demo_packs": {
    "select_ai": true,
    "doc_ai": true,
    "vision_ai": false
  },
  "data_volume": "M",
  "humor_mode": "LIGHT",
  "pii_mode": "SYNTHETIC_ONLY",
  "cleanup": {
    "mode": "TTL_AUTO",
    "ttl_days": 7
  }
}
```

---

## 6. Orchestration
- APEX triggers DBMS_SCHEDULER jobs
- Deterministic provisioning steps
- Clear run-state tracking

---

## 7. Synthetic Data Strategy
- OLTP-style ATP datasets
- Optional light, professional humor
- Toggleable per tenant

---

## 8. Select AI
- Curated views
- Golden prompts
- Explainable SQL

---

## 9. Documents & Images
- Synthetic PDFs and images
- OCI Document Understanding
- OCI Vision

---

## 10. Cleanup
- Reset data
- Drop tenant
- TTL-based auto cleanup

---

## 11. Secrets
- OCI Vault preferred
- APEX Web Credentials fallback

---

## 12. MVP Phases
1. Control plane + APEX UI
2. Select AI demos
3. Doc AI & Vision
4. ADW expansion

---

## 13. Outcome
A clean, Oracle-native, reusable demo factory aligned to OCI and Autonomous Database.
