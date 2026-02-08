-- Demo Factory - Reset API (DB-004) - INLINE VERSION
-- Schema: DEMO_FACTORY_ADMIN
--
-- Browser-safe installer for PKG_DEMO_FACTORY_RESET.
-- Notes:
-- - Reset is allowlist-based.
-- - Cross-schema clearing/seeding may be SKIPPED on ORA-01031, to be completed later via admin-controlled steps.

set define off

create or replace package pkg_demo_factory_reset as
  procedure reset_tenant(
    p_run_id      in varchar2,
    p_schema_name in varchar2
  );
end pkg_demo_factory_reset;
/

create or replace package body pkg_demo_factory_reset as

  function q_ident(p_name in varchar2) return varchar2 is
  begin
    return upper(dbms_assert.simple_sql_name(trim(p_name)));
  end;

  function user_exists(p_username in varchar2) return boolean is
    l_cnt number;
  begin
    select count(*) into l_cnt from all_users where username = upper(p_username);
    return l_cnt > 0;
  end;

  function table_exists(p_owner in varchar2, p_table in varchar2) return boolean is
    l_cnt number;
  begin
    select count(*) into l_cnt
    from all_tables
    where owner = upper(p_owner)
      and table_name = upper(p_table);
    return l_cnt > 0;
  end;

  procedure ensure_baseline(p_owner in varchar2) is
  begin
    if not table_exists(p_owner, 'DF_HEALTHCHECK') then
      execute immediate
        'create table ' || p_owner || '.DF_HEALTHCHECK (' ||
        '  id varchar2(36) default rawtohex(sys_guid()) not null,' ||
        '  created_at timestamp with time zone default systimestamp not null,' ||
        '  note varchar2(4000),' ||
        '  constraint df_healthcheck_pk primary key (id)' ||
        ')';
    end if;
  end;

  procedure clear_objects(p_owner in varchar2) is
  begin
    if table_exists(p_owner, 'DF_HEALTHCHECK') then
      execute immediate 'delete from ' || p_owner || '.DF_HEALTHCHECK';
    end if;
  end;

  procedure seed_baseline(p_owner in varchar2) is
    l_note varchar2(4000);
  begin
    l_note := 'reset seed @ ' || to_char(systimestamp, 'YYYY-MM-DD"T"HH24:MI:SS.FF3 TZH:TZM');
    execute immediate 'insert into ' || p_owner || '.DF_HEALTHCHECK (note) values (:1)'
      using l_note;
  end;

  procedure reset_tenant(
    p_run_id      in varchar2,
    p_schema_name in varchar2
  ) is
    l_schema    varchar2(128);
    l_tenant_id varchar2(36);
    l_status    varchar2(30);
  begin
    if p_run_id is null then
      raise_application_error(-20110, 'p_run_id is required');
    end if;
    if p_schema_name is null then
      raise_application_error(-20111, 'p_schema_name is required');
    end if;

    l_schema := q_ident(p_schema_name);

    pkg_demo_factory_runs.step_started(p_run_id, 'RESET:VALIDATE', 'Validate tenant and schema');

    select tenant_id, status
      into l_tenant_id, l_status
      from tenants
     where schema_name = l_schema;

    if l_status = 'DROPPED' then
      raise_application_error(-20112, 'Tenant is DROPPED: ' || l_schema);
    end if;

    if not user_exists(l_schema) then
      raise_application_error(-20113, 'Tenant DB user does not exist: ' || l_schema);
    end if;

    pkg_demo_factory_runs.step_succeeded(p_run_id, 'RESET:VALIDATE', 'OK');

    pkg_demo_factory_runs.step_started(p_run_id, 'RESET:ENSURE_BASELINE', 'Ensure baseline objects exist');
    ensure_baseline(l_schema);
    pkg_demo_factory_runs.step_succeeded(p_run_id, 'RESET:ENSURE_BASELINE', 'OK');

    pkg_demo_factory_runs.step_started(p_run_id, 'RESET:CLEAR_OBJECTS', 'Delete allowlisted tenant data');
    begin
      clear_objects(l_schema);
      pkg_demo_factory_runs.step_succeeded(p_run_id, 'RESET:CLEAR_OBJECTS', 'OK');
    exception
      when others then
        if sqlcode in (-1031, -41900) then
          pkg_demo_factory_runs.step_skipped(p_run_id, 'RESET:CLEAR_OBJECTS', 'Skipped (insufficient privileges): ' || sqlerrm);
        else
          raise;
        end if;
    end;

    pkg_demo_factory_runs.step_started(p_run_id, 'RESET:SEED_BASELINE', 'Seed baseline data');
    begin
      seed_baseline(l_schema);
      pkg_demo_factory_runs.step_succeeded(p_run_id, 'RESET:SEED_BASELINE', 'OK');
    exception
      when others then
        if sqlcode in (-1031, -41900) then
          pkg_demo_factory_runs.step_skipped(p_run_id, 'RESET:SEED_BASELINE', 'Skipped (insufficient privileges): ' || sqlerrm);
        else
          raise;
        end if;
    end;

    update tenants set updated_at = systimestamp where tenant_id = l_tenant_id;

    pkg_demo_factory_runs.step_succeeded(p_run_id, 'RESET:DONE', 'Reset complete');

    commit;

  exception
    when no_data_found then
      begin
        pkg_demo_factory_runs.step_failed(p_run_id, 'RESET:VALIDATE', 'Tenant not found for schema ' || p_schema_name);
        pkg_demo_factory_runs.set_run_status(p_run_id, 'FAILED', null, 'Tenant not found for schema ' || p_schema_name);
      exception when others then null; end;
      raise;
    when others then
      begin
        pkg_demo_factory_runs.step_failed(p_run_id, 'RESET:ERROR', sqlerrm);
        pkg_demo_factory_runs.set_run_status(p_run_id, 'FAILED', null, sqlerrm);
      exception when others then null; end;
      raise;
  end;

end pkg_demo_factory_reset;
/

select name, type, line, position, text
from user_errors
where name = 'PKG_DEMO_FACTORY_RESET'
order by sequence;

prompt Done.

