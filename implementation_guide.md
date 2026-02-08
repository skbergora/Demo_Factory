## Oracle Autonomous Demo Factory â€“ Implementation Guide

> Updated task-oriented guide:
> - `D:\Demo_Factory\implementation_guide_v2.md`

### 1. Vision & Goal
Deliver a reusable, ATP-first Oracle APEX demo factoryâ€”augmented with an Oracle Analytics Cloud (OAC) companion experienceâ€”that can be provisioned, demoed, reset, and extended by the broader field team without custom engineering.

### 2. Reference Summary
- **Platform Tenets**: ATP-first, APEX-only orchestration, synthetic-only datasets, safe humor optional.
- **Experience Targets**: Select AI, Document Understanding, Vision AI, and OAC dashboards mirroring the APEX narrative.
- **Runbook Model**: One control schema (`DEMO_FACTORY_ADMIN`), one tenant schema per customer, all orchestrated via APEX + DBMS Scheduler.

### 3. Deliverables
1. **Control Plane & Governance** â€“ DEMO_FACTORY_ADMIN schema, manifest handling, job orchestration, reset automation, and admin APEX UI.
2. **Tenant Provisioning** â€“ Deterministic schema creation per manifest with synthetic data, AI service outputs, and cleanup policies.
3. **Demo Experiences** â€“ APEX pages/workflows for Select AI, Document Understanding, and Vision; curated assets in Object Storage.
4. **Automation & Runbooks** â€“ Reset/cleanup procedures, synthetic data refresh guidance, and manifest templates.
5. **OAC Perspective** â€“ Replicated curated views/datasets + dashboards that mirror the APEX story with analytics-grade visuals.

### 4. Success Criteria
- Tenants can be provisioned and torn down repeatedly via APEX UI with audit trails in RUNS.
- All data is synthetic, documented, and reproducible from stored manifests.
- Select AI / Doc AI / Vision demos run end-to-end with OCI credentials managed in Vault or APEX Web Credentials.
- Demo operators can hand off a manifest + instructions for consistent replication.
- OAC dashboards present the same narratives (Select AI insights, Doc/Vision highlights) with interactive visuals sourced from the tenant data or curated extracts.

### 5. Constraints & Guardrails
- **ATP-first**: A single Autonomous Transaction Processing instance hosts control & tenant schemas (ADW optional in later phases).
- **APEX-only orchestration**: No external schedulers/functions for MVP.
- **Synthetic-only datasets** with optional light humor; no uploads in MVP.
- **Security**: OCI Vault preferred, fallback to APEX credentials, strict PII avoidance.

### 6. Architecture Snapshot
- **Core Services**: ATP, APEX, Select AI, OCI AI Services (Doc/Vision), OCI Object Storage, OCI Vault/APEX credentials.
- **Tenant Model**: Control schema `DEMO_FACTORY_ADMIN` + tenant schemas `DEMO_<CUSTOMER>_<YYYYMMDD>` with synthetic OLTP data, curated views, AI outputs.
- **Manifest Driven**: JSON manifest drives packs, humor toggle, cleanup policy (see reference manifest).

### 7. Phased Plan & Status

#### Phase 0 â€“ Foundations & Readiness (Week 1) âœ… Mostly Complete (CI/CD hooks pending)
- **ATP Environment Prep**  
  - Instance OCID: `ocid1.autonomousdatabase.oc1.us-chicago-1.anxxeljt2ocwscaahcbko35rtaro7a3tyy44grviaatbhmrht6br7hv2bfgq` (workload: ATP, private access).  
  - Credential wallet: `Wallet_SBAITST.zip` (store in OCI Vault or restricted Object Storage).  
  - Create users via OCI Database Actions/SQL Worksheet: `DEMO_FACTORY_ADMIN` plus pattern `DEMO_<CUSTOMER>_<YYYYMMDD>` for tenants (default tablespace).  
  - **Recommended roles for `DEMO_FACTORY_ADMIN`:** `CONNECT`, `RESOURCE`, `CONSOLE_DEVELOPER`, `DWROLE`, `SODA_APP`, `CTXAPP`, `GRAPH_DEVELOPER`, `OML_DEVELOPER`, `DCAT_SYNC`. Add object privileges (`CREATE JOB`, `CREATE VIEW`, `CREATE SEQUENCE`, `CREATE MATERIALIZED VIEW`, `CREATE PROCEDURE`, `CREATE TRIGGER`, `UNLIMITED TABLESPACE`) as needed for orchestration jobs, logging tables, and AI service staging. Keep grants documented for future least-privilege tightening.
  - Validate connectivity through OCI Database Actions, SQLcl (wallet-based), and APEX private endpoints. (âœ… Confirmed by current operator.)  
  - Capture scripts in OCI DevOps/Resource Manager to demonstrate full OCI-tooling provisioning.
