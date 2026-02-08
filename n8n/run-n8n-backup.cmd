@echo off
setlocal
set OCI_CLI_REGION=us-chicago-1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\n8n_backups\backup-n8n.ps1" -ComposeDir "D:\n8n" -KeepDays 14 -OciNamespace "orasenatdpublicsector05" -OciBucket "demo-factory-assets" -OciPrefix "backups/n8n" -OciEndpoint "https://orasenatdpublicsector05.objectstorage.us-chicago-1.oci.customer-oci.com"
exit /b %errorlevel%
