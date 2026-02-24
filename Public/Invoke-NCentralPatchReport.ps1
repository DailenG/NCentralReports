<#
.SYNOPSIS
    Generates an HTML patch management report from N-Central monitored-service data.

.DESCRIPTION
    Authenticates against the N-Central REST API, enumerates devices matching any scope
    filters provided, fetches Patch Status v2 service states for each device, and for
    every degraded device follows the appliance-tasks endpoint to extract the human-readable
    PME error message. Results are rendered as a self-contained PSWriteHTML dashboard.

    Requires the PSWriteHTML module:
        Install-Module PSWriteHTML -Scope CurrentUser

    Set your JWT via the environment variable to avoid passing it on the command line:
        $env:NCentral_JWT = 'eyJ...'

.PARAMETER ServerFQDN
    Hostname of the N-Central server (no protocol prefix).
    Defaults to 'n-central.example.com'.

.PARAMETER JWT
    Long-lived JWT token from N-Central Admin > User Management > API Access.
    Defaults to $env:NCentral_JWT.

.PARAMETER CustomerName
    Partial match on customer name (case-insensitive). Leave blank for all customers.

.PARAMETER CustomerId
    Exact customer ID. Takes precedence over CustomerName for device queries.

.PARAMETER SiteName
    Partial match on site name. Leave blank for all sites within matched customers.

.PARAMETER SiteId
    Exact site ID. Takes precedence over SiteName for device queries.

.PARAMETER DeviceName
    Partial match applied client-side on device hostname/name.

.PARAMETER StatusFilter
    Limit the report to 'Failed', 'Warning', or 'All' (default) patch states.

.PARAMETER OutputPath
    File path for the generated HTML report.
    Defaults to .\NCentral-PatchReport-<timestamp>.html

.PARAMETER NoShow
    If specified, the HTML report file is created but not opened in the default browser.

.PARAMETER PageSize
    Items per page for paginated API calls. Reduce to 50 for very large environments.
    Defaults to 100.

.PARAMETER IncludeHealthy
    Include healthy (Normal state) devices in the 'All Devices' report tab.
    Without this switch the All Devices tab only shows devices that had patch services checked.

.EXAMPLE
    # Full environment report, open in browser
    .\Invoke-NCentralPatchReport.ps1

.EXAMPLE
    # One customer, failed devices only
    .\Invoke-NCentralPatchReport.ps1 -CustomerName "Acme Corp" -StatusFilter Failed

.EXAMPLE
    # Specific site, save without opening browser
    .\Invoke-NCentralPatchReport.ps1 -SiteId 42 -NoShow -OutputPath "C:\Reports\patch.html"

.EXAMPLE
    # Verbose output to confirm API field names on first run
    .\Invoke-NCentralPatchReport.ps1 -CustomerName "Acme" -Verbose

.NOTES
    See AGENTS.md for API field-name assumptions that must be verified on first run.
    See README.md for full documentation.