- **APEX Platform Readiness** â€“ (Upgrade complete âœ…) Now focus on:
  - Create an APEX workspace (âœ… `DEMO_FACTORY`) mapped to `DEMO_FACTORY_ADMIN`. Workspace builder user: `DEMO_ADMIN` (password stored in secure vault; not logged here). Use OCI Database Actions > APEX to keep tooling within OCI.
  - Configure authentication/authorization (âœ… APEX accounts for now; single-operator mode). Document future path to OCI IAM if multi-operator access is needed.
  - Enable REST Data Source/REST Enabled SQL if future services need it, ensuring the workspace can reach both control and tenant schemas. (âœ… `DEMO_FACTORY_ADMIN` and workspace accounts already REST-enabled.) Document tenant-onboarding steps: grant REST privileges + add schema assignment when automation creates each `DEMO_*` schema.
  - Provision a sample application stub (placeholder pages) to validate schema grants, file storage, and session state before Phase 1 development. Include: static Dashboard/Tenant pages, File Browse item storing in `APEX_APPLICATION_TEMP_FILES`, and an â€œOn Submitâ€ PL/SQL process (e.g., set hidden `P1_STATUS := 'UPLOAD_RECEIVED'` + `APEX_DEBUG.MESSAGE(...)`) to confirm session state updates via Session â†’ View Items.
    - **How-to:**
      1. Create hidden item `P1_STATUS` on the target page.
      2. In Page Designer â†’ Processing, add process `PROC_SET_STATUS` with point â€œOn Submit â€“ After Computations and Validations.â€
      3. Type = PL/SQL Code, body: `:P1_STATUS := 'UPLOAD_RECEIVED'; APEX_DEBUG.MESSAGE('Stub process executed');`
      4. Keep Server-side Condition = Always; run page, submit, then use Developer Toolbar â†’ Session â†’ View Items to verify `P1_STATUS` set.
  - Record workspace IDs, admin credentials storage location (OCI Vault), and any custom ACLs here for the runbook.

> **Phase 0 Completion Recap:**
> - ATP instance provisioned + wallet `Wallet_SBAITST.zip` secured
> - `DEMO_FACTORY_ADMIN` user created with elevated roles/object privs
> - Connectivity validated via Database Actions, SQLcl, and APEX private endpoint
> - APEX workspace `DEMO_FACTORY` established (builder user `DEMO_ADMIN`, APEX-auth only)
> - REST Enabled SQL confirmed for control workspace; tenant onboarding steps documented
> - Admin stub app online with file upload + PL/SQL session-state test

- **Synthetic Asset Staging** â€“ Create OCI Object Storage bucket for doc/image packs, seed initial synthetic assets, and note naming/tagging standards.
  - Bucket: `demo-factory-assets` (Region `us-chicago-1`, Namespace `orasenatdpublicsector05`, OCID `ocid1.bucket.oc1.us-chicago-1.aaaaaaaavf6xzjbqhwkyyzbzk2xcmlzw6iknljk2mytcbpnwtqmh2ysuccia`). Private bucket; plan to expose via resource principal when automation is ready.
  - Folder prefixes created: `docs_ai/`, `vision_ai/`, `manifests/`, `external_load_files/` (state & local themed assets to be added once synthetic data is available).
  - Define naming standards (e.g., `state_local-objecttype-version`) and store credentials (Vault secret or APEX Web Credential) for access. Document sample object URIs and tags once seed files exist.
