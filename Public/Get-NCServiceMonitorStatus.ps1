function Get-NCServiceMonitorStatus {
    <#
    .SYNOPSIS
        Returns degraded Patch Status monitored-service entries for a device.
    .DESCRIPTION
        Calls GET /api/devices/{deviceId}/service-monitor-status, filters for services whose
        moduleName matches 'Patch Status*' or 'Patch Management*', and excludes services in
        'Normal' or 'Disconnected' states (healthy / no data).

        Returns an array of standardized objects including mapping to the
        DeviceServiceMonitoringStatus schema.
    .PARAMETER BaseUri
        Base URL including protocol.
    .PARAMETER Headers
        Hashtable containing Authorization Bearer token.
    .PARAMETER DeviceId
        Numeric device ID.
    .EXAMPLE
        $patchServices = Get-NCServiceMonitorStatus -BaseUri $base -Headers $hdrs -DeviceId 12345
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

    $endpoint = "/api/devices/$DeviceId/service-monitor-status"
    $response = Invoke-NCRestMethod -BaseUri $BaseUri -Endpoint $endpoint -Headers $Headers

    if ($null -eq $response) {
        Write-Verbose "  No response for device $DeviceId (404) - skipping"
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
    Write-Verbose "  First monitored-service object: $($services[0] | ConvertTo-Json -Depth 4 -Compress -WarningAction SilentlyContinue)"

    # Filter for Patch-related services only (strictly mapped to moduleName)
    $patchServices = $services | Where-Object {
        $_.moduleName -like '*Patch Status*' -or
        $_.moduleName -like '*Patch Management*'
    }

    if ($null -eq $patchServices -or @($patchServices).Count -eq 0) {
        Write-Verbose "  Device $DeviceId has no Patch Status services"
        return @()
    }

    # Exclude healthy / no-data states
    $healthyStates = @('Normal', 'Disconnected')

    $degraded = @($patchServices) | Where-Object {
        # Strict mapping to stateStatus schema field
        $state = [string]$_.stateStatus
        $healthyStates -notcontains $state
    }

    if ($null -eq $degraded -or @($degraded).Count -eq 0) {
        Write-Verbose "  Device $DeviceId has Patch services but all are healthy/disconnected"
        return @()
    }

    Write-Verbose "  Device $DeviceId - $(@($degraded).Count) degraded patch service(s) found"

    # Return strictly mapped standardized objects
    $mappedDegraded = [System.Collections.Generic.List[object]]::new()
    foreach ($svc in $degraded) {
        $mapped = [PSCustomObject]@{
            _deviceId   = [long]$DeviceId
            TaskId      = [long]$svc.taskId
            ServiceId   = [long]$svc.serviceId
            ModuleName  = [string]$svc.moduleName
            StateStatus = [string]$svc.stateStatus
        }
        $mappedDegraded.Add($mapped)
    }

    return $mappedDegraded.ToArray()
}