#>
function Invoke-NCentralPatchReport {
    [CmdletBinding()]
    param(
        [string]$ServerFQDN = 'n-central.example.com',

        [string]$JWT = $env:NCentral_JWT,

        # Scope filters
        [string]$CustomerName = '',
        [int]$CustomerId = 0,
        [string]$SiteName = '',
        [int]$SiteId = 0,
        [string]$DeviceName = '',

        # Status filter
        [ValidateSet('All', 'Failed', 'Warning')]
        [string]$StatusFilter = 'All',

        # Output
        [string]$OutputPath = ".\NCentral-PatchReport-$(Get-Date -Format 'yyyy-MM-dd-HHmm').html",
        [switch]$NoShow,

        # Tuning
        [switch]$IncludeHealthy
    )

    $ErrorActionPreference = 'Stop'

    # ── Step 0: Validate prerequisites ────────────────────────────────────────────

    if ([string]::IsNullOrWhiteSpace($JWT)) {
        throw "No JWT provided. Set `$env:NCentral_JWT or pass -JWT. " +
        "Generate a JWT from N-Central Administration > User Management > API Access."
    }


    # ── Step 0: Validate prerequisites ────────────────────────────────────────────

    $baseUri = "https://$ServerFQDN"
    Write-Host "N-Central Patch Management Report" -ForegroundColor Cyan
    Write-Host "Server : $ServerFQDN"
    Write-Host "Scope  : $(if ($CustomerName) { "Customer='$CustomerName'" } elseif ($CustomerId) { "CustomerId=$CustomerId" } else { 'All customers' })"

    # ── Step 1: Authenticate ───────────────────────────────────────────────────────

    Write-Host "`nAuthenticating..." -ForegroundColor Yellow
    $accessToken = Get-NCAccessToken -ServerFQDN $ServerFQDN -JWT $JWT
    $headers = @{ Authorization = "Bearer $accessToken" }
    Write-Host "  Access token obtained." -ForegroundColor Green

    # ── Step 2: Resolve scope — customers and sites ────────────────────────────────

    Write-Host "`nResolving scope..." -ForegroundColor Yellow

    # Determine which customer IDs to enumerate
    $targetCustomerIds = @()

    if ($CustomerId -gt 0) {
        # Exact ID provided — use directly
        $targetCustomerIds = @($CustomerId)
        Write-Host "  Using exact customer ID: $CustomerId"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($CustomerName)) {
        # Partial name match
        $customers = Get-NCCustomers -BaseUri $baseUri -Headers $headers
        $matched = @($customers | Where-Object {
                $_.customerName -like "*$CustomerName*" -or
                $_.name -like "*$CustomerName*"
            })
        if ($matched.Count -eq 0) {
            Write-Warning "No customers matched '$CustomerName'. Proceeding with all customers."
        }
        else {
            $targetCustomerIds = @($matched | ForEach-Object { $_.customerId ?? $_.id })
            Write-Host "  Matched $($matched.Count) customer(s): $(($matched | ForEach-Object { $_.customerName ?? $_.name }) -join ', ')"
        }
    }
    else {
        Write-Host "  No customer filter — enumerating all devices."
    }

    # Determine target site IDs (used for filtering devices client-side when needed)
    $targetSiteIds = @()
    if ($SiteId -gt 0) {
        $targetSiteIds = @($SiteId)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($SiteName)) {
        # Fetch sites for matched customers (or all if no customer filter)
        $customerIdsForSites = if ($targetCustomerIds.Count -gt 0) { $targetCustomerIds } else {
            # Fetch all customers to get their IDs
            $allCustomers = Get-NCCustomers -BaseUri $baseUri -Headers $headers
            @($allCustomers | ForEach-Object { $_.customerId ?? $_.id })
        }
        foreach ($cId in $customerIdsForSites) {
            $sites = Get-NCSites -BaseUri $baseUri -Headers $headers -CustomerId $cId
            $matchedSites = @($sites | Where-Object {
                    $_.siteName -like "*$SiteName*" -or
                    $_.name -like "*$SiteName*"
                })
            $targetSiteIds += @($matchedSites | ForEach-Object { $_.siteId ?? $_.id })
        }
        Write-Host "  Site filter '$SiteName' matched $($targetSiteIds.Count) site(s)."
    }

    # ── Step 3: Enumerate devices ──────────────────────────────────────────────────

    Write-Host "`nEnumerating devices..." -ForegroundColor Yellow

    $allDevices = @()

    if ($targetCustomerIds.Count -gt 0) {
        # Send the batch of Target Customer IDs natively to the new 'select' expression
        $allDevices = Get-NCDevices -BaseUri $baseUri -Headers $headers `
            -CustomerIds $targetCustomerIds -DeviceNameFilter $DeviceName
    }
    else {
        $allDevices = Get-NCDevices -BaseUri $baseUri -Headers $headers `
            -DeviceNameFilter $DeviceName
    }

    # Apply site filter client-side if needed
    if ($targetSiteIds.Count -gt 0) {
        $before = $allDevices.Count
        $allDevices = @($allDevices | Where-Object {
                ($_.siteId ?? $_.locationId ?? $_.site) -in $targetSiteIds
            })
        Write-Host "  Site filter reduced $before → $($allDevices.Count) devices."
    }

    Write-Host "  Total devices to scan: $($allDevices.Count)" -ForegroundColor Cyan

    if ($allDevices.Count -eq 0) {
        Write-Warning "No devices found matching the provided filters. Report will be empty."
    }

    # ── Step 4: Collect patch service data for each device ─────────────────────────

    Write-Host "`nScanning patch services..." -ForegroundColor Yellow

    $reportRows = [System.Collections.Generic.List[PSCustomObject]]::new()
    $deviceCount = 0
    $issueCount = 0
    $total = $allDevices.Count

    foreach ($device in $allDevices) {
        $deviceCount++

        # Extract device properties — strictly typed from Get-NCDevices
        $deviceId = $device.DeviceId
        $deviceName = $device.DeviceName
        $custName = $device.CustomerName
        $siteName = $device.SiteName

        # Progress indicator
        $percent = [math]::Round(($deviceCount / $total) * 100)
        Write-Progress -Activity "Scanning Devices for Patch Status" -Status "Device $deviceCount of $total ($percent%) : $deviceName" -PercentComplete $percent

        # Fetch degraded patch services using the new endpoint
        $patchServices = Get-NCServiceMonitorStatus -BaseUri $baseUri -Headers $headers -DeviceId $deviceId

        if ($null -eq $patchServices -or @($patchServices).Count -eq 0) {
            # Device is healthy (no degraded patch services)
            if ($IncludeHealthy) {
                $reportRows.Add([PSCustomObject]@{
                        DeviceName         = $deviceName
                        CustomerName       = $custName
                        SiteName           = $siteName
                        ServiceState       = 'Normal'
                        PMEThresholdStatus = 'N/A'
                        PMEStatus          = 'N/A'
                        LastChecked        = $null
                        PatchState         = 'Normal'
                        DeviceId           = $deviceId
                    })
            }
            continue
        }

        # Device has degraded patch services — fetch task details for each
        foreach ($svc in $patchServices) {
            $issueCount++

            $serviceState = $svc.StateStatus
            $lastChecked = $null

            # Extract task ID — strictly mapped from Get-NCServiceMonitorStatus
            $taskId = [string]$svc.TaskId

            $pmeStatus = 'N/A'
            $pmeThresholdStatus = 'N/A'

            if (-not [string]::IsNullOrWhiteSpace($taskId)) {
                Write-Verbose "  Fetching appliance task $taskId for device $deviceName"
                $taskObj = Get-NCApplianceTask -BaseUri $baseUri -Headers $headers -TaskId $taskId

                if ($null -ne $taskObj) {
                    $details = Get-NCPatchDetails -TaskObject $taskObj
                    $pmeStatus = $details.PMEStatus
                    $pmeThresholdStatus = $details.PMEThresholdStatus
                }
                else {
                    Write-Verbose "  Task $taskId not found for device $deviceName"
                }
            }
            else {
                Write-Verbose "  No taskId on service object for device $deviceName — cannot fetch PME details"
            }

            $reportRows.Add([PSCustomObject]@{
                    DeviceName         = $deviceName
                    CustomerName       = $custName
                    SiteName           = $siteName
                    ServiceState       = $serviceState
                    PMEThresholdStatus = $pmeThresholdStatus
                    PMEStatus          = $pmeStatus
                    LastChecked        = $lastChecked
                    PatchState         = $serviceState
                    DeviceId           = $deviceId
                })
        }
    }

    Write-Host "  Scan complete. Devices with issues: $issueCount / $deviceCount" -ForegroundColor Cyan

    # ── Step 5: Apply status filter ────────────────────────────────────────────────

    $filteredRows = @($reportRows)

    if ($StatusFilter -ne 'All') {
        $filteredRows = @($filteredRows | Where-Object { $_.ServiceState -eq $StatusFilter })
        Write-Host "  Status filter '$StatusFilter' applied: $($filteredRows.Count) rows remaining."
    }

    # ── Step 6: Generate report ────────────────────────────────────────────────────

    Write-Host "`nGenerating HTML report..." -ForegroundColor Yellow

    New-PatchManagementReport -ReportData $filteredRows `
        -OutputPath $OutputPath `
        -TotalDevicesScanned $deviceCount

    $resolvedPath = Resolve-Path $OutputPath -ErrorAction SilentlyContinue
    if (-not $resolvedPath) { $resolvedPath = $OutputPath }

    Write-Host "  Report saved: $resolvedPath" -ForegroundColor Green

    # ── Step 7: Open report ────────────────────────────────────────────────────────

    if (-not $NoShow) {
        Write-Host "  Opening report in default browser..." -ForegroundColor Yellow
        Start-Process $resolvedPath
    }

    Write-Host "`nDone." -ForegroundColor Green
}
