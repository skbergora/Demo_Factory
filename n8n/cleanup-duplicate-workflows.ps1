[CmdletBinding()]
param(
  # Docker compose project directory for n8n
  [string]$ComposeDir = 'D:\n8n',

  # Optional exact workflow name to dedupe; if omitted, dedupes all names with duplicates
  [string]$NameExact = '',

  # Show what would be deleted but do not delete
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ComposeDir)) {
  throw "ComposeDir not found: $ComposeDir"
}

$filterSql = ''
if ($NameExact) {
  $escaped = $NameExact.Replace("'", "''")
  $filterSql = "WHERE name = '$escaped'"
}

$sql = @"
\set ON_ERROR_STOP on

WITH ranked AS (
  SELECT
    id,
    name,
    "createdAt",
    "updatedAt",
    row_number() OVER (PARTITION BY name ORDER BY "updatedAt" DESC NULLS LAST, "createdAt" DESC) AS rn
  FROM workflow_entity
  $filterSql
),
will_delete AS (
  SELECT id, name, "createdAt", "updatedAt" FROM ranked WHERE rn > 1
)
SELECT * FROM will_delete ORDER BY name, "updatedAt" DESC NULLS LAST, "createdAt" DESC;
"@

Push-Location $ComposeDir
try {
  Write-Host 'Workflows that would be deleted (keeping newest per name):'
  $out = $sql | docker compose exec -T postgres psql -U n8n -d n8n
  $out

  if ($DryRun) {
    Write-Host 'DryRun enabled; no deletes performed.'
    return
  }

  $sqlDelete = @"
\set ON_ERROR_STOP on

WITH ranked AS (
  SELECT
    id,
    name,
    "createdAt",
    "updatedAt",
    row_number() OVER (PARTITION BY name ORDER BY "updatedAt" DESC NULLS LAST, "createdAt" DESC) AS rn
  FROM workflow_entity
  $filterSql
),
will_delete AS (
  SELECT id FROM ranked WHERE rn > 1
)
DELETE FROM workflow_entity
WHERE id IN (SELECT id FROM will_delete)
RETURNING id, name, "createdAt", "updatedAt";
"@

  Write-Host 'Deleting...'
  $delOut = $sqlDelete | docker compose exec -T postgres psql -U n8n -d n8n
  $delOut
}
finally {
  Pop-Location
}

Write-Host 'Done.'
