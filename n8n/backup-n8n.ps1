[CmdletBinding()]
param(
  # Where backups are written locally
  [string]$OutputDir = (Join-Path $PSScriptRoot 'backups'),
  [int]$KeepDays = 14,

  # Where the n8n docker compose project lives (docker-compose.yml + .env + data/).
  [string]$ComposeDir = $env:N8N_COMPOSE_DIR,

  # OCI Object Storage upload settings
  [string]$OciNamespace = $env:OCI_NAMESPACE,
  [string]$OciBucket = $env:OCI_BUCKET,
  [string]$OciPrefix = $(if ($env:OCI_PREFIX) { $env:OCI_PREFIX } else { 'n8n-backups' }),

  # Optional: override Object Storage endpoint/realm (useful for non-oraclecloud.com realms)
  # Example: https://<namespace>.objectstorage.<region>.oci.customer-oci.com
  [string]$OciEndpoint = $env:OCI_OS_ENDPOINT
)

$ErrorActionPreference = 'Stop'

function Require-Cmd([string]$name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $name"
  }
}

Require-Cmd docker

# Locate oci.exe in a way that still works under Task Scheduler where PATH can differ
$ociExe = $null
$ociCmd = Get-Command oci -ErrorAction SilentlyContinue
if ($ociCmd) {
  $ociExe = $ociCmd.Source
} else {
  $knownOci = @(
    'C:\Program Files\Oracle\oci-cli\oci.exe',
    'C:\Program Files (x86)\Oracle\oci_cli\oci.exe'
  )
  foreach ($p in $knownOci) {
    if (Test-Path $p) { $ociExe = $p; break }
  }
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Compose dir detection
if (-not $ComposeDir) {
  $default = 'D:\n8n'
  if (Test-Path (Join-Path $default 'docker-compose.yml')) { $ComposeDir = $default }
}
if (-not $ComposeDir) {
  throw 'ComposeDir not provided and could not be auto-detected. Pass -ComposeDir or set N8N_COMPOSE_DIR.'
}

$envFile = Join-Path $ComposeDir '.env'
if (-not (Test-Path $envFile)) {
  throw "Missing env file: $envFile"
}

$pgDumpPath = Join-Path $OutputDir "postgres-$ts.sql"
$n8nZipPath = Join-Path $OutputDir "n8n-data-$ts.zip"

Write-Host "Backing up Postgres to $pgDumpPath"
Push-Location $ComposeDir
try {
  docker compose --env-file $envFile exec -T postgres sh -lc 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | Out-File -FilePath $pgDumpPath -Encoding utf8

  Write-Host "Backing up n8n data dir to $n8nZipPath"
  $n8nDataDir = Join-Path $ComposeDir 'data\n8n'
  if (-not (Test-Path $n8nDataDir)) {
    throw "Missing n8n data dir: $n8nDataDir"
  }
  if (Test-Path $n8nZipPath) { Remove-Item -Force $n8nZipPath }
  Compress-Archive -Path (Join-Path $n8nDataDir '*') -DestinationPath $n8nZipPath
}
finally {
  Pop-Location
}

# Local retention
Get-ChildItem -Path $OutputDir -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$KeepDays) } | Remove-Item -Force

# Optional OCI upload + remote retention
if ($ociExe -and $OciNamespace -and $OciBucket) {
  Write-Host "Uploading backups to OCI Object Storage bucket '$OciBucket' (namespace '$OciNamespace')"
  $endpointArgs = @()
  if ($OciEndpoint) { $endpointArgs = @('--endpoint', $OciEndpoint) }

  $objects = @(
    @{ File = $pgDumpPath; Name = "$OciPrefix/postgres-$ts.sql" },
    @{ File = $n8nZipPath; Name = "$OciPrefix/n8n-data-$ts.zip" }
  )

  foreach ($o in $objects) {
    & $ociExe os object put @endpointArgs --namespace-name $OciNamespace --bucket-name $OciBucket --file $o.File --name $o.Name --force | Out-Null
  }

  # Remote retention based on timestamp in object name
  $cutoff = (Get-Date).AddDays(-$KeepDays)
  $listJson = & $ociExe os object list @endpointArgs --namespace-name $OciNamespace --bucket-name $OciBucket --prefix "$OciPrefix/" --all --output json
  $resp = $null
  try { $resp = $listJson | ConvertFrom-Json } catch { $resp = $null }

  $items = @()
  if ($resp -and $resp.data) {
    if ($resp.data.objects) { $items = $resp.data.objects }
    elseif ($resp.data -is [System.Collections.IEnumerable]) { $items = $resp.data }
  }

  $rx = [regex]'-(\d{8}-\d{6})\.'
  foreach ($it in $items) {
    $name = $it.name
    if (-not $name) { continue }
    $m = $rx.Match($name)
    if (-not $m.Success) { continue }

    $dt = $null
    try { $dt = [datetime]::ParseExact($m.Groups[1].Value, 'yyyyMMdd-HHmmss', $null) } catch { $dt = $null }
    if (-not $dt) { continue }
    if ($dt -ge $cutoff) { continue }

    Write-Host "Deleting remote old backup object: $name"
    & $ociExe os object delete @endpointArgs --namespace-name $OciNamespace --bucket-name $OciBucket --name $name --force | Out-Null
  }
}
elseif ($OciNamespace -or $OciBucket) {
  Write-Warning 'OCI_NAMESPACE/OCI_BUCKET provided but OCI CLI not found. Skipping upload.'
}

Write-Host 'Backup complete.'



