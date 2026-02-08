# End-to-End Orchestration (APEX Parent App + n8n)

This document defines the target end-to-end process for the Demo Factory, combining:

- APEX as the parent/control-plane UI (operator entry point)
- n8n as the orchestration engine (workflow execution and cross-service automation)
- Autonomous Database + APEX/ORDS as the system of record and provisioning engine
- OCI Object Storage + OCI Generative AI as supporting services

It is written to align with:

- `D:\n8n_backups\N8N-Management.md` (n8n deployment, backups, and connectivity method)
- `D:\Demo_Factory\oracle_apex_autonomous_demo_factory.md` (vision and architecture goals)
- `D:\Demo_Factory\implementation_guide.md` (phase plan and environment metadata)

## 1. Outcome

Operators provision a new demo "tenant" by opening an APEX app, entering a customer name, selecting packs/options, and submitting.

APEX submits a run request to n8n. n8n then:

1. Validates connectivity to all required services (Object Storage, APEX/ORDS, GenAI, ADB reachability).
2. Provisions tenant artifacts by calling ORDS endpoints (implemented in PL/SQL in the control schema).
3. Seeds synthetic data and optional AI artifacts.
4. Writes step-by-step run status back to the control schema for full auditability.

## 2. Standard Connectivity Pattern (Decision)

This is the decided connectivity method for future workflows and automation:

1. OCI APIs (Object Storage, GenAI, and future OCI services):
   - n8n uses OCI API-key request signing in Code nodes.
   - n8n reads OCI config/private key from `/home/node/.oci` (mounted read-only from the host).
   - No OCI private keys are stored in n8n credentials.

2. APEX/ORDS:
   - n8n calls ORDS endpoints (REST modules) over HTTPS.
   - For "reachability" health checks, do not follow redirects; treat 2xx/3xx/401/403 as reachable.

3. Autonomous Database:
   - n8n performs a basic TCP reachability check to `<adbHost>:1522`.
   - Database provisioning actions are executed inside the database via PL/SQL (invoked through ORDS endpoints).
   - Direct wallet-based DB connections from n8n are considered an advanced case and out of MVP.

## 3. System Components

### 3.1 APEX Parent App (Control Plane UI)

Purpose:

- Collect provisioning input (customer label, packs, volume, cleanup TTL)
- Show run status and logs
- Allow reset/drop actions

APEX workspace/schema:

- Control schema: `DEMO_FACTORY_ADMIN`
- APEX app(s): a Control Plane app (admin/operator)

### 3.2 ORDS REST Modules (Control Plane API)

Purpose:

- Provide stable APIs for n8n to call, implemented in PL/SQL
- Ensure all privileged actions happen in the database with auditing

### 3.3 n8n (Orchestrator)

Purpose:

- Execute the run pipeline reliably
- Call OCI APIs and ORDS APIs
- Poll/aggregate statuses into a single execution report

Reference:

- Deployment/backups: `D:\n8n_backups\N8N-Management.md`

### 3.4 OCI Object Storage (Artifacts)

Purpose:

- Store synthetic assets (docs/images), manifests, exports, and run artifacts

Baseline bucket:

- Bucket: `demo-factory-assets`
- Prefixes (example conventions):
  - `manifests/`
  - `runs/<run_id>/`
  - `tenants/<tenant_key>/`
  - `docs_ai/`
  - `vision_ai/`
  - `external_load_files/`

### 3.5 OCI Generative AI

Purpose:

- Support GenAI demo pack operations (summaries, narratives, prompt-based enrichments)
- Used in the connectivity validation workflow and future tenant content generation

## 4. End-to-End Process

### 4.1 Provision Tenant (Happy Path)

1. Operator opens APEX Control Plane app
2. Operator enters:
   - Customer label (required)
   - Industry pack (optional)
   - Demo packs toggles (Select AI / Doc AI / Vision AI / GenAI)
   - Data volume (S/M/L)
   - Cleanup policy (TTL days)
3. APEX validates input and builds a manifest JSON
4. APEX creates a new RUN record in `DEMO_FACTORY_ADMIN.RUNS`:
   - `run_id` (GUID)
   - `status = QUEUED`
   - `manifest_json`
   - `requested_by`
   - timestamps
5. APEX calls the n8n "Provision Tenant" webhook:
   - Request includes `run_id`, `manifest`, and environment constants
6. n8n workflow runs steps (each step writes progress to the DB via ORDS):
   1. Step: Connectivity validation
   2. Step: Ensure Object Storage prefixes for the run
   3. Step: Call ORDS provision API (PL/SQL) to:
      - Create tenant schema/user
      - Apply DDL templates
      - Seed synthetic data
      - Register APEX objects/metadata as needed
   4. Step: Optional AI packs:
      - Generate/refresh AI content, store outputs in tenant tables
   5. Step: Mark run `SUCCEEDED` and store final summary
7. APEX status page shows final result and a deep link to the tenant experience

### 4.2 Reset Tenant

Goal: rerun synthetic data and demo artifacts without dropping the tenant schema.

1. Operator selects a tenant and presses Reset
2. APEX creates RUN record `RESET` type (or sets `run_action = RESET`)
3. APEX calls n8n "Reset Tenant" webhook
4. n8n calls ORDS reset API, then verifies post-conditions

### 4.3 Drop Tenant

