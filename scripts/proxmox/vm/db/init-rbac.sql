-- Idempotent superuser init script.
--
-- This script's sole entrypoint is init-rbac.sh.
--
-- Requires psql variables:
--   master_db_migrator_pw
--   master_db_app_pw

-- roles
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', 'master_db_migrator', :'master_db_migrator_pw')
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'master_db_migrator') \gexec
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', 'master_db_app', :'master_db_app_pw')
  WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'master_db_app') \gexec

-- databases
SELECT 'CREATE DATABASE wywywebsite OWNER master_db_migrator'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'wywywebsite') \gexec
SELECT 'CREATE DATABASE info OWNER master_db_migrator'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'info') \gexec

-- extensions
\connect wywywebsite
CREATE EXTENSION IF NOT EXISTS postgis;