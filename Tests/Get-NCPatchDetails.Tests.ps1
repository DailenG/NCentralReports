#Requires -Module Pester
<#
.SYNOPSIS
    Pester unit tests for Get-NCPatchDetails.
    Tests run without any live API connection.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Private\Get-NCPatchDetails.ps1')
}

Describe 'Get-NCPatchDetails' {

    Context 'Standard field names (.results / .detailname / .value)' {

        It 'Extracts pme_status and pme_threshold_status from standard task object' {
            $task = [PSCustomObject]@{
                results = @(
                    [PSCustomObject]@{ detailname = 'pme_status';           value = 'PME service stopped' }
                    [PSCustomObject]@{ detailname = 'pme_threshold_status'; value = 'Threshold exceeded'  }
                    [PSCustomObject]@{ detailname = 'other_field';          value = 'irrelevant'          }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'PME service stopped'
            $result.PMEThresholdStatus | Should -Be 'Threshold exceeded'
        }

        It 'Returns N/A when pme_status is absent' {
            $task = [PSCustomObject]@{
                results = @(
                    [PSCustomObject]@{ detailname = 'other_field'; value = 'irrelevant' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'N/A'
            $result.PMEThresholdStatus | Should -Be 'N/A'
        }

        It 'Returns N/A for missing threshold when only pme_status present' {
            $task = [PSCustomObject]@{
                results = @(
                    [PSCustomObject]@{ detailname = 'pme_status'; value = 'Error loading PME' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'Error loading PME'
            $result.PMEThresholdStatus | Should -Be 'N/A'
        }
    }

    Context 'Case-insensitive key matching' {

        It 'Matches PME_STATUS (uppercase) correctly' {
            $task = [PSCustomObject]@{
                results = @(
                    [PSCustomObject]@{ detailname = 'PME_STATUS';           value = 'Uppercase error' }
                    [PSCustomObject]@{ detailname = 'PME_THRESHOLD_STATUS'; value = 'Uppercase threshold' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'Uppercase error'
            $result.PMEThresholdStatus | Should -Be 'Uppercase threshold'
        }

        It 'Matches mixed-case Pme_Status correctly' {
            $task = [PSCustomObject]@{
                results = @(
                    [PSCustomObject]@{ detailname = 'Pme_Status'; value = 'Mixed case error' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus | Should -Be 'Mixed case error'
        }
    }

    Context 'Alternate results array paths' {

        It 'Falls back to .data.results when .results is absent' {
            $task = [PSCustomObject]@{
                data = [PSCustomObject]@{
                    results = @(
                        [PSCustomObject]@{ detailname = 'pme_status'; value = 'Data results path' }
                    )
                }
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus | Should -Be 'Data results path'
        }

        It 'Falls back to .details when .results and .data.results are absent' {
            $task = [PSCustomObject]@{
                details = @(
                    [PSCustomObject]@{ detailname = 'pme_status'; value = 'Details path' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus | Should -Be 'Details path'
        }
    }

    Context 'Alternate entry key/value field names' {

        It 'Uses .name when .detailname is absent' {
            $task = [PSCustomObject]@{
                results = @(
                    [PSCustomObject]@{ name = 'pme_status'; value = 'Name field used' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus | Should -Be 'Name field used'
        }

        It 'Uses .key when .detailname and .name are absent' {
            $task = [PSCustomObject]@{
                results = @(
                    [PSCustomObject]@{ key = 'pme_status'; value = 'Key field used' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus | Should -Be 'Key field used'
        }

        It 'Uses .stringValue when .value is absent' {
            $task = [PSCustomObject]@{
                results = @(
                    [PSCustomObject]@{ detailname = 'pme_status'; stringValue = 'StringValue field' }
                )
            }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus | Should -Be 'StringValue field'
        }
    }

    Context 'Empty or missing results' {

        It 'Returns Unknown when no results array found at all' {
            $task = [PSCustomObject]@{ taskId = '123'; unrelated = 'field' }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'Unknown'
            $result.PMEThresholdStatus | Should -Be 'Unknown'
        }

        It 'Returns N/A when results array is empty' {
            $task = [PSCustomObject]@{ results = @() }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PMEStatus          | Should -Be 'N/A'
            $result.PMEThresholdStatus | Should -Be 'N/A'
        }
    }

    Context 'RawDetails passthrough' {

        It 'Always includes RawDetails on the return object' {
            $task   = [PSCustomObject]@{ results = @() }
            $result = Get-NCPatchDetails -TaskObject $task
            $result.PSObject.Properties.Name | Should -Contain 'RawDetails'
            $result.RawDetails               | Should -Be $task
        }
    }
}
