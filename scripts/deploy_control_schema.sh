#!/usr/bin/env bash
set -euo pipefail

# Expects environment variables already set by pipeline stage:
#   SQLCL_CONNECT  - e.g., "DEMO_FACTORY_ADMIN/password@(description=...)"
#   DB_CONTROL_DIR - path to /db/control directory

echo "[deploy_control_schema] Starting control schema deployment"

if [[ -z "${SQLCL_CONNECT:-}" ]]; then
  echo "SQLCL_CONNECT is not set" >&2
  exit 1
fi

DB_CONTROL_DIR="${DB_CONTROL_DIR:-$(pwd)/db/control}"
if [[ ! -d "$DB_CONTROL_DIR" ]]; then
  echo "Control directory not found: $DB_CONTROL_DIR" >&2
  exit 1
fi

for script in "$DB_CONTROL_DIR"/*.sql; do
  echo "Running $script"
  sql "$SQLCL_CONNECT" @"$script"
done

echo "[deploy_control_schema] Completed"