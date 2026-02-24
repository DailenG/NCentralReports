function Get-NCentralConfig {
    <#
    .SYNOPSIS
        Retrieves or creates the local configuration for NCentralReports.
        
    .DESCRIPTION
        Checks if a configuration file exists in the user's profile directory.
        If it does not exist, prompts the user for the N-Central Server FQDN and their JWT.
        The JWT is securely stored as a SecureString using Export-Clixml.
        Returns a custom object containing the ServerFQDN and the plain text JWT.
        
    .EXAMPLE
        $config = Get-NCentralConfig
        $ServerFQDN = $config.ServerFQDN
        $JWT = $config.JWT
    #>

    $configPath = Join-Path -Path $env:USERPROFILE -ChildPath ".ncentralreports.config.xml"

    if (Test-Path -Path $configPath) {
        Write-Verbose "Loading existing configuration from $configPath"
        
        try {
            $configObj = Import-Clixml -Path $configPath
            
            # SecureString to Plain Text inside local context
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($configObj.JWT)
            $plainJwt = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            
            return [PSCustomObject]@{
                ServerFQDN = $configObj.ServerFQDN
                JWT        = $plainJwt
            }
        }
        catch {
            Write-Warning "Failed to load configuration file. It may be corrupt or encrypted by another user."
            Write-Warning "Please delete '$configPath' and run the command again to re-authenticate."
            throw $_
        }
    }
    else {
        Write-Host "This appears to be the first time running NCentralReports, or the configuration is missing." -ForegroundColor Yellow
        Write-Host "Please provide your N-Central details below." -ForegroundColor Yellow
        
        $serverFqdn = Read-Host "Enter your N-Central Server FQDN (e.g., n-central.example.com)"
        
        # Ensure we don't have http/https prefix
        $serverFqdn = $serverFqdn -replace '^https?://', '' -replace '/$', ''
        
        $jwtSecure = Read-Host "Enter your N-Central JWT Token" -AsSecureString
        
        $configObj = [PSCustomObject]@{
            ServerFQDN = $serverFqdn
            JWT        = $jwtSecure
        }
        
        Write-Verbose "Saving configuration to $configPath"
        $configObj | Export-Clixml -Path $configPath -Force
        
        # Convert it to plain text to use right away
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($jwtSecure)
        $plainJwt = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        
        Write-Host "Configuration securely saved to: $configPath" -ForegroundColor Green
        
        return [PSCustomObject]@{
            ServerFQDN = $serverFqdn
            JWT        = $plainJwt
        }
    }
}
