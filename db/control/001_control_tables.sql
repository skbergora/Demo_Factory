-- Demo Factory - Control Plane Tables (DB-001)
-- Schema: DEMO_FACTORY_ADMIN
--
-- Creates the minimum control-plane tables needed for the end-to-end flow:
--   - TENANTS
--   - RUNS
--   - RUN_STEPS
--
-- Notes:
-- - Idempotent-ish: ignores ORA-00955 (name already used).
-- - JSON columns are stored as CLOB with an IS JSON constraint (Oracle 21c+ / Autonomous).
-- - updated_at is not automatically maintained here; that can be added in DB-002.

set define off
set serveroutput on

declare
  procedure exec_ddl(p_sql in clob) is
  begin
    execute immediate p_sql;
    dbms_output.put_line('OK: ' || substr(replace(p_sql, chr(10), ' '), 1, 120));
  exception
    when others then
      if sqlcode = -955 then
        dbms_output.put_line('SKIP (exists): ' || substr(replace(p_sql, chr(10), ' '), 1, 120));
      else
        dbms_output.put_line('FAIL: ' || sqlerrm);
        raise;
      end if;
  end;
begin
  -- TENANTS: one row per provisioned demo tenant
  exec_ddl(q'[
    create table tenants (
      tenant_id        varchar2(36) default rawtohex(sys_guid()) not null,
      tenant_key       varchar2(128) not null,
      customer_label   varchar2(256) not null,
      schema_name      varchar2(128) not null,
      status           varchar2(30)  default 'ACTIVE' not null,
      manifest_json    clob,
      created_at       timestamp with time zone default systimestamp not null,
      updated_at       timestamp with time zone,
      constraint tenants_pk primary key (tenant_id),
      constraint tenants_tenant_key_uk unique (tenant_key),
      constraint tenants_schema_name_uk unique (schema_name),
      constraint tenants_status_ck check (status in ('ACTIVE','INACTIVE','DROPPED')),
      constraint tenants_manifest_json_is_json check (manifest_json is json)
    )
  ]');

  -- RUNS: one row per orchestration request (provision/reset/drop)
  exec_ddl(q'[
    create table runs (
      run_id           varchar2(36) default rawtohex(sys_guid()) not null,
      tenant_id        varchar2(36),
      action           varchar2(30) not null,
      status           varchar2(30) default 'QUEUED' not null,
      requested_by     varchar2(256),
      request_source   varchar2(64),
      manifest_json    clob,
      error_code       varchar2(64),
      error_message    varchar2(4000),
      created_at       timestamp with time zone default systimestamp not null,
      updated_at       timestamp with time zone,
      started_at       timestamp with time zone,
      ended_at         timestamp with time zone,
      constraint runs_pk primary key (run_id),
      constraint runs_action_ck check (action in ('PROVISION','RESET','DROP')),
      constraint runs_status_ck check (status in ('QUEUED','RUNNING','FAILED','SUCCEEDED')),
      constraint runs_manifest_json_is_json check (manifest_json is json),
      constraint runs_tenant_fk foreign key (tenant_id) references tenants(tenant_id)
    )
  ]');

  -- RUN_STEPS: step-level audit trail per run (idempotent by run_id + step_key)
  exec_ddl(q'[
    create table run_steps (
      run_id           varchar2(36) not null,
      step_key         varchar2(64) not null,
      status           varchar2(30) default 'PENDING' not null,
      attempt          number default 0 not null,
      message          varchar2(4000),
      details_json     clob,
      created_at       timestamp with time zone default systimestamp not null,
      updated_at       timestamp with time zone,
      started_at       timestamp with time zone,
      ended_at         timestamp with time zone,
      constraint run_steps_pk primary key (run_id, step_key),
      constraint run_steps_status_ck check (status in ('PENDING','RUNNING','FAILED','SUCCEEDED','SKIPPED')),
      constraint run_steps_details_json_is_json check (details_json is json),
      constraint run_steps_run_fk foreign key (run_id) references runs(run_id) on delete cascade
    )
  ]');

  -- Indexes for common operator queries
  exec_ddl('create index runs_tenant_id_ix on runs(tenant_id)');
  exec_ddl('create index runs_status_ix on runs(status)');
  exec_ddl('create index runs_created_at_ix on runs(created_at)');
  exec_ddl('create index run_steps_status_ix on run_steps(status)');
  exec_ddl('create index run_steps_updated_at_ix on run_steps(updated_at)');

  commit;
end;
/

prompt Done.

