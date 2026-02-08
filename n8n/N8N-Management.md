# n8n Management (Docker Desktop on Windows)

## Locations

- Compose/runtime: `D:\n8n`
  - `D:\n8n\docker-compose.yml`
  - `D:\n8n\.env`
  - `D:\n8n\data\` (bind-mounted state)
- Backup scripts/output: `D:\n8n_backups`
  - `D:\n8n_backups\backup-n8n.ps1`
  - `D:\n8n_backups\backups\`

## Services

- n8n image: `docker.n8n.io/n8nio/n8n:stable`
- Postgres image: `postgres:16`
- UI: `http://localhost:5678`

## Code Node Module Allowlist

This deployment enables a small allowlist of Node.js built-in modules for n8n Code nodes (needed for OCI request signing and TCP reachability checks):

- `NODE_FUNCTION_ALLOW_BUILTIN=crypto,fs,path,https,net,url`

Without this, Code nodes will fail with errors like: `Module 'fs' is disallowed`.

## OCI Config Mount (For Workflow Signing)

The n8n container mounts the host OCI config directory read-only:

- Host: `C:\Users\opc\.oci`
- Container: `/home/node/.oci` (read-only)

This allows workflows to read `config` and the API key PEM for OCI request signing without storing the private key inside n8n credentials.

## Start/Stop

```powershell
cd D:\n8n
docker compose --env-file .\.env up -d
docker compose ps
docker compose down
```

## Frontend Validation

Browser:

- Open: `http://localhost:5678`

Command-line (HTTP status):

```powershell
curl.exe -sS -D - http://localhost:5678/ -o NUL | Select-String -Pattern '^HTTP/'
```

If the browser cannot load the UI, capture logs:

```powershell
cd D:\n8n
docker compose ps
docker compose logs --tail 200 n8n
docker compose logs --tail 200 postgres
```

## Docker/Compose Checks

Show running containers and ports:

```powershell
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

Show Compose projects and the config file location:

```powershell
docker compose ls
```

## Backups

Each run produces and uploads (when OCI args are provided):

- `postgres-YYYYMMDD-HHmmss.sql`
- `n8n-data-YYYYMMDD-HHmmss.zip`

Retention:

- Local: deletes files older than `KeepDays` from `D:\n8n_backups\backups\`
- OCI: deletes objects older than `KeepDays` under prefix `backups/n8n/` based on timestamps in object names

### Run Once

```powershell
cd D:\n8n_backups
.\backup-n8n.ps1 `
  -ComposeDir "D:\n8n" `
  -KeepDays 14 `
  -OciNamespace "orasenatdpublicsector05" `
  -OciBucket "demo-factory-assets" `
  -OciPrefix "backups/n8n" `
  -OciEndpoint "https://orasenatdpublicsector05.objectstorage.us-chicago-1.oci.customer-oci.com"
```

### Backup Validation

Local validation (confirm files created):

```powershell
Get-ChildItem D:\n8n_backups\backups -File | Sort-Object LastWriteTime -Descending | Select-Object -First 10 Name,Length,LastWriteTime
```

OCI Object Storage validation (confirm objects uploaded):

```powershell
oci os object list `
  --endpoint "https://orasenatdpublicsector05.objectstorage.us-chicago-1.oci.customer-oci.com" `
  --namespace-name orasenatdpublicsector05 `
  --bucket-name demo-factory-assets `
  --prefix "backups/n8n/" `
  --limit 20
```

## Scheduled Daily Backup

This machine is configured to `UTC`. To approximate 10:00 PM Central (CST, UTC-6) without changing the machine time zone, the task is scheduled for `04:00` UTC.

Task name: `n8n backup`

Wrapper invoked by the task:

- `D:\n8n_backups\run-n8n-backup.cmd`

Show task details:

```powershell
schtasks /Query /TN "n8n backup" /V /FO LIST
```

## OCI Notes

- Your Object Storage realm requires an endpoint override:
  - `https://orasenatdpublicsector05.objectstorage.us-chicago-1.oci.customer-oci.com`
- "Subfolders" are part of the object name (e.g. `backups/n8n/file.txt`).

## OCI Connectivity Validation Workflow

Importable workflow JSON:

- `D:\n8n_backups\workflows\oci-connectivity-validation.workflow.json`

