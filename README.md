# N-Central Patch Management Report Tool

Generates a self-contained Excel spreadsheet (or HTML dashboard) showing Windows patch health across all devices
monitored by N-Central (N-able), with drill-down into PME (Patch Management Engine) error
messages.

---

## Prerequisites

**PowerShell 5.1 or 7+**

**ImportExcel module (Required):**
```powershell
Install-Module ImportExcel -Scope CurrentUser
```

**PSWriteHTML module (Optional for `-ExportHTML`):**
```powershell
Install-Module PSWriteHTML -Scope CurrentUser
```

**Mailozaurr module (Optional for `-SendEmail`):**
```powershell
Install-Module Mailozaurr -Scope CurrentUser
```

**N-Central JWT token** — generate from your N-Central portal under
*Administration → User Management → API Access*.

---

## Quick Start

```powershell
# Import the module
Import-Module .\NCentralReports.psd1 -Force

# No need to set environment variables or pass credentials!
# The first time you run the report with email enabled, it will quickly securely prompt
# for your SMTP server, sender address, and email credentials, saving them locally alongside
# the N-Central JWT.

# Run against all devices, generate Excel, open on completion
Invoke-NCentralPatchReport

# Legacy HTML format instead of Excel
Invoke-NCentralPatchReport -ExportHTML

# Run, generate Excel, don't open browser, and email to me (uses saved config)
Invoke-NCentralPatchReport -CustomerName "Acme Corp" -StatusFilter Failed -NoShow -SendEmail -SendTo "admin@dailen.net"

# Fully automated execution (bypasses config prompt by optionally supplying all details)
Invoke-NCentralPatchReport -NoShow -SendEmail -SendTo "admin@dailen.net" `
    -SmtpServer "smtp.example.com" -Port 587 -SkipCertificateValidation `
    -SmtpFrom "reports@example.com" -SmtpUsername "user" -SmtpPassword "plaintext_pass!"
```

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `ServerFQDN` | string | _(prompt)_ | N-Central server hostname (skip to trigger prompt) |
| `JWT` | string | _(prompt)_ | JWT token for authentication (skip to trigger prompt) |
| `CustomerName` | string | _(all)_ | Partial match on customer name |
| `CustomerId` | int | _(all)_ | Exact customer ID |
| `SiteName` | string | _(all)_ | Partial match on site name |
| `SiteId` | int | _(all)_ | Exact site ID |
| `DeviceName` | string | _(all)_ | Partial match on device name |
| `StatusFilter` | All/Failed/Warning | `All` | Filter report rows by patch state |
| `OutputPath` | string | auto-named .xlsx | Where to save the exported report |
| `NoShow` | switch | _(off)_ | Don't open the file/browser after generating |
| `ExportHTML` | switch | _(off)_ | Generate the legacy HTML visualization via PSWriteHTML instead of an Excel sheet |
| `IncludeHealthy` | switch | _(off)_ | Include healthy devices in the All Devices tab |
| `SendEmail` | switch | _(off)_ | Triggers emailing the generated document via Mailozaurr |
| `SendTo` | string[] | | Recipient email addresses. Required if `-SendEmail` used. |
| `SmtpServer` | string | | Override for SMTP Server hostname or IP |
| `SmtpFrom` | string | | Override for Sender email address |
| `SmtpUsername` | string | | Override for SMTP Username |
| `SmtpPassword` | string | | Override for SMTP Password (plaintext) |
| `Port` | int | | Override for SMTP Port |
| `SkipCertificateValidation` | switch | _(off)_ | Ignore SMTP server SSL/TLS certificate errors |

---

## Report Tabs

| Tab | Contents |
|---|---|
| **Overview** | KPI cards (devices scanned, issues, healthy %), donut chart of PME status distribution, bar chart of issues by customer, top-10 recent issues table |
| **PME Issues** | Full table of affected devices with red/amber row highlighting; Excel/CSV/PDF export buttons |
| **Error Catalog** | Unique PME error messages ranked by frequency with affected device names |
| **All Devices** | Complete device list with patch state (requires `-IncludeHealthy` for full population) |

---

## Publishing

### Publishing to PSGallery
The module includes a `publish.ps1` helper script modeled for standard PSGallery drops.
```powershell
.\publish.ps1 -ApiKey "oy2..."
```

---

## How It Works

1. Authenticates using your JWT to obtain a short-lived Bearer access token.
2. Enumerates customers → sites → devices (respecting any scope filters).
3. For each device, fetches monitored-service states from `/api/devices/{id}/monitored-services`.
4. Filters for "Patch Status v2" services that are in a degraded state.
5. For each degraded service, calls `/api/appliance-tasks/{taskId}` to get the PME error detail.
6. Aggregates all results and renders a PSWriteHTML report.

---

## Troubleshooting

**401 Unauthorized** — Your JWT has expired. Generate a new one from the N-Central portal.

**Empty report / no devices found** — Run with `-Verbose` to see raw API responses and
confirm pagination is working. Check that your JWT has permissions to read device data.

**429 Rate Limited** — The tool automatically backs off and retries up to 3 times before failing aggressively to protect your threshold limits.

**Strict OpenAPI Architecture** — This module strictly adheres to the official `ncentral-openapi-spec.json` definitions. All properties, mapping, and payload bindings are 100% typed. If you encounter missing fields, ensure your N-Central server is updated to the latest REST API schema.

---

## File Structure

```
NCentralReports/
├── NCentralReports.psd1           Module manifest
├── NCentralReports.psm1           Dynamic module loader
├── publish.ps1                    PSGallery publishing script
├── Private/
│   ├── ApiHelpers.ps1             Pagination + retry/backoff
│   └── Get-NCOrganizations.ps1    Customer and site lists
└── Public/
    ├── Invoke-NCentralPatchReport.ps1  Main entry point function
    ├── Get-NCDevices.ps1               Device enumeration
    ├── Get-NCServiceMonitorStatus.ps1  Per-device patch service states
    ├── Get-NCApplianceTask.ps1         Fetch appliance task details
    ├── Get-NCPatchDetails.ps1          Extract PME status fields
    └── New-PatchManagementReport.ps1   PSWriteHTML report builder
```
