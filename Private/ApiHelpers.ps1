function Invoke-NCRestMethod {
    <#
    .SYNOPSIS
        Wraps Invoke-RestMethod with exponential back-off retry for N-Central REST calls.
    .DESCRIPTION
        Builds the full URI from BaseUri + Endpoint, appends query parameters, and handles:
          - 429 (rate limit): exponential back-off up to MaxRetries attempts
          - 401 (unauthorised): throws immediately with an actionable message
          - 5xx (server error): retries with same back-off as 429

        Returns the raw response object. Callers are responsible for unwrapping .data etc.
    .PARAMETER BaseUri
        Base URL including protocol, e.g. 'https://n-central.example.com'
    .PARAMETER Endpoint
        API path, e.g. '/api/devices'
    .PARAMETER Headers
        Hashtable of HTTP headers (must include Authorization Bearer token).
    .PARAMETER QueryParams
        Optional hashtable of query-string parameters.
    .PARAMETER Method
        HTTP method. Defaults to GET.
    .PARAMETER MaxRetries
        Maximum retry attempts on 429/5xx. Defaults to 5.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [hashtable]$QueryParams = @{},

        [string]$Method = 'GET',

        [int]$MaxRetries = 5
    )

    # Build query string
    $queryString = ''
    if ($QueryParams.Count -gt 0) {
        $parts = foreach ($key in $QueryParams.Keys) {
            "$([Uri]::EscapeDataString($key))=$([Uri]::EscapeDataString([string]$QueryParams[$key]))"
        }
        $queryString = '?' + ($parts -join '&')
    }

    $fullUri = $BaseUri.TrimEnd('/') + $Endpoint + $queryString
    Write-Verbose "  --> $Method $fullUri"

    $attempt = 0
    $waitSecs = 1

    while ($true) {
        $attempt++
        try {
            $response = Invoke-RestMethod -Uri $fullUri -Method $Method -Headers $Headers -ErrorAction Stop
            return $response
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            # 401 - bad/expired token, no point retrying
            if ($statusCode -eq 401) {
                throw "N-Central API returned 401 Unauthorized for $fullUri. " +
                "Your access token may have expired - re-run the script to obtain a fresh one."
            }

            # 404 - resource not found, return null so callers can handle gracefully
            if ($statusCode -eq 404) {
                Write-Verbose "  404 Not Found: $fullUri - returning null"
                return $null
            }

            # 429 or 5xx - retry with backoff
            if ($statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -le 599)) {
                if ($attempt -ge $MaxRetries) {
                    throw "N-Central API $statusCode on $fullUri after $MaxRetries attempts: $_"
                }
                Write-Verbose "  $statusCode received - waiting ${waitSecs}s before retry $attempt/$MaxRetries"
                Start-Sleep -Seconds $waitSecs
                $waitSecs = $waitSecs * 2
                continue
            }

            # Any other error - throw immediately
            throw "N-Central API request failed ($statusCode) for $fullUri : $_"
        }
    }
}

function Get-NCPagedResults {
    <#
    .SYNOPSIS
        Retrieves all pages of a paginated N-Central API endpoint.
    .DESCRIPTION
        Loops through pages starting at pageNumber=1, collecting items from .data,
        until the total collected equals .totalItems (or no items returned).

        Returns a flat array of all items across all pages.

        NOTE: The pagination envelope fields (.data / .totalItems) are strictly
        mapped according to the N-Central OpenAPI specification.
    .PARAMETER BaseUri
        Base URL including protocol.
    .PARAMETER Endpoint
        API path.
    .PARAMETER Headers
        Hashtable containing Authorization header.
    .PARAMETER QueryParams
        Additional query parameters (pageSize and pageNumber are added automatically).
    .PARAMETER PageSize
        Items per page. Defaults to 100.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [hashtable]$QueryParams = @{},

        [ValidateRange(1, 1000)]
        [int]$PageSize = 100,

        [int]$MaxPages = 500
    )

    $allItems = [System.Collections.Generic.List[object]]::new()
    $pageNumber = 1
    $firstPage = $true

    do {
        $params = $QueryParams.Clone()
        $params['pageSize'] = $PageSize
        $params['pageNumber'] = $pageNumber

        $response = Invoke-NCRestMethod -BaseUri $BaseUri -Endpoint $Endpoint `
            -Headers $Headers -QueryParams $params

        if ($null -eq $response) {
            Write-Verbose "  Paged call returned null at page $pageNumber - stopping."
            break
        }

        # Log raw shape on first page so field names can be confirmed
        if ($firstPage) {
            Write-Verbose "  First-page raw response: $($response | ConvertTo-Json -Depth 4 -Compress -WarningAction SilentlyContinue)"
            $firstPage = $false
        }

        # In Pester Mocks, the result is sometimes wrapped in a 1-element object array.
        # In the real world Invoke-RestMethod returns PSCustomObject directly.
        if ($response -is [array] -and $response.Count -eq 1 -and $response[0].PSObject.Properties.Match('data').Count -gt 0) {
            $response = $response[0]
        }

        $hasData = [bool]($response.PSObject.Properties.Match('data').Count -gt 0)

        if ($hasData) {
            # Unwrap items using strictly defined schema .data
            $items = $response.PSObject.Properties['data'].Value
            $totalProp = $response.PSObject.Properties['totalItems']
            $totalItems = if ($null -ne $totalProp) { $totalProp.Value } else { $null }
        }
        elseif ($response -is [array]) {
            # Handle raw array gracefully
            $items = $response
            $totalItems = $null
        }
        else {
            # Handle plain objects gracefully
            $items = @($response)
            $totalItems = $null
        }

        if ($items -isnot [array] -and $items -isnot [System.Collections.IEnumerable]) {
            # Single object returned
            if ($null -ne $items) { $items = @($items) }
            else { $items = @() }
        }

        $itemArray = @($items)
        if ($itemArray.Count -eq 0) {
            Write-Verbose "  No items on page $pageNumber - stopping pagination."
            break
        }

        foreach ($item in $itemArray) { $allItems.Add($item) }

        Write-Verbose "  Page $pageNumber - collected $($allItems.Count) of $totalItems total"

        if ($null -ne $totalItems -and $allItems.Count -ge $totalItems) { break }
        if ($itemArray.Count -lt $PageSize) { break }  # Last page was partial
        if ($pageNumber -ge $MaxPages) {
            Write-Warning "Get-NCPagedResults: reached MaxPages ($MaxPages) for $Endpoint - stopping to prevent runaway loop."
            break
        }

        $pageNumber++

    } while ($true)

    Write-Verbose "  Total items collected from $($Endpoint): $($allItems.Count)"
    return $allItems.ToArray()
}
