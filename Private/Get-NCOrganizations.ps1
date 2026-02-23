function Get-NCCustomers {
    <#
    .SYNOPSIS
        Returns the list of N-Central customers (organisations).
    .DESCRIPTION
        Calls GET /api/customers (endpoint inferred — confirm via -Verbose output).
        Returns an array of customer objects.
    .PARAMETER BaseUri
        Base URL including protocol, e.g. 'https://n-central.example.com'
    .PARAMETER Headers
        Hashtable containing Authorization Bearer token.
    .EXAMPLE
        $customers = Get-NCCustomers -BaseUri $base -Headers $hdrs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [hashtable]$Headers
    )

    Write-Verbose "Fetching customer list from $BaseUri/api/customers"

    # Endpoint to confirm at runtime — alternatives: /api/org-units, /api/organizations
    $customers = Get-NCPagedResults -BaseUri $BaseUri -Endpoint '/api/customers' -Headers $Headers

    if ($null -eq $customers -or @($customers).Count -eq 0) {
        Write-Warning "No customers returned from /api/customers. " +
                      "Check endpoint path and token permissions."
        return @()
    }

    Write-Verbose "Found $(@($customers).Count) customers"
    return $customers
}

function Get-NCSites {
    <#
    .SYNOPSIS
        Returns sites belonging to a specific N-Central customer.
    .DESCRIPTION
        Calls GET /api/customers/{customerId}/sites.
        Returns an array of site objects. Returns empty array on 404 (customer has no sites).
    .PARAMETER BaseUri
        Base URL including protocol.
    .PARAMETER Headers
        Hashtable containing Authorization Bearer token.
    .PARAMETER CustomerId
        Numeric customer ID.
    .EXAMPLE
        $sites = Get-NCSites -BaseUri $base -Headers $hdrs -CustomerId 12345
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter(Mandatory)]
        [int]$CustomerId
    )

    Write-Verbose "Fetching sites for customer $CustomerId"

    # Endpoint to confirm at runtime
    $sites = Get-NCPagedResults -BaseUri $BaseUri -Endpoint "/api/customers/$CustomerId/sites" `
                                -Headers $Headers

    if ($null -eq $sites) { return @() }

    Write-Verbose "Found $(@($sites).Count) sites for customer $CustomerId"
    return $sites
}
