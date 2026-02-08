# n8n Backup Ops

Compose/runtime: `D:\n8n`
Backups/scripts: `D:\n8n_backups`

## Run Backup (Local + OCI Upload)

```powershell
$env:OCI_CLI_REGION = 'us-chicago-1'  # optional safety

cd D:\n8n_backups

.\backup-n8n.ps1 `
  -ComposeDir "D:\n8n" `
  -KeepDays 14 `
  -OciNamespace "orasenatdpublicsector05" `
  -OciBucket "demo-factory-assets" `
  -OciPrefix "backups/n8n" `
  -OciEndpoint "https://orasenatdpublicsector05.objectstorage.us-chicago-1.oci.customer-oci.com"
```

Local outputs: `D:\n8n_backups\backups\`
Remote outputs: `demo-factory-assets/backups/n8n/` (object names include the "subfolder" prefix)

## Verify Upload

```powershell
oci os object list `
  --endpoint "https://orasenatdpublicsector05.objectstorage.us-chicago-1.oci.customer-oci.com" `
  --namespace-name orasenatdpublicsector05 `
  --bucket-name demo-factory-assets `
  --prefix "backups/n8n/" `
  --limit 20
```

## Scheduled Daily Backup (10:00 PM Central)

This machine is configured to the `UTC` time zone. 10:00 PM Central (CST, UTC-6) is scheduled as `04:00` UTC.

The scheduled task runs a wrapper to avoid `schtasks` quoting issues:

- `D:\n8n_backups\run-n8n-backup.cmd`

To view:

```powershell
schtasks /Query /TN "n8n backup" /V /FO LIST
```
