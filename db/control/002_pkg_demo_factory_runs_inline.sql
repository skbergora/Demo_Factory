-- Demo Factory - Run/Step API (DB-002) - INLINE VERSION
-- Schema: DEMO_FACTORY_ADMIN
--
-- Use this script when running in browser-based SQL tools (APEX SQL Commands / Database Actions)
-- that cannot access local filesystem paths via @ includes.
--
-- After running, check the USER_ERRORS query at the end for compilation errors.

set define off

-- Package Spec
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

-- Package Body
create or replace package body pkg_demo_factory_runs as

  function norm_status(p_status in varchar2) return varchar2 is
  begin
    return upper(trim(p_status));
  end;

  function create_run(
    p_run_id         in varchar2 default null,
    p_action         in varchar2,
    p_tenant_id      in varchar2 default null,
    p_requested_by   in varchar2 default null,
    p_request_source in varchar2 default null,
    p_manifest_json  in clob default null
  ) return varchar2 is
    l_run_id varchar2(36) := p_run_id;
    l_action varchar2(30) := upper(trim(p_action));
    l_now    timestamp with time zone := systimestamp;
  begin
    if l_run_id is null then
      l_run_id := rawtohex(sys_guid());
    end if;

    insert into runs(
      run_id,
      tenant_id,
      action,
      status,
      requested_by,
      request_source,
      manifest_json,
      created_at,
      updated_at
    ) values (
      l_run_id,
      p_tenant_id,
      l_action,
      'QUEUED',
      p_requested_by,
      p_request_source,
      p_manifest_json,
      l_now,
      l_now
    );

    return l_run_id;
  exception
    when dup_val_on_index then
      -- If run_id exists, treat as idempotent create; return it.
      return l_run_id;
  end;

  procedure set_run_status(
    p_run_id        in varchar2,
    p_status        in varchar2,
    p_error_code    in varchar2 default null,
    p_error_message in varchar2 default null
  ) is
    l_status varchar2(30) := norm_status(p_status);
    l_now    timestamp with time zone := systimestamp;
  begin
    update runs
       set status = l_status,
           error_code = p_error_code,
           error_message = p_error_message,
           updated_at = l_now,
           started_at = case when l_status = 'RUNNING' and started_at is null then l_now else started_at end,
           ended_at   = case when l_status in ('FAILED','SUCCEEDED') and ended_at is null then l_now else ended_at end
     where run_id = p_run_id;

    if sql%rowcount = 0 then
      raise_application_error(-20001, 'RUN not found: ' || p_run_id);
    end if;
  end;

  procedure mark_run_started(p_run_id in varchar2) is
  begin
    set_run_status(p_run_id => p_run_id, p_status => 'RUNNING');
  end;

  procedure mark_run_ended(p_run_id in varchar2) is
    l_now timestamp with time zone := systimestamp;
  begin
    update runs
       set ended_at = case when ended_at is null then l_now else ended_at end,
           updated_at = l_now
     where run_id = p_run_id;

    if sql%rowcount = 0 then
      raise_application_error(-20001, 'RUN not found: ' || p_run_id);
    end if;
  end;

  procedure upsert_step(
    p_run_id       in varchar2,
    p_step_key     in varchar2,
    p_status       in varchar2,
    p_message      in varchar2 default null,
    p_details_json in clob default null,
    p_attempt_inc  in number default 0
  ) is
    l_status varchar2(30) := norm_status(p_status);
    l_now    timestamp with time zone := systimestamp;
  begin
    merge into run_steps t
    using (
      select
        p_run_id as run_id,
        p_step_key as step_key,
        l_status as status,
        p_message as message,
        p_details_json as details_json,
        p_attempt_inc as attempt_inc,
        l_now as ts
      from dual
    ) s
    on (t.run_id = s.run_id and t.step_key = s.step_key)
    when matched then update set
      t.status = s.status,
      t.message = s.message,
      t.details_json = s.details_json,
      t.attempt = t.attempt + nvl(s.attempt_inc, 0),
      t.updated_at = s.ts,
      t.started_at = case when s.status = 'RUNNING' and t.started_at is null then s.ts else t.started_at end,
      t.ended_at   = case when s.status in ('FAILED','SUCCEEDED','SKIPPED') and t.ended_at is null then s.ts else t.ended_at end
    when not matched then insert (
      run_id,
      step_key,
      status,
      attempt,
      message,
      details_json,
      created_at,
      updated_at,
      started_at,
      ended_at
    ) values (
      s.run_id,
      s.step_key,
      s.status,
      nvl(s.attempt_inc, 0),
      s.message,
      s.details_json,
      s.ts,
      s.ts,
      case when s.status = 'RUNNING' then s.ts else null end,
      case when s.status in ('FAILED','SUCCEEDED','SKIPPED') then s.ts else null end
    );
  exception
    when others then
      -- If run_id doesn't exist, surface a clear error.
      if sqlcode = -2291 then
        raise_application_error(-20002, 'RUN not found for step upsert: ' || p_run_id);
      end if;
      raise;
  end;

  procedure step_started(p_run_id in varchar2, p_step_key in varchar2, p_message in varchar2 default null) is
  begin
    upsert_step(p_run_id => p_run_id, p_step_key => p_step_key, p_status => 'RUNNING', p_message => p_message);
  end;

  procedure step_succeeded(p_run_id in varchar2, p_step_key in varchar2, p_message in varchar2 default null, p_details_json in clob default null) is
  begin
    upsert_step(p_run_id => p_run_id, p_step_key => p_step_key, p_status => 'SUCCEEDED', p_message => p_message, p_details_json => p_details_json);
  end;

  procedure step_failed(p_run_id in varchar2, p_step_key in varchar2, p_message in varchar2 default null, p_details_json in clob default null) is
  begin
    upsert_step(p_run_id => p_run_id, p_step_key => p_step_key, p_status => 'FAILED', p_message => p_message, p_details_json => p_details_json);
  end;

  procedure step_skipped(p_run_id in varchar2, p_step_key in varchar2, p_message in varchar2 default null, p_details_json in clob default null) is
  begin
    upsert_step(p_run_id => p_run_id, p_step_key => p_step_key, p_status => 'SKIPPED', p_message => p_message, p_details_json => p_details_json);
  end;

end pkg_demo_factory_runs;
/

-- Compilation check (should return 0 rows)
select name, type, line, position, text
from user_errors
where name = 'PKG_DEMO_FACTORY_RUNS'
order by sequence;

