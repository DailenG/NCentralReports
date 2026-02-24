function Get-NCentralConfig {
    <#
    .SYNOPSIS
        Retrieves or creates the local configuration for NCentralReports.
        
    .DESCRIPTION
        Checks if a configuration file exists in the user's profile directory.
        If it does not exist, prompts the user for the N-Central Server FQDN and their JWT.
        The JWT is securely stored as a SecureString using Export-Clixml.
        Returns a custom object containing the ServerFQDN, plain text JWT, and (optionally) SMTP settings.
        
    .PARAMETER RequireSMTP
        If provided, the function checks for existing SMTP settings. Re-prompts if missing.
        
    .EXAMPLE
        $config = Get-NCentralConfig
        $ServerFQDN = $config.ServerFQDN
        $JWT = $config.JWT
    #>
    [CmdletBinding()]
    param(
        [switch]$RequireSMTP
    )

    $configPath = Join-Path -Path $env:USERPROFILE -ChildPath ".ncentralreports.config.xml"

    if (Test-Path -Path $configPath) {
        Write-Verbose "Loading existing configuration from $configPath"
        
        try {
            $configObj = Import-Clixml -Path $configPath
            
            # SecureString to Plain Text inside local context
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($configObj.JWT)
            $plainJwt = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            
            $returnObj = [PSCustomObject]@{
                ServerFQDN = $configObj.ServerFQDN
                JWT        = $plainJwt
            }

            $missingSMTP = $false

            if ($RequireSMTP) {
                if (-not $configObj.SmtpServer -or -not $configObj.SmtpFrom -or -not $configObj.SmtpUser -or -not $configObj.SmtpPassword) {
                    $missingSMTP = $true
                }
                else {
                    $returnObj | Add-Member -MemberType NoteProperty -Name SmtpServer -Value $configObj.SmtpServer
                    $returnObj | Add-Member -MemberType NoteProperty -Name SmtpFrom -Value $configObj.SmtpFrom
                    $returnObj | Add-Member -MemberType NoteProperty -Name SmtpUser -Value $configObj.SmtpUser
                    
                    $bstrPw = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($configObj.SmtpPassword)
                    $plainPw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstrPw)
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstrPw)

                    $returnObj | Add-Member -MemberType NoteProperty -Name SmtpPassword -Value $plainPw
                }
            }

            if (-not $missingSMTP) {
                return $returnObj
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
            ServerFQDN   = $serverFqdn
            JWT          = $jwtSecure
            SmtpServer   = $null
            SmtpFrom     = $null
            SmtpUser     = $null
            SmtpPassword = $null
        }
        
        $missingSMTP = $RequireSMTP
    }

    if ($missingSMTP) {
        Write-Host "`nEmail reporting is enabled, but SMTP details are missing from your configuration." -ForegroundColor Yellow
        Write-Host "Please provide your SMTP Server details below." -ForegroundColor Yellow
        
        $configObj.SmtpServer = Read-Host "SMTP Server Address (e.g., smtp.domain.com)"
        $configObj.SmtpFrom = Read-Host "Sender Email Address (e.g., reports@domain.com)"
        $configObj.SmtpUser = Read-Host "SMTP Username"
        $configObj.SmtpPassword = Read-Host "SMTP Password" -AsSecureString
    }

    if ($null -eq $configObj.ServerFQDN -or $missingSMTP) {
        Write-Verbose "Saving configuration to $configPath"
        $configObj | Export-Clixml -Path $configPath -Force
        Write-Host "Configuration securely saved to: $configPath" -ForegroundColor Green
    }
    
    # Convert JWT
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($configObj.JWT)
    $plainJwt = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    $returnObj = [PSCustomObject]@{
        ServerFQDN = $configObj.ServerFQDN
        JWT        = $plainJwt
    }

    if ($RequireSMTP) {
        $returnObj | Add-Member -MemberType NoteProperty -Name SmtpServer -Value $configObj.SmtpServer
        $returnObj | Add-Member -MemberType NoteProperty -Name SmtpFrom -Value $configObj.SmtpFrom
        $returnObj | Add-Member -MemberType NoteProperty -Name SmtpUser -Value $configObj.SmtpUser
        
        $bstrPw = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($configObj.SmtpPassword)
        $plainPw = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstrPw)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstrPw)

        $returnObj | Add-Member -MemberType NoteProperty -Name SmtpPassword -Value $plainPw
    }

    return $returnObj
}
