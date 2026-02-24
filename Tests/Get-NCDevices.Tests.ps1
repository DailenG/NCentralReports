#Requires -Module Pester
<#
.SYNOPSIS
    Pester unit tests for Get-NCDevices.
    Tests API response mapping to strict Device schema.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\ApiHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Public\Get-NCDevices.ps1')
}

Describe 'Get-NCDevices' {

    BeforeEach {
        $base = 'https://test.example.com'
        $headers = @{ Authorization = 'Bearer testtoken' }
    }

    Context 'Global global /api/devices mapping' {
        
        It 'Correctly maps OpenAPI Device properties to standardized PSCustomObject' {
            Mock Get-NCPagedResults {
                return @(
                    [PSCustomObject]@{
                        deviceId     = 1001
                        longName     = 'Server-01'
                        customerId   = 50
                        customerName = 'Acme Corp'
                        siteId       = 10
                        siteName     = 'Headquarters'
                        osId         = 'windows'
                        supportedOs  = 'true'
                    }
                )
            }

            $result = Get-NCDevices -BaseUri $base -Headers $headers
            
            $result.Count | Should -Be 1
            $result[0].DeviceId     | Should -Be 1001
            $result[0].DeviceName   | Should -Be 'Server-01'
            $result[0].CustomerId   | Should -Be 50
            $result[0].CustomerName | Should -Be 'Acme Corp'
            $result[0].SiteId       | Should -Be 10
            $result[0].SiteName     | Should -Be 'Headquarters'
            $result[0].OSId         | Should -Be 'windows'
            $result[0].SupportedOS  | Should -Be 'true'
        }

        It 'Filters results client-side when DeviceName parameter is provided' {
            Mock Get-NCPagedResults {
                return @(
                    [PSCustomObject]@{ deviceId = 1; longName = 'DC-01' }
                    [PSCustomObject]@{ deviceId = 2; longName = 'EXCH-01' }
                    [PSCustomObject]@{ deviceId = 3; longName = 'DC-02' }
                )
            }

            $result = Get-NCDevices -BaseUri $base -Headers $headers -DeviceName 'DC-*'
            
            $result.Count | Should -Be 2
            $result[0].DeviceName | Should -Be 'DC-01'
            $result[1].DeviceName | Should -Be 'DC-02'
        }

        It 'Passes explicit query parameters for customerId and siteId' {
            Mock Get-NCPagedResults {
                param($QueryParams)
                return @(
                    [PSCustomObject]@{ deviceId = 99; longName = 'Test'; capturedQueryParams = $QueryParams; customerId = 100; siteId = 200 }
                )
            }

            $result = Get-NCDevices -BaseUri $base -Headers $headers -CustomerId 100 -SiteId 200
            
            $result[0].DeviceId   | Should -Be 99
            $result[0].CustomerId | Should -Be 100
            $result[0].SiteId     | Should -Be 200
        }
    }
}