What it validates:

- OCI Object Storage signed request (lists up to 1 object under a prefix)
- APEX/ORDS HTTP reachability (simple GET)
- ADB network reachability (TCP connect to host:1522 by default)
- OCI Generative AI (Inference) signed request (optional; off by default)

Important security note:

- The workflow reads the OCI private key from `/home/node/.oci` at runtime and does not store the PEM contents in workflow execution data.

Generative AI config values (in the workflow `Config` node):

- `genAiEndpoint`: default is the commercial realm pattern for Chicago: `https://inference.generativeai.us-chicago-1.oci.oraclecloud.com`
  - For your realm, you may need the `oci.customer-oci.com` equivalent host.
- `genAiPath`: default `/20231130/actions/chat`
- `genAiCompartmentId`: compartment OCID where you are allowed to call the service
- `genAiModelId`: a model identifier supported in your region (example in docs: `cohere.command-plus-latest`)
- `runAiCall`: set `true` to enable the GenAI check

Current status (2026-02-07):

- Frontend reachable at `http://localhost:5678`
- OCI config mount working: `C:\Users\opc\.oci` -> `/home/node/.oci` (read-only)
- Code node allowlist enabled:
  - `NODE_FUNCTION_ALLOW_BUILTIN=crypto,fs,path,https,net,url`
- Workflow name: `OCI Connectivity Validation (Object Storage + APEX/ORDS + AI + ADB TCP)`
  - Latest workflow id after dedupe: `FgYTmn5eJ04qXwgx`
- Object Storage validation:
  - Signed list call succeeds and returns objects under prefix `backups/n8n/`
  - Summarizer updated to handle `{objects:[...]}` response shape and reports `ok=true`

- APEX/ORDS validation:
  - The ORDS/APEX endpoints can redirect (for example to a landing page or sign-in). The workflow uses a Code node to capture `statusCode` and `Location` without following redirects, to avoid redirect loops.
  - Note: `https://cdxjobgw.adb.us-chicago-1.oraclecloudapps.com/ords/apex/` returns `404`; use `.../ords/apex` (no trailing slash) for the sign-in redirect check.

- Generative AI validation:
  - Inference call to `/20231130/actions/chat` succeeded (HTTP 200) after selecting a compatible chat model.
  - Working model example: `openai.gpt-oss-120b`

- Autonomous Database validation:
  - `ADB TCP Check (1522)` succeeded, confirming network reachability from the n8n container to `cdxjobgw.adb.us-chicago-1.oraclecloud.com:1522`.

## Standard Connectivity Pattern (Use For Future Workflows)

This repository standardizes on the following connectivity approach for OCI-related workflows:

- Object Storage and OCI service APIs:
  - Use OCI API-key request signing in n8n Code nodes.
  - Read OCI config and private key from the mounted host directory `/home/node/.oci` (read-only), not from stored n8n credentials.
- APEX/ORDS:
  - Use HTTP(S) calls to ORDS/APEX endpoints.
  - For health checks, do not follow redirects; treat `2xx`, `3xx`, `401`, and `403` as reachable.
- Autonomous Database:
  - For basic health validation, use TCP connectivity checks to the ADB host/port.
  - For application operations, prefer ORDS/APEX REST endpoints; direct DB connectivity from n8n should be treated as an advanced case requiring wallet/TLS handling.

## Workflow Deduplication (Keep Latest By Name)

Because repeated imports can create multiple workflows with the same name, use this helper to keep only the newest workflow per name (by `updatedAt`, then `createdAt`):

- `D:\n8n_backups\cleanup-duplicate-workflows.ps1`

Examples:

```powershell
# Dry run (shows what would be deleted)
powershell -NoProfile -ExecutionPolicy Bypass -File D:\n8n_backups\cleanup-duplicate-workflows.ps1 `
  -NameExact "OCI Connectivity Validation (Object Storage + APEX/ORDS + AI + ADB TCP)" `
  -DryRun

# Delete older duplicates (keeps newest)
powershell -NoProfile -ExecutionPolicy Bypass -File D:\n8n_backups\cleanup-duplicate-workflows.ps1 `
  -NameExact "OCI Connectivity Validation (Object Storage + APEX/ORDS + AI + ADB TCP)"
```
