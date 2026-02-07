#!/usr/bin/env bash
set -euo pipefail

# Expects environment variables:
#   SQLCL_CONNECT   - connection string for ADB schema owning APEX app
#   APEX_APP_EXPORT - path to /apex directory containing exports (fXXXX.sql)

echo "[deploy_apex_app] Starting APEX deployment"

if [[ -z "${SQLCL_CONNECT:-}" ]]; then
  echo "SQLCL_CONNECT is not set" >&2
  exit 1
fi

APEX_APP_EXPORT="${APEX_APP_EXPORT:-$(pwd)/apex}"
if [[ ! -d "$APEX_APP_EXPORT" ]]; then
  echo "APEX export directory not found: $APEX_APP_EXPORT" >&2
  exit 1
fi

for export_file in "$APEX_APP_EXPORT"/f*.sql; do
  echo "Importing $export_file"
  sql "$SQLCL_CONNECT" @"$export_file"
done

echo "[deploy_apex_app] Completed"