function Get-NCPatchServices {
    <#
    .SYNOPSIS
        Returns degraded Patch Status monitored-service entries for a device.
    .DESCRIPTION
        Calls GET /api/devices/{deviceId}/monitored-services, filters for services whose
        name matches 'Patch Status*' or 'Patch Management*', and excludes services in
        'Normal' or 'Disconnected' states (healthy / no data).

        Returns an array of service objects including the taskId needed for the second
        API hop. The taskId field name is inferred — confirm via -Verbose output.

        Returns empty array if the device has no matching degraded services.
    .PARAMETER BaseUri
        Base URL including protocol.
    .PARAMETER Headers
        Hashtable containing Authorization Bearer token.
    .PARAMETER DeviceId
        Numeric device ID.
    .EXAMPLE
        $patchServices = Get-NCPatchServices -BaseUri $base -Headers $hdrs -DeviceId 12345
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter(Mandatory)]
        [int]$DeviceId
    )

    Write-Verbose "Fetching monitored services for device $DeviceId"

    $endpoint = "/api/devices/$DeviceId/monitored-services"
    $response = Invoke-NCRestMethod -BaseUri $BaseUri -Endpoint $endpoint -Headers $Headers

    if ($null -eq $response) {
        Write-Verbose "  No response for device $DeviceId (404) — skipping"
        return @()
    }

    # Unwrap items — may be in .data or directly as array
    $services = $response.data
    if ($null -eq $services) { $services = $response }
    $services = @($services)

    if ($services.Count -eq 0) {
        Write-Verbose "  Device $DeviceId has no monitored services"
        return @()
    }

    # Log raw shape of first service to allow field-name confirmation
    Write-Verbose "  First monitored-service object: $($services[0] | ConvertTo-Json -Depth 4 -Compress)"

    # Filter for Patch-related services only
    $patchServices = $services | Where-Object {
        $_.serviceName -like '*Patch Status*'      -or
        $_.serviceName -like '*Patch Management*'  -or
        $_.name        -like '*Patch Status*'      -or
        $_.name        -like '*Patch Management*'
    }

    if ($null -eq $patchServices -or @($patchServices).Count -eq 0) {
        Write-Verbose "  Device $DeviceId has no Patch Status services"
        return @()
    }

    # Exclude healthy / no-data states
    $degradedStates = @('Failed', 'Warning', 'Stale', 'Misconfigured', 'No Data')
    $healthyStates  = @('Normal', 'Disconnected')

    $degraded = @($patchServices) | Where-Object {
        # Include if state is NOT in the healthy list
        # (handles case where state field name varies)
        $state = $_.state
        if ($null -eq $state) { $state = $_.serviceState }
        if ($null -eq $state) { $state = $_.status }

        $healthyStates -notcontains $state
    }

    if ($null -eq $degraded -or @($degraded).Count -eq 0) {
        Write-Verbose "  Device $DeviceId has Patch services but all are healthy/disconnected"
        return @()
    }

    Write-Verbose "  Device $DeviceId — $(@($degraded).Count) degraded patch service(s) found"

    # Add deviceId to each service object for later correlation
    foreach ($svc in $degraded) {
        $svc | Add-Member -NotePropertyName '_deviceId' -NotePropertyValue $DeviceId -Force
    }

    return $degraded
}
