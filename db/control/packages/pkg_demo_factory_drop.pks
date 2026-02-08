create or replace package pkg_demo_factory_drop as
  -- Drops a tenant schema/user and marks the tenant as DROPPED.
  procedure drop_tenant(
    p_run_id      in varchar2,
    p_schema_name in varchar2
  );
end pkg_demo_factory_drop;
/
