-- Demo Factory - Run/Step API (DB-002)
-- Schema: DEMO_FACTORY_ADMIN
--
-- Provides a single, consistent API for APEX, ORDS, and n8n to:
-- - create and update RUNS
-- - upsert RUN_STEPS
-- - mark runs as succeeded/failed

create or replace package pkg_demo_factory_runs as

  -- Creates a run row. If p_run_id is null, generates one.
  -- Returns run_id.
  function create_run(
    p_run_id         in varchar2 default null,
    p_action         in varchar2,
    p_tenant_id      in varchar2 default null,
    p_requested_by   in varchar2 default null,
    p_request_source in varchar2 default null,
    p_manifest_json  in clob default null
  ) return varchar2;

  -- Updates run status (and timestamps) with optional error details.
  procedure set_run_status(
    p_run_id        in varchar2,
    p_status        in varchar2,
    p_error_code    in varchar2 default null,
    p_error_message in varchar2 default null
  );

  -- Marks the run as started (sets RUNNING + started_at).
  procedure mark_run_started(p_run_id in varchar2);

  -- Marks the run as ended (sets ended_at).
  procedure mark_run_ended(p_run_id in varchar2);

  -- Upserts a step (idempotent by run_id + step_key).
  -- If status transitions to RUNNING, sets started_at when null.
  -- If status transitions to terminal (FAILED/SUCCEEDED/SKIPPED), sets ended_at when null.
  procedure upsert_step(
    p_run_id       in varchar2,
    p_step_key     in varchar2,
    p_status       in varchar2,
    p_message      in varchar2 default null,
    p_details_json in clob default null,
    p_attempt_inc  in number default 0
  );

  -- Convenience helpers
  procedure step_started(p_run_id in varchar2, p_step_key in varchar2, p_message in varchar2 default null);
  procedure step_succeeded(p_run_id in varchar2, p_step_key in varchar2, p_message in varchar2 default null, p_details_json in clob default null);
  procedure step_failed(p_run_id in varchar2, p_step_key in varchar2, p_message in varchar2 default null, p_details_json in clob default null);
  procedure step_skipped(p_run_id in varchar2, p_step_key in varchar2, p_message in varchar2 default null, p_details_json in clob default null);

end pkg_demo_factory_runs;
/

