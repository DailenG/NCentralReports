# N-Central Patch Management Report Tool

Generates a self-contained HTML dashboard showing Windows patch health across all devices
monitored by N-Central (N-able), with drill-down into PME (Patch Management Engine) error
messages.

---

## Prerequisites

**PowerShell 5.1 or 7+**

**PSWriteHTML module:**
```powershell
Install-Module PSWriteHTML -Scope CurrentUser
```

**N-Central JWT token** — generate from your N-Central portal under
*Administration → User Management → API Access*.

---

## Quick Start

```powershell
# Import the module
Import-Module .\NCentralReports.psd1 -Force

# No need to set environment variables or pass credentials!
# The first time you run the report, it will securely prompt you for your
# N-Central Server FQDN and JWT token and save them locally.

# Run against all devices, open HTML on completion
Invoke-NCentralPatchReport

# Filter to one customer, only show failed devices
Invoke-NCentralPatchReport -CustomerName "Acme Corp" -StatusFilter Failed

# Save report without opening browser
Invoke-NCentralPatchReport -NoShow -OutputPath "C:\Reports\patch-$(Get-Date -f 'yyyyMMdd').html"
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
| `OutputPath` | string | auto-named .html | Where to save the HTML report |
| `NoShow` | switch | _(off)_ | Don't open browser after generating |
| `IncludeHealthy` | switch | _(off)_ | Include healthy devices in the All Devices tab |

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
