function Get-NCDevices {
    <#
    .SYNOPSIS
        Returns devices from N-Central, with optional customer/site/name filtering.
    .DESCRIPTION
        Calls GET /api/devices with pagination. If CustomerId or SiteId are provided,
        they are passed as query parameters to server-side filter. DeviceNameFilter
        is applied client-side via -like matching.

        Returns an array of device objects.
    .PARAMETER BaseUri
        Base URL including protocol.
    .PARAMETER Headers
        Hashtable containing Authorization Bearer token.
    .PARAMETER CustomerId
        Filter to a specific customer. 0 = no filter (all customers).
    .PARAMETER SiteId
        Filter to a specific site. 0 = no filter (all sites).
    .PARAMETER DeviceNameFilter
        Optional partial match applied client-side on the device name field.
    .EXAMPLE
        # All devices
        $devices = Get-NCDevices -BaseUri $base -Headers $hdrs

        # Devices for customer 1001
        $devices = Get-NCDevices -BaseUri $base -Headers $hdrs -CustomerId 1001

        # Devices matching a name pattern
        $devices = Get-NCDevices -BaseUri $base -Headers $hdrs -DeviceNameFilter 'PROD-*'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [int]$CustomerId       = 0,
        [int]$SiteId           = 0,
        [string]$DeviceNameFilter = ''
    )

    $queryParams = @{}

    if ($SiteId -gt 0) {
        # Parameter name to confirm at runtime — may be 'siteId', 'locationId', etc.
        $queryParams['siteId'] = $SiteId
        Write-Verbose "Will apply siteId=$SiteId filter"
    }

    # Strategy: try the customer-scoped endpoint first, then fall back to the
    # global endpoint with client-side filtering if the scoped one returns nothing.
    $devices = @()

    if ($CustomerId -gt 0) {
        # Attempt 1 — customer-scoped URL (mirrors the /api/customers/{id}/sites pattern)
        $scopedEndpoint = "/api/customers/$CustomerId/devices"
        Write-Verbose "Attempt 1: customer-scoped endpoint $scopedEndpoint"
        $devices = @(Get-NCPagedResults -BaseUri $BaseUri -Endpoint $scopedEndpoint `
                                        -Headers $Headers -QueryParams $queryParams)

        if ($devices.Count -gt 0) {
            Write-Verbose "  Scoped endpoint returned $($devices.Count) device(s)"
            # Log first device object so customer ID field name can be confirmed
            Write-Verbose "  First device object: $($devices[0] | ConvertTo-Json -Depth 2 -Compress)"
        }
        else {
            # Attempt 2 — global endpoint + client-side filter
            Write-Verbose "  Scoped endpoint returned nothing — falling back to /api/devices with client-side filter"
            $allDevices = @(Get-NCPagedResults -BaseUri $BaseUri -Endpoint '/api/devices' `
                                               -Headers $Headers -QueryParams $queryParams)

            if ($allDevices.Count -gt 0) {
                Write-Verbose "  Global endpoint returned $($allDevices.Count) total device(s)"
                Write-Verbose "  First device object: $($allDevices[0] | ConvertTo-Json -Depth 2 -Compress)"

                # Filter client-side — check all common customer ID field names
                $devices = @($allDevices | Where-Object {
                    ($_.customerId     -eq $CustomerId) -or
                    ($_.organizationId  -eq $CustomerId) -or
                    ($_.clientId        -eq $CustomerId) -or
                    ($_.orgUnitId       -eq $CustomerId) -or
                    ($_.customerUnitId  -eq $CustomerId)
                })

                if ($devices.Count -gt 0) {
                    Write-Verbose "  Client-side filter matched $($devices.Count) device(s) for customerId=$CustomerId"
                }
                else {
                    Write-Warning "Client-side customer filter found no matches for customerId=$CustomerId. " +
                                  "Check the first device object in -Verbose output to find the correct customer ID field name."
                    # Return all devices unfiltered so the report isn't silently empty;
                    # the operator can inspect verbose output to identify the right field.
                    $devices = $allDevices
                }
            }
        }
    }
    else {
        $devices = @(Get-NCPagedResults -BaseUri $BaseUri -Endpoint '/api/devices' `
                                        -Headers $Headers -QueryParams $queryParams)
        Write-Verbose "Global /api/devices returned $($devices.Count) device(s)"
        if ($devices.Count -gt 0) {
            Write-Verbose "First device object: $($devices[0] | ConvertTo-Json -Depth 2 -Compress)"
        }
    }

    if ($devices.Count -eq 0) {
        Write-Warning "No devices returned. Check filters and token permissions."
        return @()
    }

    # Client-side name filter
    if (-not [string]::IsNullOrWhiteSpace($DeviceNameFilter)) {
        # Field name 'deviceName' or 'longName' — confirm via -Verbose first-run output
        $before   = @($devices).Count
        $devices  = @($devices) | Where-Object {
            $_.deviceName -like "*$DeviceNameFilter*" -or
            $_.longName   -like "*$DeviceNameFilter*" -or
            $_.hostname    -like "*$DeviceNameFilter*"
        }
        Write-Verbose "Name filter '$DeviceNameFilter' reduced $before → $(@($devices).Count) devices"
    }

    Write-Verbose "Returning $(@($devices).Count) devices"
    return $devices
}
