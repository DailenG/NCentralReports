function Get-NCAccessToken {
    <#
    .SYNOPSIS
        Exchanges a long-lived N-Central JWT for a short-lived Bearer access token.
    .DESCRIPTION
        POSTs to /api/auth/authenticate with the JWT in the Authorization header.
        Returns the access token string.

        NOTE: The response field path (.tokens.access.token) is inferred from N-Central
        API documentation. Run with -Verbose to see the raw response and confirm.
    .PARAMETER ServerFQDN
        Fully-qualified hostname of the N-Central server (no protocol prefix).
    .PARAMETER JWT
        The long-lived JWT token from N-Central Administration > User Management > API Access.
    .EXAMPLE
        $token = Get-NCAccessToken -ServerFQDN 'n-central.example.com' -JWT $env:NCentral_JWT
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServerFQDN,

        [Parameter(Mandatory)]
        [string]$JWT
    )

    $uri = "https://$ServerFQDN/api/auth/authenticate"

    Write-Verbose "Authenticating against $uri"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method POST -Headers @{
            Authorization  = "Bearer $JWT"
            'Content-Type' = 'application/json'
        } -ErrorAction Stop
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401) {
            throw "Authentication failed (401). Your JWT may be expired or invalid. " +
                  "Generate a new one from N-Central Administration > User Management > API Access."
        }
        throw "Authentication request to $uri failed: $_"
    }

    Write-Verbose "Raw auth response: $($response | ConvertTo-Json -Depth 5 -Compress -WarningAction SilentlyContinue)"

    # Field path inferred — confirm against live response via -Verbose output above.
    # Common alternatives: .tokens.access.token  /  .accessToken  /  .token
    $accessToken = $response.tokens.access.token

    if ([string]::IsNullOrWhiteSpace($accessToken)) {
        Write-Warning "Could not find access token at response.tokens.access.token."
        Write-Warning "Raw response dumped above (use -Verbose). Update this function with the correct path."
        throw "Access token extraction failed. See -Verbose output for raw response shape."
    }

    Write-Verbose "Access token obtained (first 20 chars): $($accessToken.Substring(0, [Math]::Min(20, $accessToken.Length)))..."
    return $accessToken
}
