# ORDS-001: Demo Factory API Module (Scaffold)

## Goal
Create the base ORDS module `DEMO_FACTORY_API` that exposes a stable HTTPS surface for n8n/APEX.

This module is the control-plane API. It should:
- Be versionable and repeatable.
- Call DB packages in `DEMO_FACTORY_ADMIN`.
- Return consistent JSON.

## Proposed Base Path
- `/ords/demo_factory/` (module base)

## MVP Endpoints (planned)
- `POST /runs/{run_id}/step` (ORDS-002)
- `POST /runs/{run_id}/provision` (ORDS-003)
- `POST /runs/{run_id}/reset` (ORDS-004)
- `POST /runs/{run_id}/drop` (ORDS-004)
- `GET  /runs/{run_id}` (optional MVP)

## Auth (MVP)
- ORDS auth via Basic Auth (internal only) or APEX session auth.
- Admin enablement endpoints are separate module (ORDS-005/006), Basic Auth for n8n only.

## Notes
- Keep request/response contracts stable.
- All privileged operations happen in DB packages; ORDS is thin routing.
