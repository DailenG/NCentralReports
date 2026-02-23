# AGENTS.md — AI-Agent Development Guide
# N-Central Patch Management Report Tool

## Project Overview

This tool automates the N-Central (N-able) two-hop API pattern to produce a self-contained
HTML dashboard of Windows patch health across all monitored devices.

**The problem it solves:**
N-Central's "Patch Status v2" monitored service only tells you a device is degraded — it does
not tell you *why*. To get the human-readable PME error, you must follow a second call to
`/api/appliance-tasks/{taskId}`. This tool automates that lookup across every device,
aggregates results, and renders a PSWriteHTML report.

**Two-hop pattern:**
```
GET /api/devices/{deviceId}/monitored-services
  → filter for Patch Status v2, state == Degraded/Failed/Warning
  → extract taskId from service object
GET /api/appliance-tasks/{taskId}
  → extract .results[].detailname == 'pme_status'         → human-readable error
  → extract .results[].detailname == 'pme_threshold_status' → threshold context
```

---

## File Map

| File | Purpose |
|---|---|
| `Invoke-NCentralPatchReport.ps1` | Main entry point; orchestrates all steps |
| `Private/Authentication.ps1` | JWT → short-lived Bearer access token |
| `Private/ApiHelpers.ps1` | `Invoke-NCRestMethod` (retry/backoff) + `Get-NCPagedResults` |
| `Private/Get-NCOrganizations.ps1` | List customers and their sites |
| `Private/Get-NCDevices.ps1` | Paginated device enumeration with scope filters |
| `Private/Get-NCMonitoredServices.ps1` | Per-device Patch Status v2 service states |
| `Private/Get-NCApplianceTask.ps1` | Fetch full task object from `/api/appliance-tasks/{id}` |
| `Private/Get-NCPatchDetails.ps1` | Extract pme_status / pme_threshold_status from task object |
| `Reports/New-PatchManagementReport.ps1` | PSWriteHTML report builder |

---

## API Assumptions to Verify at Runtime

These field names are inferred from N-Central documentation and may differ in production.
Each Private/ function emits `Write-Verbose` showing the raw first-object response so you
can confirm field paths live.

| Assumption | Field / Endpoint | Where to confirm |
|---|---|---|
| Auth response path | `.tokens.access.token` | `Authentication.ps1` first run |
| Service taskId field | `.taskId` (may be `.serviceId` or inside details) | `Get-NCMonitoredServices.ps1` |
| Task results array path | `$task.results[].detailname` | `Get-NCPatchDetails.ps1` |
| Customer list endpoint | `GET /api/customers` | `Get-NCOrganizations.ps1` |
| Site list endpoint | `GET /api/customers/{id}/sites` | `Get-NCOrganizations.ps1` |
| Pagination envelope | `.data` items / `.totalItems` count | `ApiHelpers.ps1` first paged call |
| Device endpoint | `GET /api/devices` with `?customerId=` param | `Get-NCDevices.ps1` |

**When you discover the real field name:** update the relevant Private/ function AND add a
note to the "Verified Fields" section at the bottom of this file.

---

## Development Workflow

### Dot-source order (required when testing interactively)
```powershell
. .\Private\Authentication.ps1
. .\Private\ApiHelpers.ps1
. .\Private\Get-NCOrganizations.ps1
. .\Private\Get-NCDevices.ps1
. .\Private\Get-NCMonitoredServices.ps1
. .\Private\Get-NCApplianceTask.ps1
. .\Private\Get-NCPatchDetails.ps1
. .\Reports\New-PatchManagementReport.ps1
```

### Testing individual functions in isolation
```powershell
$env:NCentral_JWT = 'your-jwt-here'
$token  = Get-NCAccessToken -ServerFQDN 'n-central.example.com' -JWT $env:NCentral_JWT
$hdrs   = @{ Authorization = "Bearer $token" }
$base   = 'https://n-central.example.com'

# List first page of devices
Invoke-NCRestMethod -BaseUri $base -Endpoint '/api/devices' -Headers $hdrs -QueryParams @{pageSize=5}

# Get monitored services for device 12345
Get-NCPatchServices -BaseUri $base -Headers $hdrs -DeviceId 12345

# Fetch a specific task
Get-NCApplianceTask -BaseUri $base -Headers $hdrs -TaskId '99999'
```

### Verbose output
Run any function or the main script with `-Verbose` to see raw API responses for the first
object in each call. This is essential for confirming field names.

---

## Extending to Other Service Types

The PME extraction pattern in `Get-NCPatchDetails.ps1` is the template for adding new service
types. To add, for example, "Antivirus Status":

1. Add a filter in `Get-NCMonitoredServices.ps1` for the new service name pattern.
2. Create `Private/Get-NCAVDetails.ps1` modelled on `Get-NCPatchDetails.ps1`.
3. Add a new `$avRows` collection in the orchestrator.
4. Add a new PSWriteHTML tab in `Reports/New-PatchManagementReport.ps1`.

No changes to `ApiHelpers.ps1` or `Authentication.ps1` are needed.

---

## Error Codes Reference

| HTTP Code | Meaning | Handling |
|---|---|---|
| 401 | Bad/expired token | Throw with message "Re-run with a fresh JWT" |
| 404 | Resource not found (device has no services, task doesn't exist) | Return empty / null, log warning |
| 429 | Rate-limited | Exponential back-off: 1s, 2s, 4s, 8s, 16s (max 5 retries) |
| 5xx | Server error | Retry with back-off same as 429; throw after max retries |

---

## Commit Conventions

Use **Conventional Commits** with these scopes:

```
feat(auth):    New authentication functionality
feat(api):     New or changed API helper behaviour
feat(report):  Report generation changes
fix(api):      Bug fix in API calls
fix(report):   Bug fix in report output
chore:         Non-functional changes (gitignore, formatting)
docs:          README, AGENTS.md, inline help
```

Commits should be **atomic** — one logical change per commit. Do not bundle unrelated changes.

---

## Verified Fields (update as you confirm live API responses)

_Empty until first live run. Add entries here in the format:_
`- **fieldName**: confirmed path `$obj.path.to.field` — verified YYYY-MM-DD`
