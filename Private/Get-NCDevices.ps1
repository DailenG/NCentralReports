function Get-NCDevices {
    <#
    .SYNOPSIS
        Returns devices from N-Central, with optional customer/site/name filtering.
    .DESCRIPTION
        Calls GET /api/devices with pagination. Applies strict schema mapping per OpenAPI specification.
        Returns an array of standardized device objects with known property names.
    .PARAMETER BaseUri
        Base URL including protocol.
    .PARAMETER Headers
        Hashtable containing Authorization Bearer token.
    .PARAMETER CustomerIds
        Filter to a specific customer or array of customers. Empty array = no filter.
    .PARAMETER SiteId
        Filter to a specific site. 0 = no filter (all sites).
    .PARAMETER DeviceNameFilter
        Optional partial match applied client-side on the longName field.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [int[]]$CustomerIds = @(),
        [int]$SiteId = 0,
        [string]$DeviceNameFilter = ''
    )

    $queryParams = @{}

    if ($SiteId -gt 0) {
        # Strict mapping per schema ListResponseSite/Device: siteId
        $queryParams['siteId'] = $SiteId
    }

    if ($CustomerIds.Count -gt 0) {
        # Using the RSQL syntax required by N-Central 'select' filters
        # e.g. customerId=in=(131,132)
        $queryParams['select'] = "customerId=in=($($CustomerIds -join ','))"
    }

    $allDevices = @(Get-NCPagedResults -BaseUri $BaseUri -Endpoint '/api/devices' `
            -Headers $Headers -QueryParams $queryParams)

    # Convert to strict standardized types based on OpenAPI Device schema.
    $devices = [System.Collections.Generic.List[object]]::new()
    foreach ($rawData in $allDevices) {
        $mappedDevice = [PSCustomObject]@{
            DeviceId     = [long]$rawData.deviceId
            DeviceName   = [string]$rawData.longName
            CustomerId   = [long]$rawData.customerId
            CustomerName = [string]$rawData.customerName
            SiteId       = [long]$rawData.siteId
            SiteName     = [string]$rawData.siteName
            OSId         = [string]$rawData.osId
            SupportedOS  = [string]$rawData.supportedOs
        }
        $devices.Add($mappedDevice)
    }

    if ($devices.Count -eq 0) {
        Write-Warning "No devices returned. Check filters and token permissions."
        return @()
    }

    $finalDevices = @($devices)
    if (-not [string]::IsNullOrWhiteSpace($DeviceNameFilter)) {
        # Strict mapping to DeviceName (schema longName)
        $before = $finalDevices.Count
        $finalDevices = $finalDevices | Where-Object {
            $_.DeviceName -like "*$DeviceNameFilter*"
        }
        Write-Verbose "Name filter '$DeviceNameFilter' reduced $before → $($finalDevices.Count) devices"
    }

    Write-Verbose "Returning $($finalDevices.Count) devices"
    return $finalDevices
}
