create or replace package pkg_demo_factory_reset as
  -- Resets a tenant schema to a known-good baseline (does not drop the user).
  procedure reset_tenant(
    p_run_id      in varchar2,
    p_schema_name in varchar2
  );
end pkg_demo_factory_reset;
/
