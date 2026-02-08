-- Demo Factory - Run/Step API (DB-002)
-- Schema: DEMO_FACTORY_ADMIN
--
-- Installs the run/step package used by APEX, ORDS, and n8n.

set define off
set serveroutput on

prompt Installing pkg_demo_factory_runs...

@D:\Demo_Factory\db\control\packages\pkg_demo_factory_runs.pks
show errors package pkg_demo_factory_runs

@D:\Demo_Factory\db\control\packages\pkg_demo_factory_runs.pkb
show errors package body pkg_demo_factory_runs

prompt Done.

