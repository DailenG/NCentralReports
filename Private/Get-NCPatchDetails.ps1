function Get-NCPatchDetails {
    <#
    .SYNOPSIS
        Extracts PME status fields from an N-Central appliance task object.
    .DESCRIPTION
        Walks the task object's results array looking for entries whose detailname
        matches 'pme_status' and 'pme_threshold_status'.

        Field paths are inferred from API documentation:
          $TaskObject.results[n].detailname  — the field name key
          $TaskObject.results[n].value       — the field value

        These paths are confirmed via -Verbose output on first run.

        Returns a PSCustomObject with PMEStatus, PMEThresholdStatus, and the raw
        task object for future extensibility.
    .PARAMETER TaskObject
        The appliance task object returned by Get-NCApplianceTask.
    .EXAMPLE
        $details = Get-NCPatchDetails -TaskObject $task
        Write-Host "PME Status: $($details.PMEStatus)"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TaskObject
    )

    $PMEStatus          = $null
    $PMEThresholdStatus = $null

    # Locate the results array — may be at .results or .data.results
    $results = $TaskObject.results
    if ($null -eq $results) {
        $results = $TaskObject.data.results
    }
    if ($null -eq $results) {
        $results = $TaskObject.details
    }

    if ($null -eq $results -or @($results).Count -eq 0) {
        Write-Verbose "  No results array found in task object. " +
                      "Check field paths — raw task: $($TaskObject | ConvertTo-Json -Depth 2 -Compress)"
        return [PSCustomObject]@{
            PMEStatus          = 'Unknown'
            PMEThresholdStatus = 'Unknown'
            RawDetails         = $TaskObject
        }
    }

    Write-Verbose "  Task results array has $(@($results).Count) entries"
    Write-Verbose "  First result entry: $($results[0] | ConvertTo-Json -Depth 2 -Compress)"

    foreach ($entry in $results) {
        # 'detailname' is inferred — may be 'name', 'key', 'label', etc.
        $key = $entry.detailname
        if ($null -eq $key) { $key = $entry.name }
        if ($null -eq $key) { $key = $entry.key  }

        # 'value' is inferred — may be 'stringValue', 'data', etc.
        $val = $entry.value
        if ($null -eq $val) { $val = $entry.stringValue }
        if ($null -eq $val) { $val = $entry.data        }

        switch ($key) {
            'pme_status'           { $PMEStatus          = $val }
            'pme_threshold_status' { $PMEThresholdStatus = $val }
        }
    }

    Write-Verbose "  PMEStatus='$PMEStatus'  PMEThresholdStatus='$PMEThresholdStatus'"

    return [PSCustomObject]@{
        PMEStatus          = if ($null -ne $PMEStatus)          { $PMEStatus }          else { 'N/A' }
        PMEThresholdStatus = if ($null -ne $PMEThresholdStatus) { $PMEThresholdStatus } else { 'N/A' }
        RawDetails         = $TaskObject
    }
}