- **CI/CD Hooks (OCI-native)** â€“ _In progress_: comparing OCI DevOps (Code Repo + Build/Deploy pipelines) versus Terraform/Resource Manager for first-class automation.
  - **Current leaning**: OCI DevOps keeps everything within OCI-native services, supports SQLcl/ APEX export flows, and is pay-as-you-go (no extra cost beyond compute minutes + artifact storage already covered). Terraform + Resource Manager may be lighter weight for purely infrastructure-as-code but would still require a separate pipeline or manual applies for schema/APEX packaging.
  - Decision inputs: team familiarity, need for artifact traceability/run history (DevOps excels here), and how much infrastructure drift control is required (Terraform better if multi-environment parity is critical).
  - Repo structure proposal (applies to either choice):
    - `/db/control/` â€“ SQL scripts for `DEMO_FACTORY_ADMIN` objects (tables, packages, jobs)
    - `/db/tenant/` â€“ template DDL for tenant schemas
    - `/apex/` â€“ exported apps (`f<AppID>.sql`) + import scripts
    - `/scripts/` â€“ SQLcl shell wrappers (e.g., `deploy_control_schema.sh`)
  - Tentative OCI DevOps build steps (to be finalized once cloning issue resolved):
    1. Checkout repo (OCI DevOps Code Repo or external Git)
    2. Download wallet `Wallet_SBAITST.zip` (Object Storage or DevOps artifact)
    3. Fetch DB creds from OCI Vault Secret variables
    4. Run SQLcl: `sql /nolog @scripts/deploy_control_schema.sql`
    5. Run APEX export/import via SQLcl `apex export` + `apex import`
    6. Publish artifacts (optional) for traceability
  - Open items: document pipeline OCID, repo URL, secret names, trigger mode; capture Terraform alternative if OCI DevOps access issues persist.
- **OAC Track** â€“ Identify the target OAC tenancy, confirm private connectivity (Data Gateway/Private Endpoint) to the ATP instance, and reserve capacity/licensing.

> **Runbook Note:** This implementation guide doubles as the living runbook. Update this section whenever instance metadata, wallets, user patterns, or OCI automation flows change so internal operators always have a single reference. Current access is limited to the primary operator; additional users will be onboarded post-MVP.

#### Phase 1 â€“ Control Plane & Admin APEX (Weeks 2â€“3) ðŸ”„ Up Next
- Model control tables (TENANTS, MANIFESTS, RUNS, PROMPT_LIBRARY, CLEANUP_POLICIES).
- Build manifest JSON validation PL/SQL package + REST enablement if needed.
- Create APEX admin app pages: dashboard, manifest upload/edit, run tracker, cleanup monitor.
- Implement DBMS_SCHEDULER jobs invoked from APEX (provision, reset, drop).
- Logging & notifications (APEX Activities + email/slack integration optional).
- **OAC Track**: Define naming convention for mirrored datasets; design initial semantic model (fact + dimension views) aligned with manifest schema.

#### Phase 2 â€“ Tenant Provisioning & Synthetic Data (Weeks 4â€“5)
- Generate baseline OLTP tables, sequences, and curated views per tenant schema.
- Script deterministic synthetic data builders (industry packs, humor toggle, volume scaling).
- Persist manifest metadata within tenant (e.g., DEMO_METADATA table) for traceability.
- Enhance cleanup automation with TTL enforcement + manual override.
- **OAC Track**: Expose tenant curated views via read-only accounts; configure data model ingestion pipeline (DB links, Data Gateway, or extract scripts).

#### Phase 3 â€“ AI Feature Packs (Weeks 6â€“7)
- **Select AI**: Golden prompts, explainable SQL views, sample Q&A flows in APEX.
- **Document Understanding**: Load synthetic PDFs, persist extraction outputs, visualize status.
- **Vision AI**: Process sample images, store labels/annotations, expose results in tenant schema.
- Add toggle-able demo packs in manifest to include/exclude AI services per tenant.
- **OAC Track**: Build dashboards showcasing AI insightsâ€”e.g., Select AI query comparison, Doc AI metadata trends, Vision classification heatmaps.

#### Phase 4 â€“ Demo UX & Storytelling (Weeks 8â€“9)
- Polish APEX UI with guided walkthroughs, persona switchers, and safe humor callouts.
- Bundle manifest templates by industry, including recommended prompts/scripts.
- Document runbooks: provisioning checklist, cleanup SOP, troubleshooting matrix.
- **OAC Track**: Finalize storytelling dashboards, publish catalog, and script side-by-side demo narrative comparing APEX vs. OAC experiences.

#### Phase 5 â€“ Expansion & ADW/OAC Enhancements (Week 10+)
- Evaluate ADW for analytic-heavy packs; introduce hybrid ATP+ADW option.
- Automate OAC dataset refresh (APEX job â†’ OCI Data Integration or db_jobs feeding staged tables).
- Add usage telemetry collection to inform future demo improvements.

### 8. Oracle Analytics Cloud Footprint Strategy
1. **Data Alignment**: All curated APEX views become OAC data sources; enforce column naming parity for consistent storytelling.
2. **Dataset Publishing Workflow**: Control schema stores dataset definitions and last refresh timestamps; scheduler publishes to OAC via REST or Data Gateway.
3. **Visual Narratives**: Mirror KPIs from APEX (Select AI insights, Doc AI extraction summaries, Vision accuracy) but highlight OAC-specific capabilitiesâ€”map visualizations, anomaly detection, natural language insights.
4. **Demo Toggle**: From APEX admin UI, provide deep links to the equivalent OAC dashboard filtered for the same tenant.

