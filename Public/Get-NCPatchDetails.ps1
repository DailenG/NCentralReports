function Get-NCPatchDetails {
    <#
    .SYNOPSIS
        Extracts PME status fields from an N-Central appliance task object.
    .DESCRIPTION
        Walks the task object's serviceDetails array looking for entries whose detailName
        matches 'pme_status' and 'pme_threshold_status'.

        Field paths are strictly mapped from API documentation:
          $TaskObject.serviceDetails[n].detailName  - the field name key
          $TaskObject.serviceDetails[n].detailValue - the field value

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

    $PMEStatus = $null
    $PMEThresholdStatus = $null

    # Locate the strictly defined serviceDetails array
    $results = $TaskObject.serviceDetails

    if ($null -eq $results -or @($results).Count -eq 0) {
        Write-Verbose "  No serviceDetails array found in task object. raw task: $($TaskObject | ConvertTo-Json -Depth 2 -Compress -WarningAction SilentlyContinue)"
        return [PSCustomObject]@{
            PMEStatus          = 'Unknown'
            PMEThresholdStatus = 'Unknown'
            RawDetails         = $TaskObject
        }
    }

    Write-Verbose "  Task serviceDetails array has $(@($results).Count) entries"
    Write-Verbose "  First result entry: $($results[0] | ConvertTo-Json -Depth 2 -Compress -WarningAction SilentlyContinue)"

    foreach ($entry in $results) {
        $key = $entry.detailName
        $val = $entry.detailValue

        switch -Wildcard ($key) {
            { $_ -ieq 'pme_status' } { $PMEStatus = $val }
            { $_ -ieq 'pme_threshold_status' } { $PMEThresholdStatus = $val }
        }
    }

    Write-Verbose "  PMEStatus='$PMEStatus'  PMEThresholdStatus='$PMEThresholdStatus'"

    return [PSCustomObject]@{
        PMEStatus          = if ($null -ne $PMEStatus) { $PMEStatus }          else { 'N/A' }
        PMEThresholdStatus = if ($null -ne $PMEThresholdStatus) { $PMEThresholdStatus } else { 'N/A' }
        RawDetails         = $TaskObject
    }
}
