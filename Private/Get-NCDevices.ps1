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

    if ($CustomerId -gt 0) {
        # Parameter name to confirm at runtime — may be 'customerId', 'organizationId', etc.
        $queryParams['customerId'] = $CustomerId
        Write-Verbose "Filtering devices by customerId=$CustomerId"
    }

    if ($SiteId -gt 0) {
        # Parameter name to confirm at runtime — may be 'siteId', 'locationId', etc.
        $queryParams['siteId'] = $SiteId
        Write-Verbose "Filtering devices by siteId=$SiteId"
    }

    Write-Verbose "Fetching devices from $BaseUri/api/devices"
    $devices = Get-NCPagedResults -BaseUri $BaseUri -Endpoint '/api/devices' `
                                  -Headers $Headers -QueryParams $queryParams

    if ($null -eq $devices -or @($devices).Count -eq 0) {
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
