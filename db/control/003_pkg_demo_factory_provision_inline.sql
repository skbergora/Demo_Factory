-- Demo Factory - Provision API (DB-003) - INLINE VERSION
-- Schema: DEMO_FACTORY_ADMIN
--
-- Use this script when running in browser-based SQL tools (APEX SQL Commands / Database Actions)
-- that cannot access local filesystem paths via @ includes.
--
-- Prereq (one-time): run D:\Demo_Factory\db\control\003_admin_prereqs.sql as ADMIN.

set define off

create or replace package pkg_demo_factory_provision authid current_user as
  procedure provision_tenant(
    p_run_id         in varchar2,
    p_customer_label in varchar2,
    p_schema_name    in varchar2,
    p_password       in varchar2 default 'T3st_0raclE_'
  );
end pkg_demo_factory_provision;
/

create or replace package body pkg_demo_factory_provision as

  function q_ident(p_name in varchar2) return varchar2 is
    l_name varchar2(128) := upper(trim(p_name));
  begin
    if l_name is null then
      raise_application_error(-20012, 'p_schema_name is required');
    end if;
    if length(l_name) > 30 then
      raise_application_error(-20013, 'p_schema_name must be <= 30 characters');
    end if;
    if not regexp_like(l_name, '^[A-Z][A-Z0-9_]*$') then
      raise_application_error(-20014, 'p_schema_name must match ^[A-Z][A-Z0-9_]*$');
    end if;
    return l_name;
  end;

  function q_password(p_pwd in varchar2) return varchar2 is
    l_pwd varchar2(4000) := nvl(p_pwd, '');
  begin
    return '"' || replace(l_pwd, '"', '""') || '"';
  end;

  function user_exists(p_username in varchar2) return boolean is
    l_cnt number;
  begin
    select count(*) into l_cnt from all_users where username = upper(p_username);
    return l_cnt > 0;
  end;

  procedure grant_required(p_username in varchar2, p_role_or_priv in varchar2) is
  begin
    execute immediate 'grant ' || p_role_or_priv || ' to ' || p_username;
  exception
    when others then
      raise_application_error(-20021, 'Required grant failed: ' || p_role_or_priv || ' -> ' || sqlerrm);
  end;

  procedure grant_optional(p_username in varchar2, p_role_or_priv in varchar2) is
  begin
    execute immediate 'grant ' || p_role_or_priv || ' to ' || p_username;
  exception
    when others then
      null;
  end;

  procedure set_quota_unlimited_safe(p_username in varchar2) is
  begin
    execute immediate 'alter user ' || p_username || ' quota unlimited on data';
  exception
    when others then
      null;
  end;

  procedure enable_rest_required(p_schema in varchar2, p_base_path in varchar2) is
    l_plsql clob;
  begin
    l_plsql :=
      'begin ' ||
      '  ORDS_METADATA.ORDS_ADMIN.ENABLE_SCHEMA(' ||
      '    p_enabled => TRUE,' ||
      '    p_schema => :p_schema,' ||
      '    p_url_mapping_type => ''BASE_PATH'',' ||
      '    p_url_mapping_pattern => :p_path,' ||
      '    p_auto_rest_auth => TRUE' ||
      '  );' ||
      '  commit;' || chr(10) ||
      'end;';

    execute immediate l_plsql using p_schema, p_base_path;
  exception
    when others then
      raise;
  end;

  procedure enable_share_required(p_schema in varchar2) is
    l_plsql clob;
  begin
    l_plsql :=
      'begin ' ||
      '  C##ADP$SERVICE.DBMS_SHARE.ENABLE_SCHEMA(' ||
      '    SCHEMA_NAME => :p_schema,' ||
      '    ENABLED => TRUE' ||
      '  );' ||
      '  commit;' || chr(10) ||
      'end;';

    execute immediate l_plsql using p_schema;
  exception
    when others then
      raise;
  end;

  procedure ensure_min_objects(p_username in varchar2) is
  begin
    begin
      execute immediate
        'create table ' || p_username || '.DF_HEALTHCHECK (' ||
        '  id varchar2(36) default rawtohex(sys_guid()) not null,' ||
        '  created_at timestamp with time zone default systimestamp not null,' ||
        '  note varchar2(4000)' ||
        ')';
    exception
      when others then
        if sqlcode = -955 then
          null;
        else
          raise;
        end if;
    end;
  end;

  procedure provision_tenant(
    p_run_id         in varchar2,
    p_customer_label in varchar2,
    p_schema_name    in varchar2,
    p_password       in varchar2 default 'T3st_0raclE_'
  ) is
    l_schema     varchar2(128);
    l_tenant_key varchar2(128);
    l_tenant_id  varchar2(36);
    l_base_path  varchar2(256);
  begin
    if p_run_id is null then
      raise_application_error(-20010, 'p_run_id is required');
    end if;
    if p_customer_label is null then
      raise_application_error(-20011, 'p_customer_label is required');
    end if;

    l_schema := q_ident(p_schema_name);
    l_tenant_key := lower(l_schema);
    l_base_path := lower(l_schema);

    pkg_demo_factory_runs.step_started(p_run_id, 'PROVISION:REGISTER_TENANT', 'Register tenant in TENANTS');

    begin
      insert into tenants(tenant_key, customer_label, schema_name, status, created_at, updated_at)
      values(l_tenant_key, p_customer_label, l_schema, 'ACTIVE', systimestamp, systimestamp)
      returning tenant_id into l_tenant_id;
    exception
      when dup_val_on_index then
        select tenant_id into l_tenant_id from tenants where schema_name = l_schema;
        update tenants
           set customer_label = p_customer_label,
               status = 'ACTIVE',
               updated_at = systimestamp
         where tenant_id = l_tenant_id;
    end;

    update runs set tenant_id = l_tenant_id, updated_at = systimestamp where run_id = p_run_id;

    pkg_demo_factory_runs.step_succeeded(p_run_id, 'PROVISION:REGISTER_TENANT', 'Tenant registered');

    pkg_demo_factory_runs.step_started(p_run_id, 'PROVISION:CREATE_USER', 'Create/verify tenant DB user');

    if not user_exists(l_schema) then
      execute immediate 'create user ' || l_schema || ' identified by ' || q_password(p_password);
    else
      begin
        execute immediate 'alter user ' || l_schema || ' identified by ' || q_password(p_password);
      exception
        when others then
          -- Expected sometimes due to password reuse policy (ORA-28007). Keep going.
          if sqlcode != -28007 then
            raise;
          end if;
      end;
    end if;

    set_quota_unlimited_safe(l_schema);

    pkg_demo_factory_runs.step_succeeded(p_run_id, 'PROVISION:CREATE_USER', 'Tenant user ready: ' || l_schema);

    pkg_demo_factory_runs.step_started(p_run_id, 'PROVISION:GRANTS', 'Granting required roles');

    -- Required (your baseline list)
    grant_required(l_schema, 'CONNECT');
    grant_required(l_schema, 'RESOURCE');
    grant_required(l_schema, 'DWROLE');
    grant_optional(l_schema, 'DW_ROLE');
    grant_required(l_schema, 'CONSOLE_DEVELOPER');
    grant_required(l_schema, 'CTXAPP');
    grant_required(l_schema, 'DCAT_SYNC');
    grant_required(l_schema, 'GRAPH_DEVELOPER');
    grant_required(l_schema, 'OML_DEVELOPER');
    grant_required(l_schema, 'SODA_APP');

    pkg_demo_factory_runs.step_succeeded(p_run_id, 'PROVISION:GRANTS', 'Required roles granted');

    pkg_demo_factory_runs.step_started(p_run_id, 'PROVISION:ENABLE_REST', 'Enable ORDS REST for tenant schema');
    begin
      enable_rest_required(l_schema, l_base_path);
      pkg_demo_factory_runs.step_succeeded(p_run_id, 'PROVISION:ENABLE_REST', 'ORDS REST enabled');
    exception
      when others then
        -- In many ADB environments, ORDS admin packages are not callable from app schemas.
        pkg_demo_factory_runs.step_skipped(p_run_id, 'PROVISION:ENABLE_REST', 'ORDS REST not enabled: ' || sqlerrm);
    end;

    pkg_demo_factory_runs.step_started(p_run_id, 'PROVISION:ENABLE_SHARE', 'Enable Data Sharing for tenant schema');
    begin
      enable_share_required(l_schema);
      pkg_demo_factory_runs.step_succeeded(p_run_id, 'PROVISION:ENABLE_SHARE', 'Data sharing enabled');
    exception
      when others then
        pkg_demo_factory_runs.step_skipped(p_run_id, 'PROVISION:ENABLE_SHARE', 'Data sharing not enabled: ' || sqlerrm);
    end;

    pkg_demo_factory_runs.step_started(p_run_id, 'PROVISION:MIN_OBJECTS', 'Create minimal tenant objects');
    ensure_min_objects(l_schema);
    pkg_demo_factory_runs.step_succeeded(p_run_id, 'PROVISION:MIN_OBJECTS', 'Minimal objects created');

  exception
    when others then
      begin
        pkg_demo_factory_runs.step_failed(p_run_id, 'PROVISION:ERROR', sqlerrm);
        pkg_demo_factory_runs.set_run_status(p_run_id, 'FAILED', null, sqlerrm);
      exception
        when others then null;
      end;
      raise;
  end;

end pkg_demo_factory_provision;
/

select name, type, line, position, text
from user_errors
where name = 'PKG_DEMO_FACTORY_PROVISION'
order by sequence;

prompt Done.