Goal: remove tenant schema and associated Object Storage artifacts (per policy).

1. Operator selects a tenant and presses Drop
2. APEX creates RUN record `DROP` type
3. APEX calls n8n "Drop Tenant" webhook
4. n8n calls ORDS drop API and optionally cleans up Object Storage prefixes

## 5. APIs and Payloads

### 5.1 APEX -> n8n (Webhooks)

n8n will expose webhook endpoints (exact path TBD), for example:

- `POST /webhook/demo-factory/provision`
- `POST /webhook/demo-factory/reset`
- `POST /webhook/demo-factory/drop`

Payload (example):

```json
{
  "run_id": "uuid",
  "requested_by": "apex_user",
  "customer_label": "ACME",
  "manifest": { "..." : "..." },
  "env": {
    "ords_base_url": "https://cdxjobgw.adb.us-chicago-1.oraclecloudapps.com",
    "os_bucket": "demo-factory-assets",
    "os_endpoint": "https://orasenatdpublicsector05.objectstorage.us-chicago-1.oci.customer-oci.com"
  }
}
```

### 5.2 n8n -> ORDS (Control Plane APIs)

Recommended REST module layout (examples):

- `POST /ords/demo_factory/runs/:run_id/step`
  - Write step transitions and logs
- `POST /ords/demo_factory/runs/:run_id/provision`
  - Perform provisioning actions in PL/SQL
- `POST /ords/demo_factory/runs/:run_id/reset`
- `POST /ords/demo_factory/runs/:run_id/drop`
- `GET /ords/demo_factory/runs/:run_id`
  - Fetch status for polling

Each API should be idempotent per `run_id` and should record all side effects in the control schema.

## 6. Database Design (To Be Built)

Control schema: `DEMO_FACTORY_ADMIN`

Minimum tables:

- `TENANTS`
  - `tenant_id`, `tenant_key`, `customer_label`, `schema_name`, `created_at`, `status`
- `RUNS`
  - `run_id`, `tenant_id` (nullable for initial provision), `action`, `status`, `requested_by`, `manifest_json`, timestamps
- `RUN_STEPS`
  - `run_id`, `step_key`, `status`, `started_at`, `ended_at`, `details_json`
- `PROMPT_LIBRARY` (optional for AI packs)
- `CLEANUP_POLICIES` (optional if not embedded in manifest)

Packages:

- `PKG_DEMO_FACTORY_RUNS` (create/update runs and steps)
- `PKG_DEMO_FACTORY_PROVISION` (schema create/ddl/seed)
- `PKG_DEMO_FACTORY_RESET`
- `PKG_DEMO_FACTORY_DROP`

ORDS module:

- `DEMO_FACTORY_API` mapping to the packages above

## 7. n8n Workflow Design (To Be Built)

Workflows:

1. `OCI Connectivity Validation (Object Storage + APEX/ORDS + AI + ADB TCP)`
   - Reference implementation already exists and is the baseline connectivity harness.

2. `Demo Factory - Provision Tenant`
   - Trigger: webhook (APEX submission)
   - Steps:
     - Validate payload, create/confirm run state in DB
     - Call connectivity validation (sub-workflow)
     - Ensure Object Storage prefixes under `runs/<run_id>/`
     - Call ORDS provision endpoint
     - Poll ORDS run status until completion
     - Write final summary

3. `Demo Factory - Reset Tenant`
4. `Demo Factory - Drop Tenant`

Key requirements:

- Idempotency by `run_id`
- Step-level logging to `RUN_STEPS`
- Fail fast with actionable error messages

## 8. APEX App Design (To Be Built)

Pages (suggested):

1. Dashboard
   - Recent runs, tenant counts, failures
2. New Tenant
   - Form: customer label, packs, volume, TTL
   - On submit: insert RUN + call n8n webhook
3. Run Detail
   - Status, steps, logs, raw manifest
4. Tenants
   - List tenants with actions: reset / drop
5. Admin
   - Default settings, prompt library, cleanup policies

APEX integration to call n8n:

- Use APEX `APEX_WEB_SERVICE.MAKE_REST_REQUEST` (or REST Data Source) to post to the n8n webhook.
- Store the n8n base URL and webhook path in application settings.

## 9. Operational Notes

- n8n backups (daily, rolling 14 days) are already in place and upload to OCI Object Storage.
- Keep all credentials out of workflow JSON when possible; rely on `/home/node/.oci` and ORDS auth mechanisms.
- Prefer ORDS APIs for database provisioning actions to keep the n8n container free of DB wallets and SQL tooling.

## 10. Next Build Steps (Practical Sequence)

1. Implement control plane tables + `PKG_DEMO_FACTORY_RUNS` in `DEMO_FACTORY_ADMIN`.
2. Implement ORDS module `DEMO_FACTORY_API` with:
   - Run status endpoints
   - Provision endpoint (initially stubbed with logging)
3. Build APEX Control Plane app pages:
   - New Tenant form that creates RUN + calls n8n webhook
   - Run Detail page that reads `RUNS` + `RUN_STEPS`
4. Build n8n `Provision Tenant` workflow:
   - webhook trigger + calls to ORDS APIs
5. Flesh out provisioning logic:
   - Tenant schema create, template DDL, synthetic seed
6. Add AI packs incrementally (Select AI, Doc AI, Vision, GenAI)

