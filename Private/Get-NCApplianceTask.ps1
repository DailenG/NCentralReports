function Get-NCApplianceTask {
    <#
    .SYNOPSIS
        Fetches the full appliance task object from N-Central.
    .DESCRIPTION
        Calls GET /api/appliance-tasks/{taskId} and returns the raw response.
        The task object contains a results array with detail entries including
        pme_status and pme_threshold_status.

        Returns null if the task is not found (404) — callers should handle this case.
    .PARAMETER BaseUri
        Base URL including protocol.
    .PARAMETER Headers
        Hashtable containing Authorization Bearer token.
    .PARAMETER TaskId
        The task identifier string obtained from the monitored-service object.
    .EXAMPLE
        $task = Get-NCApplianceTask -BaseUri $base -Headers $hdrs -TaskId '99999'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter(Mandatory)]
        [string]$TaskId
    )

    Write-Verbose "Fetching appliance task $TaskId"

    $response = Invoke-NCRestMethod -BaseUri $BaseUri `
                                    -Endpoint "/api/appliance-tasks/$TaskId" `
                                    -Headers $Headers

    if ($null -eq $response) {
        Write-Verbose "  Appliance task $TaskId not found (404)"
        return $null
    }

    # Log raw shape of task object on first call per session (verbose)
    $responseJson = $response | ConvertTo-Json -Depth 3 -Compress
    Write-Verbose "  Task $TaskId raw response (truncated): $($responseJson.Substring(0, [Math]::Min(500, $responseJson.Length)))..."

    return $response
}