### 9. Whatâ€™s Next
- Approve Phase 1 resourcing + confirm OCI DevOps repo/pipeline ownership.
- Kick off Phase 1 build: control tables, manifest validation package, admin UI pages, scheduler jobs, logging/notifications.
- Parallel OAC task: finalize mirrored dataset naming + semantic model designs.
- Pre-stage tenant DDL templates to accelerate Phase 2 once control plane is stable.

### 10. Source Control Runbook (OCI DevOps + GitHub)
- **Local repo path**: `/Users/shandybergeron/Library/CloudStorage/OneDrive-OracleCorporation/_Oracle/Demos/Automated_Demo/Demo_Factory_Repo/demo-factory-repo`.
- **Primary remote (origin)**: OCI DevOps Code Repo (used by VS Codeâ€™s Git integration). Workflow: stage/commit from VS Code, then â€œSync Changesâ€ to push to OCI DevOps.
- **Secondary remote (github)**: GitHub mirror for broader collaboration. After syncing to OCI DevOps, run `git push github main` (or your active branch) from the same directory to propagate changes.
- **Credential note**: OCI DevOps requires username format `Tenancy/Federation/User` plus Auth Token. GitHub can use personal access tokens or SSH as desired.

> _Keep sensitive OCI configuration files private if the GitHub repo is public. Consider `.gitignore` entries for wallets or secrets._

### 11. Automation Workflow (n8n on OCI Compute)
1. **Compute VM Prerequisites**
   - Provision an OCI Compute VM in the same VCN/subnet as ATP. Install n8n (Docker or Node.js) plus SQLcl, OCI CLI, `jq`, and unzip.
   - Configure environment variables or n8n credentials for OCI Auth Token (Object Storage read), wallet password, and SQLcl connect string.
2. **Workflow Outline (n8n nodes)**
   1. **Manual Trigger / HTTP Webhook** â€“ entry point to start deployments.
   2. **Function Node** â€“ set variables (bucket name, object paths, repo directory).
   3. **HTTP Request Node** (OCI Object Storage GET) â€“ download `adb_credentials.json` to local filesystem (use auth token header).
   4. **HTTP Request Node** â€“ download `Wallet_SBAITST.zip` similarly.
   5. **Execute Command Node** â€“ run shell script to parse credentials and unzip wallet:
      ```bash
      WALLET_PWD=$(jq -r '.walletPassword' adb_credentials.json)
      SQLCL_CONNECT=$(jq -r '.sqlclConnectString' adb_credentials.json)
      unzip -P "$WALLET_PWD" Wallet_SBAITST.zip -d wallet
      export TNS_ADMIN=$PWD/wallet
      export SQLCL_CONNECT
      ```
   6. **Execute Command Node** â€“ run `scripts/deploy_control_schema.sh` (ensure repo mounted on VM).
   7. **Execute Command Node** â€“ run `scripts/deploy_apex_app.sh`.
   8. **Notification Node** (email/Teams/Slack) â€“ summarise success/failure with log snippets.
3. **Credential Handling**
   - Use n8nâ€™s credential vault for Object Storage auth token and database connect string if you prefer not to store them in files.
   - Rotate tokens manually (or via scheduled workflow) since Vault integration isnâ€™t available.
4. **Logging & Rollback**
   - n8n stores execution history; export logs or push to OCI Logging if desired.
   - Rollback procedure remains manual (rerun baseline scripts, drop tenant schemas, etc.).
5. **Future Enhancements**
   - Add schedules for nightly resets, include branching for tenant-specific manifests, or call APEX apps via REST for health checks.

_This guide remains the living runbookâ€”update after each milestone (whether automation lives in n8n, DevOps, or another orchestrator)._ 

### 11a. APEX Parent App + n8n Orchestration (Target E2E)

For the consolidated end-to-end process (APEX parent app submits a customer/run request to n8n, n8n orchestrates OCI + ORDS APIs, and all state is tracked in the control schema), see:

- `D:\Demo_Factory\end_to_end_apex_n8n_process.md`

### 12. Immediate Next Steps
1. Install Docker Desktop (or Docker Engine) on the OCI Windows VM that will host n8n.
2. Deploy the official n8n Docker container on that VM (bind-mount the repo path so `scripts/` is accessible).
3. Once n8n is up, import or build the workflow described above and test Object Storage access + SQLcl connectivity.
4. Resume configuration/testing after rest.

