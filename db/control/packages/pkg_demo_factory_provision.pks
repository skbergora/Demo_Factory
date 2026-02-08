create or replace package pkg_demo_factory_provision authid current_user as
  -- Provisions a tenant database user/schema and registers it in TENANTS.
  -- p_customer_label: human-friendly name (may contain spaces)
  -- p_schema_name:    database username to create (must satisfy Oracle identifier rules)
  -- p_password:       default demo password (also intended to match APEX login password for MVP)
  procedure provision_tenant(
    p_run_id         in varchar2,
    p_customer_label in varchar2,
    p_schema_name    in varchar2,
    p_password       in varchar2 default 'T3st_0raclE_'
  );
end pkg_demo_factory_provision;
/

