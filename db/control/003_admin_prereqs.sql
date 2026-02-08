-- Demo Factory - DB-003 - One-time ADMIN prerequisites
-- Run as ADMIN (or equivalent) in the Autonomous Database.
-- Purpose: allow DEMO_FACTORY_ADMIN to provision tenant schemas/users with required capabilities.

set define off
set serveroutput on

declare
  procedure try_exec(p_sql in varchar2) is
  begin
    execute immediate p_sql;
    dbms_output.put_line('OK: ' || p_sql);
  exception
    when others then
      dbms_output.put_line('WARN: ' || p_sql || ' -> ' || sqlerrm);
  end;
begin
  -- Tenant user lifecycle
  try_exec('grant create user to DEMO_FACTORY_ADMIN');
  try_exec('grant alter user to DEMO_FACTORY_ADMIN');
  try_exec('grant drop user to DEMO_FACTORY_ADMIN');

  -- Allow DEMO_FACTORY_ADMIN to grant roles to tenant users
  try_exec('grant grant any role to DEMO_FACTORY_ADMIN');

  -- "Unlimited" storage intent (also handled via ALTER USER quota unlimited on DATA in the provision package)
  try_exec('grant unlimited tablespace to DEMO_FACTORY_ADMIN');

  -- Create objects in tenant schemas (MVP convenience)\r\n  try_exec('grant any object privilege to DEMO_FACTORY_ADMIN');\r\n  try_exec('grant create any table to DEMO_FACTORY_ADMIN');
  try_exec('grant create any view to DEMO_FACTORY_ADMIN');
  try_exec('grant create any sequence to DEMO_FACTORY_ADMIN');
  try_exec('grant create any procedure to DEMO_FACTORY_ADMIN');
  try_exec('grant create any trigger to DEMO_FACTORY_ADMIN');

  -- ORDS REST enablement\r\n  -- Note: roles are disabled inside definer-rights PL/SQL, so we also try direct EXECUTE grants.\r\n  try_exec('grant ORDS_ADMINISTRATOR_ROLE to DEMO_FACTORY_ADMIN');\r\n  try_exec('grant execute on ORDS_METADATA.ORDS_ADMIN to DEMO_FACTORY_ADMIN');\r\n  try_exec('grant execute on ORDS_ADMIN to DEMO_FACTORY_ADMIN');

  -- Data sharing enablement (best-effort; may be restricted)
  try_exec('grant execute on C##ADP$SERVICE.DBMS_SHARE to DEMO_FACTORY_ADMIN');

  commit;
end;
/

prompt Done.


