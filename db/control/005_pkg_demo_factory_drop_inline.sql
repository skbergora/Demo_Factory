-- Demo Factory - Drop API (DB-004) - INLINE VERSION
-- Schema: DEMO_FACTORY_ADMIN
--
-- Browser-safe installer for PKG_DEMO_FACTORY_DROP.

set define off

create or replace package pkg_demo_factory_drop as
  procedure drop_tenant(
    p_run_id      in varchar2,
    p_schema_name in varchar2
  );
end pkg_demo_factory_drop;
/

create or replace package body pkg_demo_factory_drop as

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

  procedure drop_tenant(
    p_run_id      in varchar2,
    p_schema_name in varchar2
  ) is
    l_schema    varchar2(128);
    l_tenant_id varchar2(36);
  begin
    if p_run_id is null then
      raise_application_error(-20210, 'p_run_id is required');
    end if;
    if p_schema_name is null then
      raise_application_error(-20211, 'p_schema_name is required');
    end if;

    l_schema := q_ident(p_schema_name);

    pkg_demo_factory_runs.step_started(p_run_id, 'DROP:VALIDATE', 'Validate tenant');

    select tenant_id
      into l_tenant_id
      from tenants
     where schema_name = l_schema;

    pkg_demo_factory_runs.step_succeeded(p_run_id, 'DROP:VALIDATE', 'OK');

    pkg_demo_factory_runs.step_started(p_run_id, 'DROP:DROP_USER', 'Drop tenant DB user');

    if user_exists(l_schema) then
      begin
        execute immediate 'drop user ' || l_schema || ' cascade';
        pkg_demo_factory_runs.step_succeeded(p_run_id, 'DROP:DROP_USER', 'User dropped');
      exception
        when others then
          pkg_demo_factory_runs.step_failed(p_run_id, 'DROP:DROP_USER', sqlerrm);
          raise;
      end;
    else
      pkg_demo_factory_runs.step_skipped(p_run_id, 'DROP:DROP_USER', 'User did not exist');
    end if;

    pkg_demo_factory_runs.step_started(p_run_id, 'DROP:UPDATE_TENANT', 'Mark tenant DROPPED');
    update tenants
       set status = 'DROPPED',
           updated_at = systimestamp
     where tenant_id = l_tenant_id;
    pkg_demo_factory_runs.step_succeeded(p_run_id, 'DROP:UPDATE_TENANT', 'OK');

    pkg_demo_factory_runs.step_succeeded(p_run_id, 'DROP:DONE', 'Drop complete');

    commit;

  exception
    when no_data_found then
      begin
        pkg_demo_factory_runs.step_failed(p_run_id, 'DROP:VALIDATE', 'Tenant not found for schema ' || p_schema_name);
        pkg_demo_factory_runs.set_run_status(p_run_id, 'FAILED', null, 'Tenant not found for schema ' || p_schema_name);
      exception when others then null; end;
      raise;
    when others then
      begin
        pkg_demo_factory_runs.step_failed(p_run_id, 'DROP:ERROR', sqlerrm);
        pkg_demo_factory_runs.set_run_status(p_run_id, 'FAILED', null, sqlerrm);
      exception when others then null; end;
      raise;
  end;

end pkg_demo_factory_drop;
/

select name, type, line, position, text
from user_errors
where name = 'PKG_DEMO_FACTORY_DROP'
order by sequence;

prompt Done.
